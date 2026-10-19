import '../../models/unit.dart';
import '../../models/water_reading.dart';

/// The figures on the home screen for one property and month, worked out
/// from its units and that month's readings. Kept apart from the screen so
/// it can be tested on its own.
class HomeSummary {
  const HomeSummary({
    required this.totalUnits,
    required this.occupiedUnits,
    required this.unitsToRead,
    required this.unitsRead,
    required this.flaggedReadings,
    required this.openRepairs,
  });

  factory HomeSummary.from({
    required List<Unit> units,
    required List<WaterReading> readings,
    required int openRepairs,
  }) {
    final inUse = units.where((unit) => unit.status != 'inactive').toList();

    // Readings that still count, per unit, so each unit is looked up once.
    final readByUnit = <String, Set<String?>>{};
    var flagged = 0;

    for (final reading in readings) {
      if (!reading.stillCounts) continue;
      if (reading.isFlagged) flagged += 1;

      (readByUnit[reading.unitId] ??= <String?>{}).add(reading.tenantId);
    }

    // Only metered units with a tenant are read; each tenant once a month.
    final toRead = inUse
        .where((unit) => unit.isMetered && unit.isOccupied)
        .toList();
    final read = toRead
        .where(
          (unit) => readByUnit[unit.id]?.contains(unit.tenant?.id) ?? false,
        )
        .length;

    return HomeSummary(
      totalUnits: inUse.length,
      occupiedUnits: inUse.where((unit) => unit.isOccupied).length,
      unitsToRead: toRead.length,
      unitsRead: read,
      flaggedReadings: flagged,
      openRepairs: openRepairs,
    );
  }

  final int totalUnits;
  final int occupiedUnits;

  /// Metered units with a tenant: the ones that need a reading this month.
  final int unitsToRead;
  final int unitsRead;
  final int flaggedReadings;
  final int openRepairs;

  int get unitsLeftToRead => unitsToRead - unitsRead;
}
