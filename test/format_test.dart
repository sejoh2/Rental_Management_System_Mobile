import 'package:caretaker_app/models/water_reading.dart';
import 'package:caretaker_app/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers and money are written as on the web', () {
    expect(formatNumber(1234567), '1,234,567');
    expect(formatNumber(12.5), '12.5');
    expect(formatNumber(168), '168');
    expect(formatNumber(-2400), '-2,400');
    expect(formatKes(2400), 'KES 2,400');
  });

  test('a month is sent to the server as its first day', () {
    expect(billingPeriodOf(DateTime(2026, 10, 14)), '2026-10-01');
    expect(billingPeriodOf(DateTime(2027, 1)), '2027-01-01');
    expect(monthLabel(DateTime(2026, 10)), 'October 2026');
  });

  test('a typed reading may use a comma for the decimal point', () {
    expect(parseNumber('172'), 172);
    expect(parseNumber('172,5'), 172.5);
    expect(parseNumber(' '), isNull);
    expect(parseNumber('abc'), isNull);
  });

  test('a cancelled bill counts as nothing paid', () {
    final paid = WaterReading.fromJson({
      'id': 12,
      'unit_id': 2,
      'previous_reading': 168,
      'current_reading': 172,
      'bill_status': 'partial',
      'bill_amount_paid': 300,
      'status': 'submitted',
    });
    final voided = WaterReading.fromJson({
      'id': 13,
      'unit_id': 2,
      'bill_status': 'void',
      'bill_amount_paid': 300,
      'status': 'rejected',
    });

    expect(paid.paid, 300);
    expect(paid.stillCounts, isTrue);
    expect(voided.paid, 0);
    expect(voided.stillCounts, isFalse);
  });
}
