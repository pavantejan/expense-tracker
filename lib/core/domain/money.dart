// Integer minor-unit money (ADR-001, ADR-016).
//
// All persisted and computed financial amounts are integer minor units
// (paise for INR). This is the only place that converts between minor
// units, decimal strings, and display strings. No financial arithmetic
// in this file uses `double`: parsing and formatting use decimal-string
// and integer arithmetic only. Addition, subtraction, negation and
// absolute value use BigInt intermediates and reject results outside
// the signed 64-bit range instead of silently wrapping.
//
// Two parsing rules, kept separate on purpose:
//
// * [Money.parse] is strict: manual input with more fractional digits
//   than the currency allows is rejected, never rounded.
// * [Money.parseNormalised] applies round-half-away-from-zero and exists
//   only for the importer and Sheets read-back boundaries. The caller
//   retains the original raw value for audit; this type does not.
//
// Negative [Money] values can arise from arithmetic (for example a
// subtraction). They are never stored as transaction or posting amounts:
// persisted amounts are always positive and direction lives in postings
// (blueprint section 6.1). Repositories and the posting service enforce
// that boundary; this type does not forbid negative values outright so
// that subtraction and comparison remain usable.

/// Currency codes with explicitly defined minor-unit precision and
/// display symbols.
///
/// V1 stores INR only. This registry is metadata for parsing and
/// formatting only: it is not a multi-currency feature and no
/// conversion exists. A code outside this registry is rejected
/// instead of silently assuming two decimal places.
const Map<String, int> _minorUnitDigitsByCurrency = <String, int>{
  'INR': 2,
  'USD': 2,
  'EUR': 2,
  'GBP': 2,
  'JPY': 0,
  'KRW': 0,
};

const Map<String, String> _currencySymbols = <String, String>{
  'INR': '₹',
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'KRW': '₩',
};

/// Currency codes accepted by [Money], in registry order.
Set<String> get supportedCurrencyCodes =>
    _minorUnitDigitsByCurrency.keys.toSet();

/// Whether [currencyCode] has an explicit registry entry.
bool isSupportedCurrencyCode(String currencyCode) =>
    _minorUnitDigitsByCurrency.containsKey(currencyCode);

void _requireSupportedCurrency(String currencyCode) {
  if (!isSupportedCurrencyCode(currencyCode)) {
    throw ArgumentError(
      'Unsupported currency code: $currencyCode. '
      'Supported codes: ${supportedCurrencyCodes.join(', ')}.',
    );
  }
}

/// Number of minor units per major unit for a currency code.
///
/// Throws [ArgumentError] for a code with no registry entry.
int minorUnitDigitsForCurrency(String currencyCode) {
  _requireSupportedCurrency(currencyCode);
  return _minorUnitDigitsByCurrency[currencyCode]!;
}

/// Display symbol for a currency code.
///
/// Throws [ArgumentError] for a code with no registry entry.
String currencySymbolFor(String currencyCode) {
  _requireSupportedCurrency(currencyCode);
  return _currencySymbols[currencyCode]!;
}

/// Largest and smallest signed 64-bit integer values. Persisted amounts
/// are stored in a signed 64-bit column, so arithmetic results must
/// stay inside these bounds.
const int _maxInt64 = 9223372036854775807;
const int _minInt64 = -9223372036854775808;

/// Converts a [BigInt] arithmetic result to an `int`, throwing a
/// [StateError] when it cannot be represented as a signed 64-bit
/// integer instead of silently wrapping.
int _checkedInt64(BigInt value) {
  if (value < BigInt.from(_minInt64) || value > BigInt.from(_maxInt64)) {
    throw StateError(
      'Money arithmetic result $value cannot be represented as a '
      'signed 64-bit integer.',
    );
  }
  return value.toInt();
}

BigInt _powerOfTen(int exponent) {
  var result = BigInt.one;
  for (var i = 0; i < exponent; i++) {
    result *= BigInt.from(10);
  }
  return result;
}

bool _isDigits(String value) {
  if (value.isEmpty) {
    return false;
  }
  for (var i = 0; i < value.length; i++) {
    final code = value.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) {
      return false;
    }
  }
  return true;
}

/// Indian digit grouping: the rightmost three digits form one group and
/// the remaining digits group by two (for example 1234567 becomes
/// 12,34,567). [digits] must contain only decimal digits, no sign.
String _groupIndian(String digits) {
  if (digits.length <= 3) {
    return digits;
  }
  final lastThree = digits.substring(digits.length - 3);
  var head = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (head.length > 2) {
    parts.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) {
    parts.insert(0, head);
  }
  return '${parts.join(',')},$lastThree';
}

