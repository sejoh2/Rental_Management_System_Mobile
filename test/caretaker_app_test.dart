import 'package:caretaker_app/features/expenses/electricity_page.dart';
import 'package:caretaker_app/features/tenants/move_in_costs.dart';
import 'package:caretaker_app/features/tenants/record_payment_page.dart';
import 'package:caretaker_app/features/units/units_page.dart';
import 'package:caretaker_app/models/caretaker_property.dart';
import 'package:caretaker_app/models/electricity_bill.dart';
import 'package:caretaker_app/models/repair.dart';
import 'package:caretaker_app/models/service_charge.dart';
import 'package:caretaker_app/models/tenant.dart';
import 'package:caretaker_app/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

Unit unit({
  String id = '5',
  String number = 'A1',
  String status = 'vacant',
  Map<String, dynamic>? tenant,
  double rent = 9000,
}) {
  return Unit.fromJson({
    'id': id,
    'unit_number': number,
    'unit_type': 'bedsitter',
    'status': status,
    'monthly_rent': rent,
    'rent_deposit': 9000,
    'water_deposit': 1000,
    'water_billing_method': 'fixed_monthly',
    'water_fixed_monthly_bill': 300,
    'electricity_billing_method': 'fixed_monthly',
    'electricity_monthly_charge': 600,
    'electricity_deposit': null,
    'current_tenant': tenant,
  });
}

ServiceCharge charge(String name, String frequency, double amount) {
  return ServiceCharge.fromJson({
    'id': 1,
    'name': name,
    'frequency': frequency,
    'amount': amount,
    'start_date': '2026-01-01',
    'status': 'active',
    'unit_amounts': [
      {'unit_id': 5, 'amount': amount},
    ],
  });
}

