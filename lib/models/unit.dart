import '../core/api_client.dart';
import '../utils/format.dart';

/// A house or shop in a property.
class Unit {
  const Unit({
    required this.id,
    required this.unitNumber,
    required this.unitType,
    required this.floor,
    required this.status,
    required this.monthlyRent,
    required this.waterBillingMethod,
    required this.waterRatePerUnit,
    required this.meterNumber,
    required this.tenant,
    this.rentDeposit = 0,
    this.waterDeposit = 0,
    this.waterFixedMonthlyBill,
    this.electricityBillingMethod = 'fixed_monthly',
    this.electricityMonthlyCharge,
    this.electricityDeposit,
  });

  factory Unit.fromJson(Json json) {
    final tenant = json['current_tenant'];

    return Unit(
      id: '${json['id']}',
      unitNumber: json['unit_number'] as String? ?? '',
      unitType: json['unit_type'] as String? ?? '',
      floor: json['block_or_floor'] as String?,
      status: json['status'] as String? ?? '',
      monthlyRent: (json['monthly_rent'] as num?)?.toDouble() ?? 0,
      waterBillingMethod: json['water_billing_method'] as String? ?? '',
      waterRatePerUnit: (json['water_rate_per_unit'] as num?)?.toDouble(),
      meterNumber: json['water_meter_number'] as String?,
      tenant: tenant is Map<String, dynamic>
          ? UnitTenant.fromJson(tenant)
          : null,
      rentDeposit: (json['rent_deposit'] as num?)?.toDouble() ?? 0,
      waterDeposit: (json['water_deposit'] as num?)?.toDouble() ?? 0,
      waterFixedMonthlyBill: (json['water_fixed_monthly_bill'] as num?)
          ?.toDouble(),
      electricityBillingMethod:
          json['electricity_billing_method'] as String? ?? 'fixed_monthly',
      electricityMonthlyCharge: (json['electricity_monthly_charge'] as num?)
          ?.toDouble(),
      electricityDeposit: (json['electricity_deposit'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String unitNumber;
  final String unitType;
  final String? floor;

  /// vacant, occupied or inactive (not in use).
  final String status;
  final double monthlyRent;
  final String waterBillingMethod;
  final double? waterRatePerUnit;
  final String? meterNumber;

  /// Who lives there now, if anyone.
  final UnitTenant? tenant;

  /// Charged once when a tenant moves in. Zero means none.
  final double rentDeposit;
  final double waterDeposit;

  /// The fixed water bill each month, when water is billed that way.
  final double? waterFixedMonthlyBill;

  /// fixed_monthly (the amount below, with rent) or entered (typed each month).
  final String electricityBillingMethod;

  /// Billed with rent each month; null when electricity is not billed.
  final double? electricityMonthlyCharge;
  final double? electricityDeposit;

  bool get isOccupied => status == 'occupied' && tenant != null;

  bool get isMetered => waterBillingMethod == 'per_unit_metered';

  bool get isVacant => status == 'vacant';

  /// "Metered at KES 150 a unit", "Fixed KES 500 a month", as the owner set it.
  String waterLabel({double? propertyRate}) {
    return switch (waterBillingMethod) {
      'per_unit_metered' =>
        (waterRatePerUnit ?? propertyRate) == null
            ? 'Metered'
            : 'Metered at ${formatKes(waterRatePerUnit ?? propertyRate!)} a unit',
      'fixed_monthly' =>
        waterFixedMonthlyBill == null
            ? 'Fixed amount each month'
            : 'Fixed ${formatKes(waterFixedMonthlyBill!)} a month',
      'included_in_rent' => 'Included in rent',
      _ => waterBillingMethod.replaceAll('_', ' '),
    };
  }

  /// "Typed in each month", "Fixed KES 1,000 a month with rent", "Not billed".
  String get electricityLabel {
    if (electricityBillingMethod == 'entered') {
      return 'Amount typed in each month';
    }

    final charge = electricityMonthlyCharge;

    return charge == null
        ? 'Not billed'
        : 'Fixed ${formatKes(charge)} a month, with rent';
  }

  /// "One bedroom", or the owner's own wording, which is kept as typed.
  String get typeLabel {
    const usual = {
      'bedsitter': 'Bedsitter',
      'studio': 'Studio',
      'one_bedroom': 'One bedroom',
      'two_bedroom': 'Two bedroom',
      'three_bedroom': 'Three bedroom',
      'shop': 'Shop',
      'office': 'Office',
      'other': 'Other',
    };

    return usual[unitType] ?? unitType;
  }
}

/// The tenant living in a unit, and what they owe.
class UnitTenant {
  const UnitTenant({
    required this.id,
    required this.fullName,
    required this.status,
    required this.balance,
  });

  factory UnitTenant.fromJson(Json json) {
    return UnitTenant(
      id: '${json['tenant_id']}',
      fullName: json['full_name'] as String? ?? '',
      status: json['status'] as String? ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String fullName;

  /// active or notice_given.
  final String status;

  /// What they owe now; 0 when settled.
  final double balance;
}
