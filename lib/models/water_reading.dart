import '../core/api_client.dart';

/// One meter reading and the bill it made.
class WaterReading {
  const WaterReading({
    required this.id,
    required this.unitId,
    required this.unitNumber,
    required this.tenantId,
    required this.tenantName,
    required this.previousReading,
    required this.currentReading,
    required this.unitsUsed,
    required this.ratePerUnit,
    required this.billAmount,
    required this.billAmountPaid,
    required this.billStatus,
    required this.status,
    required this.notes,
    required this.isFinal,
    required this.canEdit,
  });

  factory WaterReading.fromJson(Json json) {
    double? number(String key) => (json[key] as num?)?.toDouble();

    return WaterReading(
      id: '${json['id']}',
      unitId: '${json['unit_id']}',
      unitNumber: json['unit_number'] as String? ?? '',
      tenantId: json['tenant_id'] == null ? null : '${json['tenant_id']}',
      tenantName: json['tenant_name'] as String?,
      previousReading: number('previous_reading') ?? 0,
      currentReading: number('current_reading') ?? 0,
      unitsUsed: number('units_used'),
      ratePerUnit: number('rate_per_unit'),
      billAmount: number('bill_amount'),
      billAmountPaid: number('bill_amount_paid'),
      billStatus: json['bill_status'] as String?,
      status: json['status'] as String? ?? '',
      notes: json['notes'] as String?,
      isFinal: json['is_final'] == true,
      canEdit: json['can_edit'] == true,
    );
  }

  final String id;
  final String unitId;
  final String unitNumber;
  final String? tenantId;
  final String? tenantName;
  final double previousReading;
  final double currentReading;
  final double? unitsUsed;
  final double? ratePerUnit;
  final double? billAmount;
  final double? billAmountPaid;

  /// The bill: open, partial, paid or void.
  final String? billStatus;

  /// submitted, flagged (lower than the previous reading, not billed) or rejected.
  final String status;
  final String? notes;

  /// A second reading taken when the tenant moved out.
  final bool isFinal;

  /// Submitted, and its bill was not settled from a deposit at move-out.
  final bool canEdit;

  bool get isFlagged => status == 'flagged';

  /// Rejected or cancelled: it no longer counts.
  bool get stillCounts => status != 'rejected';

  /// What the tenant has paid towards the bill.
  double get paid => billStatus == 'void' ? 0 : billAmountPaid ?? 0;
}