void main() {
  group('move-in costs, as the web shows them', () {
    test('prorated: the days left after the move-in day', () {
      // 31 days in October; moving in on the 21st leaves 10.
      final part = moveInPart('prorated', DateTime(2026, 10, 21), 9300);

      expect(part.days, 10);
      expect(part.daysInMonth, 31);
      expect(part.amount, 3000);
    });

    test('the 1st, or the full-month rule: the whole month', () {
      expect(moveInPart('prorated', DateTime(2026, 10, 1), 9000).amount, 9000);
      expect(
        moveInPart('full_month', DateTime(2026, 10, 21), 9000).amount,
        9000,
      );
    });

    test('free until next month: nothing for the move-in month', () {
      expect(
        moveInPart(
          'free_until_next_month',
          DateTime(2026, 10, 21),
          9000,
        ).amount,
        0,
      );
    });

    test('deposits, first month, one-off charges now; monthly ones later', () {
      final costs = MoveInCosts.of(
        policy: 'full_month',
        unit: unit(),
        moveIn: DateTime(2026, 10, 21),
        charges: [
          charge('Garbage', 'monthly', 200),
          charge('Key', 'once', 500),
        ],
      );

      expect(costs.rows.map((row) => row.$1), [
        'Rent deposit',
        'Water deposit',
        'First month rent (full month)',
        'First month electricity',
        'First month water',
        'Key',
      ]);
      expect(costs.total, 9000 + 1000 + 9000 + 600 + 300 + 500);
      expect(costs.later, [('Garbage', 200.0)]);
      expect(costs.firstBilling, DateTime(2026, 11));
    });

    test('moving in on the 1st: monthly charges are due now too', () {
      final costs = MoveInCosts.of(
        policy: 'prorated',
        unit: unit(),
        moveIn: DateTime(2026, 11, 1),
        charges: [charge('Garbage', 'monthly', 200)],
      );

      expect(costs.later, isEmpty);
      expect(costs.rows.last, ('Garbage (first month)', 200.0));
    });
  });

  group('electricity: an empty box leaves the bill as it is', () {
    final bills = [
      ElectricityBill.fromJson({
        'unit_id': 1,
        'unit_number': 'A1',
        'tenant_id': 9,
        'tenant_name': 'Grace',
        'amount': 1500,
      }),
      ElectricityBill.fromJson({
        'unit_id': 2,
        'unit_number': 'A2',
        'tenant_id': 10,
        'tenant_name': 'Tom',
        'amount': null,
      }),
      ElectricityBill.fromJson({
        'unit_id': 3,
        'unit_number': 'A3',
        'tenant_id': null,
        'tenant_name': null,
        'amount': null,
      }),
    ];

    test('empty boxes send nothing (the old app removed the bill)', () {
      expect(electricityChanges(bills, {'1': '', '2': ' '}), isEmpty);
    });

    test('a new amount, and 0 to remove an unpaid bill, are sent', () {
      expect(electricityChanges(bills, {'1': '1800', '2': '900'}), {
        '1': 1800,
        '2': 900,
      });
      expect(electricityChanges(bills, {'1': '0'}), {'1': 0});
    });

    test('the same amount again is not a change', () {
      expect(electricityChanges(bills, {'1': '1500'}), isEmpty);
    });

    test('a vacant unit is never billed', () {
      expect(electricityChanges(bills, {'3': '700'}), isEmpty);
    });
  });

  test('a payment received today keeps the time; an earlier day is midday', () {
    final now = DateTime(2026, 10, 19, 16, 30);

    expect(receivedAtFor(DateTime(2026, 10, 19), now), now);
    expect(
      receivedAtFor(DateTime(2026, 10, 17), now),
      DateTime(2026, 10, 17, 12),
    );
  });

  test('payment words match the web', () {
    expect(paymentMethods['bank'], 'Bank transfer');
    expect(paymentAccounts['rent'], 'Rent');
    expect(paymentAccountHints.keys, paymentAccounts.keys);
  });

  group('units: filters and search', () {
    final units = [
      unit(
        id: '1',
        number: 'A1',
        status: 'occupied',
        tenant: {
          'tenant_id': 7,
          'full_name': 'Grace Wanjiru',
          'status': 'active',
          'balance': 2500,
        },
      ),
      unit(
        id: '2',
        number: 'A2',
        status: 'occupied',
        tenant: {
          'tenant_id': 8,
          'full_name': 'Tom Mboya',
          'status': 'notice_given',
          'balance': 0,
        },
      ),
      unit(id: '3', number: 'B1'),
    ];

    List<String> numbers(UnitFilter filter, [String search = '']) =>
        unitsShown(units, filter, search).map((u) => u.unitNumber).toList();

    test('each filter', () {
      expect(numbers(UnitFilter.all), ['A1', 'A2', 'B1']);
      expect(numbers(UnitFilter.occupied), ['A1', 'A2']);
      expect(numbers(UnitFilter.vacant), ['B1']);
      expect(numbers(UnitFilter.owing), ['A1']);
    });

    test('search by house or tenant', () {
      expect(numbers(UnitFilter.all, 'b1'), ['B1']);
      expect(numbers(UnitFilter.all, 'grace'), ['A1']);
      expect(numbers(UnitFilter.vacant, 'grace'), isEmpty);
    });
  });

  test('a unit carries its deposits and billing for the details page', () {
    final details = unit();

    expect(details.rentDeposit, 9000);
    expect(details.waterDeposit, 1000);
    expect(details.waterLabel(), 'Fixed KES 300 a month');
    expect(details.electricityLabel, 'Fixed KES 600 a month, with rent');
    expect(details.isVacant, isTrue);
  });

  test('a tenant carries the notice date, deposits and water reference', () {
    final tenant = Tenant.fromJson({
      'id': 3,
      'unit_id': 1,
      'status': 'notice_given',
      'notice_date': '2026-10-15',
      'rent_deposit_due': 9000,
      'water_deposit_due': 1000,
      'water_payment_reference': 'A1-GRACE',
    });

    expect(tenant.noticeDate, DateTime(2026, 10, 15));
    expect(tenant.rentDepositDue, 9000);
    expect(tenant.waterPaymentReference, 'A1-GRACE');
  });

  test('a repair says who handles it and what is new', () {
    final repair = Repair.fromJson({
      'id': 4,
      'property_id': 2,
      'assigned_caretaker_id': 11,
      'caretaker_notice': 'assigned',
      'tenant_charge_id': 6,
    });

    expect(repair.isFor('11'), isTrue);
    expect(repair.isFor('12'), isFalse);
    expect(repair.isFor(null), isFalse);
    expect(repair.caretakerNotice, 'assigned');
    expect(repair.tenantChargeId, '6');
  });

  group('what the owner lets the caretaker do', () {
    test('each switch is read from the server', () {
      final property = CaretakerProperty.fromJson({
        'id': 1,
        'name': 'Green Court',
        'can_manage_tenants': false,
        'can_record_payments': true,
        'permissions': {
          'can_read_meters': true,
          'can_enter_electricity': false,
          'can_manage_maintenance': true,
          'can_add_expenses': false,
          'can_view_tenants': true,
          'can_manage_tenants': false,
          'can_record_payments': true,
        },
      });

      expect(property.canReadMeters, isTrue);
      expect(property.canEnterElectricity, isFalse);
      expect(property.canAddExpenses, isFalse);
      expect(property.allowedWork, [
        'Meter readings',
        'Maintenance',
        'View tenants',
        'Record payments',
      ]);
    });

    test('an older server (no switches): the day-to-day work is allowed', () {
      final property = CaretakerProperty.fromJson({'id': 1, 'name': 'X'});

      expect(property.canReadMeters, isTrue);
      expect(property.canManageMaintenance, isTrue);
      expect(property.canViewTenants, isTrue);
      expect(property.canManageTenants, isFalse);
    });
  });
}