/// An immutable amount in integer minor units for one currency.
///
/// The currency code must have an explicit entry in the supported
/// registry; constructing money in an unsupported code throws
/// [ArgumentError]. V1 stores INR only.
class Money {
  /// Creates money from an integer minor-unit amount (paise for INR).
  ///
  /// Throws [ArgumentError] for an unsupported currency code.
  factory Money(int amountMinorUnits, String currencyCode) {
    _requireSupportedCurrency(currencyCode);
    return Money._(amountMinorUnits, currencyCode);
  }

  const Money._(this.amountMinorUnits, this.currencyCode);

  /// Zero money in [currencyCode].
  ///
  /// Throws [ArgumentError] for an unsupported currency code.
  factory Money.zero(String currencyCode) {
    _requireSupportedCurrency(currencyCode);
    return Money._(0, currencyCode);
  }

  /// Amount in minor units. May be negative only as an arithmetic
  /// result; never persist a negative amount as a stored amount.
  final int amountMinorUnits;

  /// ISO currency code, `INR` in V1.
  final String currencyCode;

  /// Minor-unit digits for this money's currency.
  int get minorUnitDigits => minorUnitDigitsForCurrency(currencyCode);

  /// Whether the amount is exactly zero.
  bool get isZero => amountMinorUnits == 0;

  /// Whether the amount is greater than zero.
  bool get isPositive => amountMinorUnits > 0;

  /// Whether the amount is less than zero.
  bool get isNegative => amountMinorUnits < 0;

  /// The absolute value, in the same currency.
  ///
  /// Throws [StateError] for the minimum signed 64-bit value, whose
  /// absolute value cannot be represented.
  Money abs() =>
      Money(_checkedInt64(BigInt.from(amountMinorUnits).abs()), currencyCode);

  /// Parses a decimal string strictly, without rounding.
  ///
  /// Accepts an optional leading `+` or `-`, digits, and at most one
  /// decimal point. More fractional digits than the currency allows,
  /// exponent notation, grouping separators, currency symbols, and
  /// embedded whitespace are rejected with a [FormatException].
  /// Leading and trailing whitespace is trimmed.
  static Money parse(String input, {String currencyCode = 'INR'}) {
    return Money(
      _parseDecimal(input, currencyCode: currencyCode, normalise: false),
      currencyCode,
    );
  }

  /// Parses a decimal string, returning null instead of throwing.
  ///
  /// Only malformed input returns null. An unsupported [currencyCode]
  /// still throws [ArgumentError].
  static Money? tryParse(String input, {String currencyCode = 'INR'}) {
    try {
      return parse(input, currencyCode: currencyCode);
    } on FormatException {
      return null;
    }
  }

  /// Parses a decimal string with round-half-away-from-zero normalisation
  /// at the currency's minor-unit boundary.
  ///
  /// Importer and Sheets read-back boundary only (ADR-016). Manual input
  /// must use [parse], which rejects over-precise values instead.
  static Money parseNormalised(String input, {String currencyCode = 'INR'}) {
    return Money(
      _parseDecimal(input, currencyCode: currencyCode, normalise: true),
      currencyCode,
    );
  }

  /// Parses with normalisation, returning null instead of throwing.
  ///
  /// Only malformed input returns null. An unsupported [currencyCode]
  /// still throws [ArgumentError].
  static Money? tryParseNormalised(
    String input, {
    String currencyCode = 'INR',
  }) {
    try {
      return parseNormalised(input, currencyCode: currencyCode);
    } on FormatException {
      return null;
    }
  }

