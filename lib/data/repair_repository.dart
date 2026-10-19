import '../core/api_client.dart';
import '../models/repair.dart';

/// The server calls for repairs (maintenance requests).
class RepairRepository {
  const RepairRepository(this.api);

  final ApiClient api;

  /// Newest first.
  Future<List<Repair>> list(String propertyId) async {
    final response = await api.get(
      '/api/maintenance',
      query: {'property_id': propertyId},
    );

    return [
      for (final row in response['data'] as List? ?? const [])
        Repair.fromJson(row as Json),
    ];
  }

  Future<Repair> report(
    String propertyId, {
    required String title,
    String? description,
    required String category,
    required String priority,
    String? unitId,
    required String saveKey,
  }) async {
    final response = await api.post(
      '/api/properties/$propertyId/maintenance',
      saveKey: saveKey,
      body: {
        'title': title,
        'description': ?description,
        'category': category,
        'priority': priority,
        if (unitId != null) 'unit_id': int.parse(unitId),
      },
    );

    return Repair.fromJson(response['data'] as Json);
  }

  /// Changes a repair: its status, vendor, costs, who pays.
  Future<Repair> update(String repairId, Map<String, Object?> changes) async {
    final response = await api.patch(
      '/api/maintenance/$repairId',
      body: changes,
    );

    return Repair.fromJson(response['data'] as Json);
  }
}
