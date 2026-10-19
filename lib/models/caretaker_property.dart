import '../core/api_client.dart';

/// A property the caretaker looks after, with what they may do in it.
class CaretakerProperty {
  const CaretakerProperty({
    required this.id,
    required this.name,
    required this.location,
    required this.totalUnits,
    required this.occupiedUnits,
    required this.waterBillingMethod,
    required this.waterRatePerUnit,
    required this.canManageTenants,
    required this.canRecordPayments,
    this.moveInBilling = 'prorated',
    this.rentDueDay,
  });

  factory CaretakerProperty.fromJson(Json json) {
    return CaretakerProperty(
      id: '${json['id']}',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      totalUnits: (json['total_units'] as num?)?.toInt() ?? 0,
      occupiedUnits: (json['occupied_units'] as num?)?.toInt() ?? 0,
      waterBillingMethod: json['water_billing_method'] as String? ?? '',
      waterRatePerUnit: (json['water_rate_per_unit'] as num?)?.toDouble(),
      canManageTenants: json['can_manage_tenants'] == true,
      canRecordPayments: json['can_record_payments'] == true,
      moveInBilling: json['move_in_billing'] as String? ?? 'prorated',
      rentDueDay: (json['rent_due_day'] as num?)?.toInt(),
    );
  }

  final String id;
  final String name;
  final String location;
  final int totalUnits;
  final int occupiedUnits;
  final String waterBillingMethod;

  /// The property's rate; a unit may have its own.
  final double? waterRatePerUnit;

  /// Level 2: may add and edit tenants, and see their documents.
  final bool canManageTenants;

  /// Turned on by the owner for this property.
  final bool canRecordPayments;

  /// How the first month is billed when a tenant moves in mid-month:
  /// prorated, full_month or free_until_next_month.
  final String moveInBilling;

  /// The day of the month rent is due.
  final int? rentDueDay;

  int get vacantUnits => totalUnits - occupiedUnits;

  bool get readsMeters => waterBillingMethod == 'per_unit_metered';
}
