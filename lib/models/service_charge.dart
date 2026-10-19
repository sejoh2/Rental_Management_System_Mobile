import '../core/api_client.dart';

/// A charge every unit of a property pays besides rent: garbage, security.
class ServiceCharge {
  const ServiceCharge({
    required this.id,
    required this.name,
    required this.frequency,
    required this.amount,
    required this.startDate,
    required this.status,
    required this.unitAmounts,
  });

  factory ServiceCharge.fromJson(Json json) {
    return ServiceCharge(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'monthly',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      startDate: json['start_date'] as String?,
      status: json['status'] as String? ?? 'active',
      unitAmounts: {
        for (final row in json['unit_amounts'] as List? ?? const [])
          '${(row as Json)['unit_id']}':
              (row['amount'] as num?)?.toDouble() ?? 0,
      },
    );
  }

  final String id;
  final String name;

  /// monthly or once.
  final String frequency;

  /// The usual amount; a unit may have its own in [unitAmounts].
  final double amount;

  /// "2026-10-01": when the charge started.
  final String? startDate;

  /// active or archived.
  final String status;

  /// Unit ID -> what that unit pays.
  final Map<String, double> unitAmounts;

  double amountFor(String unitId) => unitAmounts[unitId] ?? amount;
}
