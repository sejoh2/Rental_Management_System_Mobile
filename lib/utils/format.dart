/// Numbers, money and months, written the way the web app writes them.
library;

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// 1234567.5 -> "1,234,567.5". Whole numbers have no decimals.
String formatNumber(num value) {
  final negative = value < 0;
  final absolute = value.abs();

  var whole = absolute.truncate().toString();
  final fraction = absolute - absolute.truncate();

  final grouped = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }

  whole = grouped.toString();

  // At most two decimals, without trailing zeros: 12.50 -> "12.5".
  final decimals = fraction == 0
      ? ''
      : fraction
            .toStringAsFixed(2)
            .substring(1)
            .replaceFirst(RegExp(r'\.?0+$'), '');

  return '${negative ? '-' : ''}$whole$decimals';
}

/// 1200 -> "KES 1,200"
String formatKes(num value) => 'KES ${formatNumber(value)}';

/// The first day of a month, as the server names a billing month: "2026-10-01".
String billingPeriodOf(DateTime month) {
  final mm = month.month.toString().padLeft(2, '0');

  return '${month.year}-$mm-01';
}

/// "October 2026"
String monthLabel(DateTime month) =>
    '${_months[month.month - 1]} ${month.year}';

/// A month's first day, with no time of day.
DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

/// Reads a typed number, allowing a comma for the decimal point. null if it is not a number.
double? parseNumber(String text) {
  final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');

  return cleaned.isEmpty ? null : double.tryParse(cleaned);
}
