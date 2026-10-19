import '../core/api_client.dart';
import 'tenant.dart';

/// A photo or PDF attached to a record: a meter photo, a receipt, or a
/// tenant's document. Files are private; one is opened through a link that
/// works for a few minutes.
class AppFile {
  const AppFile({
    required this.id,
    required this.name,
    required this.label,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedByName,
    required this.createdAt,
  });

  factory AppFile.fromJson(Json json) {
    return AppFile(
      id: '${json['id']}',
      name: json['name'] as String? ?? 'file',
      label: json['label'] as String?,
      contentType: json['content_type'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      uploadedByName: json['uploaded_by_name'] as String?,
      createdAt: parseDay(json['created_at']),
    );
  }

  final String id;
  final String name;
  final String? label;
  final String contentType;
  final int sizeBytes;
  final String? uploadedByName;
  final DateTime? createdAt;

  bool get isPdf => contentType == 'application/pdf';

  String get title => (label != null && label!.isNotEmpty) ? label! : name;

  /// "48 KB", "1.2 MB"
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).round()} KB';

    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// What a file is attached to.
enum FileKind {
  meterPhoto('meter_photo'),
  expenseReceipt('expense_receipt'),
  tenantDocument('tenant_document');

  const FileKind(this.value);

  final String value;
}
