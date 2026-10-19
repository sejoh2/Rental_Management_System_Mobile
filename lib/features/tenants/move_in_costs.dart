import '../../models/service_charge.dart';
import '../../models/unit.dart';
import '../../utils/format.dart';

/// A monthly amount for the move-in month, under the property's rule.
class MonthPart {
  const MonthPart(this.amount, this.days, this.daysInMonth);

  final double amount;
  final int days;
  final int daysInMonth;

  bool get fullMonth => days == daysInMonth;
}

/// What a monthly amount comes to for the move-in month, as the server
/// bills it (the web's preview uses the same rule):
/// - moving in on the 1st, or the rule "full_month": the full amount;
/// - "free_until_next_month": nothing;
/// - otherwise ("prorated"): the days left after the move-in day.
MonthPart moveInPart(String policy, DateTime moveIn, double monthly) {
  final daysInMonth = DateTime(moveIn.year, moveIn.month + 1, 0).day;

  if (moveIn.day == 1 || policy == 'full_month') {
    return MonthPart(monthly, daysInMonth, daysInMonth);
  }

  if (policy == 'free_until_next_month') return MonthPart(0, 0, daysInMonth);

  final days = daysInMonth - moveIn.day;

  return MonthPart(
    (monthly * days / daysInMonth).roundToDouble(),
    days,
    daysInMonth,
  );
}

/// What a tenant moving into [unit] on [moveIn] owes on day one, and the
/// monthly service charges that start with the next billing.
class MoveInCosts {
  const MoveInCosts({
    required this.rows,
    required this.later,
    required this.firstBilling,
  });

  factory MoveInCosts.of({
    required String policy,
    required Unit unit,
    required DateTime moveIn,
    required List<ServiceCharge> charges,
  }) {
    final rent = moveInPart(policy, moveIn, unit.monthlyRent);
    double part(double amount) => moveInPart(policy, moveIn, amount).amount;

    final fixedWater = unit.waterBillingMethod == 'fixed_monthly'
        ? unit.waterFixedMonthlyBill ?? 0
        : 0.0;

    // A one-off charge is billed in full on the day they move in. A monthly
    // charge starts with the next monthly billing, unless they move in on
    // the 1st, which is the billing date itself.
    final now = <(String, double)>[];
    final later = <(String, double)>[];
    final moveInKey = dayKey(moveIn);

    for (final charge in charges) {
      final amount = charge.amountFor(unit.id);

      if (charge.status != 'active' || amount <= 0) continue;

      if (charge.frequency == 'once') {
        now.add((charge.name, amount));
      } else if (moveIn.day == 1) {
        // A charge added later in the month is billed from the day it was added.
        final start = charge.startDate;
        final from = start != null && start.compareTo(moveInKey) > 0
            ? DateTime.parse(start)
            : moveIn;

        now.add((
          '${charge.name} (first month)',
          moveInPart(policy, from, amount).amount,
        ));
      } else {
        later.add((charge.name, amount));
      }
    }

    final rows = <(String, double)>[
      ('Rent deposit', unit.rentDeposit),
      ('Water deposit', unit.waterDeposit),
      ('Electricity deposit', unit.electricityDeposit ?? 0),
      (
        rent.fullMonth
            ? 'First month rent (full month)'
            : 'First month rent (${rent.days} of ${rent.daysInMonth} days)',
        rent.amount,
      ),
      ('First month electricity', part(unit.electricityMonthlyCharge ?? 0)),
      ('First month water', part(fixedWater)),
      ...now,
    ].where((row) => row.$2 > 0).toList();

    return MoveInCosts(
      rows: rows,
      later: later,
      firstBilling: DateTime(moveIn.year, moveIn.month + 1),
    );
  }

  /// (label, amount), amounts above zero only.
  final List<(String, double)> rows;

  /// Monthly service charges not due now: (name, amount a month).
  final List<(String, double)> later;

  /// The 1st of the month after the move-in.
  final DateTime firstBilling;

  double get total => rows.fold(0, (sum, row) => sum + row.$2);
}

/// The property's rule for a mid-month move-in, in words.
String moveInRuleLabel(String policy) => switch (policy) {
  'full_month' => 'the full month',
  'free_until_next_month' => 'free until the 1st of next month',
  _ => 'only the days left in the month',
};
