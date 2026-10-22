import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_client.dart';
import '../core/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';
import '../data/file_repository.dart';
import '../models/app_file.dart';
import '../utils/format.dart';
import 'message_box.dart';

/// The server takes files up to 5 MB.
const maxUploadBytes = 5 * 1024 * 1024;

/// A photo or PDF ready to upload.
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.contentType,
    required this.name,
    this.label,
  });

  final List<int> bytes;
  final String contentType;
  final String name;

  /// What it is ("Receipt"), sent with the upload; may be empty.
  final String? label;

  bool get isPdf => contentType == 'application/pdf';

  PickedPhoto withLabel(String? label) => PickedPhoto(
    bytes: bytes,
    contentType: contentType,
    name: name,
    label: label,
  );
}

/// Asks: camera or gallery? Then takes or chooses one photo, made smaller
/// first (a phone photo is often over the 5 MB limit; 1600 px is plenty to
/// read a meter or a receipt). With [allowPdf], a PDF can be chosen too.
Future<PickedPhoto?> pickPhoto(
  BuildContext context, {
  bool allowPdf = false,
}) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(sheetContext, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(sheetContext, 'gallery'),
          ),
          if (allowPdf)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
          const SizedBox(height: AppSpace.sm),
        ],
      ),
    ),
  );

  if (source == null) return null;

  if (source == 'pdf') {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (file == null) return null;

    return PickedPhoto(
      bytes: await file.xFile.readAsBytes(),
      contentType: 'application/pdf',
      name: file.name,
    );
  }

  final file = await ImagePicker().pickImage(
    source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 82,
  );

  if (file == null) return null;

  final name = file.name;
  final lower = name.toLowerCase();
  final contentType =
      file.mimeType ??
      (lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg');

  return PickedPhoto(
    bytes: await file.readAsBytes(),
    contentType: contentType,
    name: name,
  );
}

/// Asks what the file is ("ID copy", "Receipt"). Empty is allowed: the
/// file's own name is shown then. Null when cancelled.
Future<String?> askFileLabel(BuildContext context, {String? hint}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _LabelDialog(hint: hint),
  );
}

/// The box keeps its own text field, so the field is let go only once the
/// box has finished closing (letting it go at once broke the screen).
class _LabelDialog extends StatefulWidget {
  const _LabelDialog({this.hint});

  final String? hint;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What is it?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 120,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Description (optional)',
          hintText: widget.hint == null ? null : 'e.g. ${widget.hint}',
        ),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Upload'),
        ),
      ],
    );
  }
}

/// Saves a PDF on the phone (in the app's own space) and opens it in the
/// phone's PDF viewer, from where it can be shared or printed.
Future<void> openPdf(List<int> bytes, String name) async {
  final folder = await getTemporaryDirectory();
  final file = File('${folder.path}${Platform.pathSeparator}$name.pdf');

  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(file.path, type: 'application/pdf');

  if (result.type != ResultType.done) {
    throw Exception(result.message);
  }
}

/// Opens a file: a photo inside the app, a PDF in the phone's PDF viewer.
Future<void> openFile(BuildContext context, AppFile file) async {
  final repository = FileRepository(AppScope.read(context).api);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  try {
    final url = await repository.link(file.id);

    if (file.isPdf) {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No app on this phone opens PDF files.'),
          ),
        );
      }
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewer(title: file.title, url: url),
      ),
    );
  } on ApiException catch (failure) {
    messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: const Border(),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stack) => const Center(
              child: Text(
                'The photo could not be opened.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The files attached to one record, with a button to add a photo or a
/// PDF, and what it is ("ID copy"), as on the web. Deleting a file is left
/// to the owner, on the web.
class AttachmentsSection extends StatefulWidget {
  const AttachmentsSection({
    super.key,
    required this.kind,
    required this.targetId,
    required this.emptyText,
    this.addLabel = 'Add a photo or PDF',
    this.labelHint,
    this.canAdd = true,
  });

  final FileKind kind;
  final String targetId;
  final String emptyText;
  final String addLabel;

  /// An example description: "ID copy", "Receipt".
  final String? labelHint;
  final bool canAdd;

  @override
  State<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends State<AttachmentsSection> {
  List<AppFile>? _files;
  String? _error;
  bool _uploading = false;
  bool _started = false;

  late FileRepository _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = FileRepository(AppScope.read(context).api);

    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final files = await _repository.list(widget.kind, widget.targetId);

      if (mounted) setState(() => _files = files);
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    }
  }

  Future<void> _add() async {
    final picked = await pickPhoto(
      context,
      // A meter photo is a photo; documents and receipts may be PDFs.
      allowPdf: widget.kind != FileKind.meterPhoto,
    );

    if (picked == null || !mounted) return;

    if (picked.bytes.length > maxUploadBytes) {
      setState(() => _error = 'That file is over 5 MB. Choose a smaller one.');
      return;
    }

    // A meter photo needs no description; documents and receipts do.
    final label = widget.kind == FileKind.meterPhoto
        ? ''
        : await askFileLabel(context, hint: widget.labelHint);

    if (label == null || !mounted) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      await _repository.upload(
        widget.kind,
        widget.targetId,
        bytes: picked.bytes,
        contentType: picked.contentType,
        name: picked.name,
        label: label,
        saveKey: ApiClient.newSaveKey(),
      );

      await _load();
    } on ApiException catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final files = _files;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (files == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(AppSpace.md),
            child: LoadingView(),
          ),
        if (files != null && files.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            child: Text(
              widget.emptyText,
              style: AppText.small.copyWith(color: colors.inkFaint),
            ),
          ),
        for (final file in files ?? const <AppFile>[])
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              file.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
              color: colors.inkSoft,
            ),
            title: Text(
              file.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                if (file.title != file.name) file.name,
                file.sizeLabel,
                if (file.createdAt != null) formatDay(file.createdAt!),
                if (file.uploadedByName != null) file.uploadedByName!,
              ].join(' · '),
            ),
            trailing: Icon(Icons.open_in_new, size: 18, color: colors.inkFaint),
            onTap: () => openFile(context, file),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.sm),
          ErrorBox(_error!),
        ],
        if (widget.canAdd) ...[
          const SizedBox(height: AppSpace.sm),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _add,
            icon: const Icon(Icons.attach_file, size: 19),
            label: Text(_uploading ? 'Uploading...' : widget.addLabel),
          ),
        ],
      ],
    );
  }
}
