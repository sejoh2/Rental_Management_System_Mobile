import '../core/api_client.dart';

/// One unit's electricity bill for a month, typed in from the meter or the
/// token purchases.
class ElectricityBill {
  const ElectricityBill({
    required this.unitId,
    required this.unitNumber,
    required this.tenantName,
    required this.amount,
    required this.amountPaid,
    required this.status,
  });

  factory ElectricityBill.fromJson(Json json) {
    return ElectricityBill(
      unitId: '${json['unit_id']}',
      unitNumber: json['unit_number'] as String? ?? '',
      tenantName: json['tenant_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String?,
    );
  }

  final String unitId;
  final String unitNumber;
  final String? tenantName;

  /// Null when nothing has been entered for the month yet.
  final double? amount;
  final double amountPaid;

  /// open, partial or paid; null before a bill exists.
  final String? status;
}

/// A month of electricity bills for a property.
class ElectricityMonth {
  const ElectricityMonth({required this.period, required this.bills});

  factory ElectricityMonth.fromJson(Json json) {
    return ElectricityMonth(
      period: json['period'] as String? ?? '',
      bills: [
        for (final row in json['bills'] as List? ?? const [])
          ElectricityBill.fromJson(row as Json),
      ],
    );
  }

  /// "2026-10"
  final String period;
  final List<ElectricityBill> bills;
}
