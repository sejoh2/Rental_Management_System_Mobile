import '../core/api_client.dart';
import '../models/unit.dart';
import '../models/water_reading.dart';

/// The server calls for units and water readings.
///
/// Screens ask this class, never the server directly, so that saving
/// without a connection can later be added here alone.
class WaterRepository {
  const WaterRepository(this.api);

  final ApiClient api;

  Future<List<Unit>> listUnits(String propertyId) async {
    final response = await api.get('/api/properties/$propertyId/units');

    return [
      for (final row in response['data'] as List? ?? const [])
        Unit.fromJson(row as Json),
    ];
  }

  /// The month's readings, newest first.
  Future<List<WaterReading>> listReadings(
    String propertyId,
    String billingPeriod,
  ) async {
    final response = await api.get(
      '/api/properties/$propertyId/water-readings',
      query: {'billing_period': billingPeriod},
    );

    return [
      for (final row in response['data'] as List? ?? const [])
        WaterReading.fromJson(row as Json),
    ];
  }

  /// What the unit's meter last showed before this month; null if it was never read.
  Future<double?> previousReading(
    String propertyId,
    String unitId,
    String billingPeriod,
  ) async {
    final response = await api.get(
      '/api/properties/$propertyId/units/$unitId/water-readings/previous',
      query: {'billing_period': billingPeriod},
    );

    return ((response['data'] as Json?)?['previous_reading'] as num?)
        ?.toDouble();
  }

  /// Saves a reading and bills it. [saveKey] stays the same if the same
  /// reading is sent again, so it is never saved twice.
  Future<WaterReading> submitReading({
    required String propertyId,
    required String unitId,
    required String billingPeriod,
    required double currentReading,
    double? previousReading,
    String? notes,
    required bool finalReading,
    required String saveKey,
  }) async {
    final response = await api.post(
      '/api/properties/$propertyId/units/$unitId/water-readings',
      saveKey: saveKey,
      body: {
        'billing_period': billingPeriod,
        'current_reading': currentReading,
        'previous_reading': ?previousReading,
        'notes': ?notes,
        'final_reading': finalReading,
      },
    );

    return WaterReading.fromJson(response['data'] as Json);
  }

  Future<void> editReading(
    String readingId, {
    required double previousReading,
    required double currentReading,
    String? notes,
  }) {
    return api.patch(
      '/api/water-readings/$readingId',
      body: {
        'previous_reading': previousReading,
        'current_reading': currentReading,
        'notes': ?notes,
      },
    );
  }

  Future<void> cancelReading(String readingId, String reason) {
    return api.post(
      '/api/water-readings/$readingId/cancel',
      body: {'reason': reason},
    );
  }

  /// A flagged reading: enter the right figure, or throw it out.
  Future<void> correctFlagged(
    String readingId,
    double correctedCurrent, {
    String? notes,
  }) {
    return api.patch(
      '/api/water-readings/$readingId/review',
      body: {
        'action': 'approve',
        'corrected_current_reading': correctedCurrent,
        'notes': ?notes,
      },
    );
  }

  Future<void> rejectFlagged(String readingId, {String? notes}) {
    return api.patch(
      '/api/water-readings/$readingId/review',
      body: {'action': 'reject', 'notes': ?notes},
    );
  }
}
