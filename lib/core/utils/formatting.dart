import '../domain/money.dart';

const List<String> monthNames = <String>[
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

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `March 2026`.
String formatMonth(DateTime date) =>
    '${monthNames[date.month - 1]} ${date.year}';

/// `10 Mar 2026` (device-local date).
String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_shortMonths[local.month - 1]} ${local.year}';
}

/// `₹1,250.75` from integer minor units.
String formatMinor(int amountMinorUnits, {String currencyCode = 'INR'}) =>
    Money(amountMinorUnits, currencyCode).format();

/// First day of the month containing [date].
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

/// First day of the following month.
DateTime nextMonthStart(DateTime date) => DateTime(date.year, date.month + 1);

/// Fraction of [part] in [whole] for progress bars only (display, never
/// stored or summed). Zero when [whole] is not positive.
double displayRatio(Money part, Money whole) {
  if (whole.amountMinorUnits <= 0) {
    return 0;
  }
  final ratio = part.amountMinorUnits / whole.amountMinorUnits;
  return ratio.clamp(0, 1).toDouble();
}
