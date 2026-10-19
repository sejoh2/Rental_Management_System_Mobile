import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_theme.dart';
import '../../data/expense_repository.dart';
import '../../data/file_repository.dart';
import '../../data/water_repository.dart';
import '../../models/app_file.dart';
import '../../models/caretaker_property.dart';
import '../../models/expense.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';
import '../../widgets/attachments.dart';
import '../../widgets/fields.dart';
import '../../widgets/message_box.dart';

/// Adds money spent on the property, with its receipts (photos or PDFs).
class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({super.key, required this.property});

  final CaretakerProperty property;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _amount = TextEditingController();
  final _notes = TextEditingController();

  /// Made once for this expense: sending again after a dropped connection never adds it twice.
  final _saveKey = ApiClient.newSaveKey();

  String _category = 'repairs_maintenance';

  /// Empty means the whole property.
  String _unitId = '';
  DateTime _date = DateTime.now();
  List<Unit>? _units;
  final List<PickedPhoto> _receipts = [];
  bool _saving = false;
  String? _error;

  /// Set when the expense was saved but a receipt could not be uploaded.
  bool _savedWithoutReceipt = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_started) {
      _started = true;
      _loadUnits();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final units = await WaterRepository(
        AppScope.read(context).api,
      ).listUnits(widget.property.id);

      if (mounted) {
        setState(() {
          _units = units.where((unit) => unit.status != 'inactive').toList()
            ..sort((a, b) => a.unitNumber.compareTo(b.unitNumber));
        });
      }
    } on ApiException {
      // Without the list the expense is for the whole property; it can still be saved.
      if (mounted) setState(() => _units = const []);
    }
  }

  Future<void> _addReceipt() async {
    final picked = await pickPhoto(context, allowPdf: true);

    if (picked == null || !mounted) return;

    if (picked.bytes.length > maxUploadBytes) {
      setState(() => _error = 'That file is over 5 MB. Choose a smaller one.');
      return;
    }

    final label = await askFileLabel(context, hint: 'Receipt');

    if (label != null && mounted) {
      setState(() {
        _error = null;
        _receipts.add(picked.withLabel(label));
      });
    }
  }

  Future<void> _save() async {
    final api = AppScope.read(context).api;

    setState(() {
      _saving = true;
      _error = null;
    });

    Expense expense;

    try {
      expense = await ExpenseRepository(api).create(
        widget.property.id,
        category: _category,
        amount: parseNumber(_amount.text)!,
        date: dayKey(_date),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        unitId: _unitId.isEmpty ? null : _unitId,
        saveKey: _saveKey,
      );
    } on ApiException catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _saving = false;
        });
      }
      return;
    }

    try {
      for (final receipt in _receipts) {
        await FileRepository(api).upload(
          FileKind.expenseReceipt,
          expense.id,
          bytes: receipt.bytes,
          contentType: receipt.contentType,
          name: receipt.name,
          label: receipt.label,
          saveKey: ApiClient.newSaveKey(),
        );
      }
    } on ApiException catch (failure) {
      // The expense itself is saved; saving again would add it twice.
      if (mounted) {
        setState(() {
          _savedWithoutReceipt = true;
          _saving = false;
          _error =
              'The expense was saved, but a receipt could not be uploaded: ${failure.message} '
              'Open the expense from the list to add it.';
        });
      }
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${formatKes(expense.amount)} added to ${monthLabel(_date)}.',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final amount = parseNumber(_amount.text);
    final ready =
        !_saving && !_savedWithoutReceipt && amount != null && amount > 0;

    return PopScope(
      // After a save without the receipt, going back still refreshes the list.
      canPop: !_savedWithoutReceipt,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Add an expense')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpace.page),
          children: [
            AmountField(
              controller: _amount,
              label: 'Amount',
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.lg),
            SelectField<String>(
              label: 'Kind of expense',
              value: _category,
              options: ExpenseLabels.categories,
              onChanged: (value) =>
                  setState(() => _category = value ?? 'other'),
            ),
            const SizedBox(height: AppSpace.lg),
            SelectField<String>(
              label: 'This cost is for',
              value: _unitId,
              options: {
                '': 'The whole property',
                for (final unit in _units ?? const <Unit>[])
                  unit.id: 'House ${unit.unitNumber}',
              },
              onChanged: (value) => setState(() => _unitId = value ?? ''),
            ),
            const SizedBox(height: AppSpace.lg),
            DateField(
              label: 'Date',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (date) => setState(() => _date = date),
            ),
            const SizedBox(height: AppSpace.lg),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What it was for (optional)',
                hintText: 'e.g. New tap for A2',
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Text(
              'RECEIPTS',
              style: AppText.eyebrow.copyWith(color: colors.inkFaint),
            ),
            const SizedBox(height: AppSpace.sm),
            for (final (index, receipt) in _receipts.indexed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  receipt.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.image_outlined,
                  color: colors.inkSoft,
                ),
                title: Text(
                  (receipt.label ?? '').isEmpty ? receipt.name : receipt.label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${(receipt.bytes.length / 1024).round()} KB'),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: _saving
                      ? null
                      : () => setState(() => _receipts.removeAt(index)),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _saving || _savedWithoutReceipt ? null : _addReceipt,
              icon: const Icon(Icons.attach_file, size: 19),
              label: Text(
                _receipts.isEmpty
                    ? 'Add a receipt (photo or PDF)'
                    : 'Add another',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpace.lg),
              ErrorBox(_error!),
            ],
            const SizedBox(height: AppSpace.xl),
            if (_savedWithoutReceipt)
              OutlinedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Close'),
              )
            else
              FilledButton(
                onPressed: ready ? _save : null,
                child: Text(_saving ? 'Saving...' : 'Add expense'),
              ),
          ],
        ),
      ),
    );
  }
}
