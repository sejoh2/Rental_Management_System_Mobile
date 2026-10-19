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
    bool chargeToTenant = false,
    String chargeTiming = 'now',
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
        'charge_to_tenant': chargeToTenant,
        if (chargeToTenant) 'charge_timing': chargeTiming,
      },
    );

    return Repair.fromJson(response['data'] as Json);
  }

  /// One repair. Opening it clears its "new" mark for this caretaker.
  Future<Repair> get(String repairId) async {
    final response = await api.get('/api/maintenance/$repairId');

    return Repair.fromJson(response['data'] as Json);
  }

  /// What is new for this caretaker: repairs the owner reported, or gave
  /// to them, not opened yet. Newest first.
  Future<List<Repair>> notices() async {
    final response = await api.get('/api/maintenance/notices');

    return [
      for (final row in response['data'] as List? ?? const [])
        Repair.fromJson(row as Json),
    ];
  }

  /// "Mark all as read".
  Future<void> markNoticesSeen() {
    return api.post('/api/maintenance/notices/seen');
  }

  /// Tells the tenant by SMS about a repair charged to them. Sent only when
  /// asked; can be sent again.
  Future<Repair> sendChargeSms(String repairId) async {
    final response = await api.post('/api/maintenance/$repairId/charge-sms');

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
