import '../core/api_client.dart';
import '../models/service_charge.dart';
import '../models/unit.dart';

/// The server calls for one unit, and the property's service charges (for
/// the move-in costs). Changing units stays with the owner, on the web.
class UnitRepository {
  const UnitRepository(this.api);

  final ApiClient api;

  Future<Unit> get(String unitId) async {
    final response = await api.get('/api/units/$unitId');

    return Unit.fromJson(response['data'] as Json);
  }

  Future<List<ServiceCharge>> serviceCharges(String propertyId) async {
    final response = await api.get(
      '/api/properties/$propertyId/service-charges',
    );

    return [
      for (final row in response['data'] as List? ?? const [])
        ServiceCharge.fromJson(row as Json),
    ];
  }
}
