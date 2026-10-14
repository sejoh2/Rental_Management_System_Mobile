import '../core/api_client.dart';

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

  bool get isOccupied => status == 'occupied' && tenant != null;

  bool get isMetered => waterBillingMethod == 'per_unit_metered';

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
