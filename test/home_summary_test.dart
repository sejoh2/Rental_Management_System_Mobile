import 'package:caretaker_app/features/home/home_summary.dart';
import 'package:caretaker_app/models/unit.dart';
import 'package:caretaker_app/models/water_reading.dart';
import 'package:flutter_test/flutter_test.dart';

Unit unit(
  String id, {
  String status = 'occupied',
  String? tenantId,
  bool metered = true,
}) {
  return Unit.fromJson({
    'id': id,
    'unit_number': 'A$id',
    'status': status,
    'monthly_rent': 10000,
    'water_billing_method': metered ? 'per_unit_metered' : 'fixed_monthly',
    'current_tenant': tenantId == null
        ? null
        : {'tenant_id': tenantId, 'full_name': 'T$tenantId', 'balance': 0},
  });
}

WaterReading reading(
  String unitId,
  String tenantId, {
  String status = 'submitted',
}) {
  return WaterReading.fromJson({
    'id': '$unitId-$tenantId-$status',
    'unit_id': unitId,
    'tenant_id': tenantId,
    'previous_reading': 100,
    'current_reading': 110,
    'status': status,
  });
}

void main() {
  test('counts the houses to read and those already read this month', () {
    final summary = HomeSummary.from(
      units: [
        unit('1', tenantId: '10'),
        unit('2', tenantId: '20'),
        unit('3', tenantId: '30'),
        unit('4', status: 'vacant'),
        unit('5', tenantId: '50', metered: false),
        unit('6', status: 'inactive'),
      ],
      readings: [
        reading('1', '10'),
        reading('2', '20', status: 'flagged'),
      ],
      openRepairs: 2,
    );

    expect(summary.totalUnits, 5, reason: 'a unit not in use is left out');
    expect(summary.occupiedUnits, 4);
    expect(summary.unitsToRead, 3, reason: 'only metered houses with a tenant');
    expect(
      summary.unitsRead,
      2,
      reason: 'a flagged reading is still a reading',
    );
    expect(summary.unitsLeftToRead, 1);
    expect(summary.flaggedReadings, 1);
    expect(summary.openRepairs, 2);
  });

  test(
    'a cancelled reading does not count, and a new tenant needs their own reading',
    () {
      final summary = HomeSummary.from(
        units: [unit('1', tenantId: '11')],
        readings: [
          reading('1', '10'),
          reading('1', '11', status: 'rejected'),
        ],
        openRepairs: 0,
      );

      expect(summary.unitsToRead, 1);
      expect(summary.unitsRead, 0);
    },
  );
}
