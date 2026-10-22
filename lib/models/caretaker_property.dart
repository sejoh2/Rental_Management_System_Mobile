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
    this.canReadMeters = true,
    this.canEnterElectricity = true,
    this.canManageMaintenance = true,
    this.canAddExpenses = true,
    this.canViewTenants = true,
  });

  factory CaretakerProperty.fromJson(Json json) {
    final permissions = json['permissions'];
    // A server from before the switches: the day-to-day work was allowed.
    bool allowed(String key, {bool otherwise = true}) =>
        permissions is Map ? permissions[key] == true : otherwise;

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
      canReadMeters: allowed('can_read_meters'),
      canEnterElectricity: allowed('can_enter_electricity'),
      canManageMaintenance: allowed('can_manage_maintenance'),
      canAddExpenses: allowed('can_add_expenses'),
      canViewTenants: allowed('can_view_tenants'),
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

  /// What the owner lets this caretaker do here, one switch each.
  /// May add and edit tenants, mark notice, and see their documents.
  final bool canManageTenants;

  /// May record cash or bank payments handed to them.
  final bool canRecordPayments;

  final bool canReadMeters;
  final bool canEnterElectricity;
  final bool canManageMaintenance;
  final bool canAddExpenses;

  /// Tenants' names, phones, balances and statements. Without it, units
  /// show only whether they are occupied.
  final bool canViewTenants;

  /// The switches that are on, in words, for Profile and Home.
  List<String> get allowedWork => [
    if (canReadMeters) 'Meter readings',
    if (canEnterElectricity) 'Electricity',
    if (canManageMaintenance) 'Maintenance',
    if (canAddExpenses) 'Expenses',
    if (canViewTenants) 'View tenants',
    if (canManageTenants) 'Manage tenants',
    if (canRecordPayments) 'Record payments',
  ];

  /// How the first month is billed when a tenant moves in mid-month:
  /// prorated, full_month or free_until_next_month.
  final String moveInBilling;

  /// The day of the month rent is due.
  final int? rentDueDay;

  int get vacantUnits => totalUnits - occupiedUnits;

  bool get readsMeters => waterBillingMethod == 'per_unit_metered';
}
