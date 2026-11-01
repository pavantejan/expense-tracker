// Integer minor-unit money (ADR-001, ADR-016).
//
// All persisted and computed financial amounts are integer minor units
// (paise for INR). This is the only place that converts between minor
// units, decimal strings, and display strings. No financial arithmetic
// in this file uses `double`: parsing and formatting use decimal-string
// and integer arithmetic only.
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

/// Number of minor units per major unit for a currency code.
int minorUnitDigitsForCurrency(String currencyCode) {
  switch (currencyCode) {
    case 'JPY':
    case 'KRW':
      return 0;
    default:
      // INR, USD, EUR, GBP and other two-decimal currencies. V1 uses INR
      // only; the code is carried on every money-bearing row so a future
      // currency choice does not need a schema redesign (ADR-002).
      return 2;
  }
}

/// Display symbol for a currency code, or the code itself when unknown.
String currencySymbolFor(String currencyCode) {
  switch (currencyCode) {
    case 'INR':
      return '₹';
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    default:
      return currencyCode;
  }
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
class Money {
  /// Creates money from an integer minor-unit amount (paise for INR).
  const Money(this.amountMinorUnits, this.currencyCode);

  /// Zero money in [currencyCode].
  const Money.zero(this.currencyCode) : amountMinorUnits = 0;

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
  Money abs() => Money(amountMinorUnits.abs(), currencyCode);

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
    return negative ? -magnitude : magnitude;
  }

  static int _toMinorUnits({
    required String integerPart,
    required String fractionalPart,
    required int digits,
    required bool normalise,
  }) {
    final maxMinorUnits = BigInt.from(9223372036854775807);
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
    if (combined > maxMinorUnits) {
      throw const FormatException('Amount is too large.');
    }
    return combined.toInt();
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

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(amountMinorUnits + other.amountMinorUnits, currencyCode);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(amountMinorUnits - other.amountMinorUnits, currencyCode);
  }

  Money operator -() => Money(-amountMinorUnits, currencyCode);

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
