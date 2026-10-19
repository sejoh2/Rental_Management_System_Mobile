import '../core/api_client.dart';
import '../models/caretaker_property.dart';

/// The properties the signed-in caretaker looks after, and figures about one
/// property for the home screen.
class PropertyRepository {
  const PropertyRepository(this.api);

  final ApiClient api;

  Future<List<CaretakerProperty>> myProperties() async {
    final response = await api.get('/api/caretaker/properties');

    return [
      for (final row in response['data'] as List? ?? const [])
        CaretakerProperty.fromJson(row as Json),
    ];
  }

  /// Repairs still waiting or being worked on.
  Future<int> openRepairs(String propertyId) async {
    final response = await api.get(
      '/api/maintenance',
      query: {'property_id': propertyId},
    );

    final rows = response['data'] as List? ?? const [];

    return rows.where((row) {
      final status = (row as Json)['status'];

      return status == 'reported' || status == 'in_progress';
    }).length;
  }
}
