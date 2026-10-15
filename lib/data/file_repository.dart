import '../core/api_client.dart';
import '../models/app_file.dart';

/// Photos and PDFs attached to records. Uploading, listing and opening are
/// allowed to caretakers; deleting stays with the owner.
class FileRepository {
  const FileRepository(this.api);

  final ApiClient api;

  Future<List<AppFile>> list(FileKind kind, String targetId) async {
    final response = await api.get(
      '/api/files',
      query: {'kind': kind.value, 'target_id': targetId},
    );

    return [
      for (final row in response['data'] as List? ?? const [])
        AppFile.fromJson(row as Json),
    ];
  }

  Future<AppFile> upload(
    FileKind kind,
    String targetId, {
    required List<int> bytes,
    required String contentType,
    required String name,
    String? label,
    required String saveKey,
  }) async {
    final response = await api.upload(
      '/api/files',
      query: {
        'kind': kind.value,
        'target_id': targetId,
        'name': name,
        if (label != null && label.isNotEmpty) 'label': label,
      },
      bytes: bytes,
      contentType: contentType,
      saveKey: saveKey,
    );

    return AppFile.fromJson(response['data'] as Json);
  }

  /// A link that opens the file for a few minutes.
  Future<String> link(String fileId) async {
    final response = await api.get('/api/files/$fileId/link');

    return (response['data'] as Json)['url'] as String;
  }
}