  static int _parseDecimal(
    String input, {
    required String currencyCode,
    required bool normalise,
  }) {
    final digits = minorUnitDigitsForCurrency(currencyCode);
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Amount must not be empty.');
    }
    var rest = trimmed;
    var negative = false;
    final first = rest.codeUnitAt(0);
    if (first == 0x2B || first == 0x2D) {
      negative = first == 0x2D;
      rest = rest.substring(1);
    }
    if (rest.isEmpty) {
      throw const FormatException('Amount must contain digits.');
    }
    final parts = rest.split('.');
    if (parts.length > 2) {
      throw const FormatException(
        'Amount must contain at most one decimal point.',
      );
    }
    final integerPart = parts[0];
    final fractionalPart = parts.length == 2 ? parts[1] : '';
    if (integerPart.isNotEmpty && !_isDigits(integerPart)) {
      throw const FormatException('Amount must contain only digits.');
    }
    if (parts.length == 2) {
      if (fractionalPart.isEmpty || !_isDigits(fractionalPart)) {
        throw const FormatException('Amount must contain only digits.');
      }
    }
    if (integerPart.isEmpty && fractionalPart.isEmpty) {
      throw const FormatException('Amount must contain digits.');
    }
    if (!normalise && fractionalPart.length > digits) {
      throw FormatException('Amounts support up to $digits decimal places.');
    }
    final magnitude = _toMinorUnits(
      integerPart: integerPart.isEmpty ? '0' : integerPart,
      fractionalPart: fractionalPart,
      digits: digits,
      normalise: normalise,
    );
    // The magnitude may reach 2^63 only for a negative result: that is
    // exactly the minimum signed 64-bit value and is representable.
    // A positive result of the same magnitude is not.
    final limit = negative
        ? BigInt.from(_maxInt64) + BigInt.one
        : BigInt.from(_maxInt64);
    if (magnitude > limit) {
      throw const FormatException('Amount is too large.');
    }
    final signed = negative ? -magnitude : magnitude;
    return signed.toInt();
  }

  static BigInt _toMinorUnits({
    required String integerPart,
    required String fractionalPart,
    required int digits,
    required bool normalise,
  }) {
    BigInt combined;
    if (fractionalPart.length <= digits) {
      final padded = fractionalPart.padRight(digits, '0');
      combined = BigInt.parse('$integerPart$padded');
    } else {
      // Only reachable when normalising: round half away from zero.
      final keep = fractionalPart.substring(0, digits);
      final remainder = fractionalPart.substring(digits);
      final half = '5${'0' * (remainder.length - 1)}';
      final roundUp = remainder.compareTo(half) >= 0;
      combined = BigInt.parse('$integerPart$keep');
      if (roundUp) {
        combined += BigInt.one;
      }
    }
    return combined;
  }

  /// Decimal string without grouping or a currency symbol, for example
  /// `1250.75`. Used at external boundaries only; internal totals never
  /// pass through this representation.
  String toDecimalString() {
    final digits = minorUnitDigits;
    final magnitude = BigInt.from(amountMinorUnits).abs();
    final divisor = _powerOfTen(digits);
    final whole = magnitude ~/ divisor;
    final sign = amountMinorUnits < 0 ? '-' : '';
    if (digits == 0) {
      return '$sign$whole';
    }
    final fraction = magnitude % divisor;
    return '$sign$whole.${fraction.toString().padLeft(digits, '0')}';
  }

  /// Display string with Indian grouping and a currency symbol, for
  /// example `₹1,250.75` or `-₹1,250.75`.
  String format() {
    final digits = minorUnitDigits;
    final magnitude = BigInt.from(amountMinorUnits).abs();
    final divisor = _powerOfTen(digits);
    final whole = magnitude ~/ divisor;
    final grouped = _groupIndian(whole.toString());
    final sign = amountMinorUnits < 0 ? '-' : '';
    final symbol = currencySymbolFor(currencyCode);
    if (digits == 0) {
      return '$sign$symbol$grouped';
    }
    final fraction = magnitude % divisor;
    return '$sign$symbol$grouped.${fraction.toString().padLeft(digits, '0')}';
  }

  /// Display string (see [format]).
  @override
  String toString() => format();

  /// Adds two amounts in the same currency.
  ///
  /// Throws [StateError] when the result cannot be represented as a
  /// signed 64-bit integer.
  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(
      _checkedInt64(
        BigInt.from(amountMinorUnits) + BigInt.from(other.amountMinorUnits),
      ),
      currencyCode,
    );
  }

  /// Subtracts two amounts in the same currency.
  ///
  /// Throws [StateError] when the result cannot be represented as a
  /// signed 64-bit integer.
  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(
      _checkedInt64(
        BigInt.from(amountMinorUnits) - BigInt.from(other.amountMinorUnits),
      ),
      currencyCode,
    );
  }

  /// Negates the amount.
  ///
  /// Throws [StateError] for the minimum signed 64-bit value, whose
  /// negation cannot be represented.
  Money operator -() =>
      Money(_checkedInt64(-BigInt.from(amountMinorUnits)), currencyCode);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Compares by minor units. Throws on a currency mismatch.
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return amountMinorUnits.compareTo(other.amountMinorUnits);
  }

  void _requireSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'Cannot combine $currencyCode with ${other.currencyCode}.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    return other is Money &&
        other.amountMinorUnits == amountMinorUnits &&
        other.currencyCode == currencyCode;
  }

  @override
  int get hashCode => Object.hash(amountMinorUnits, currencyCode);
}
