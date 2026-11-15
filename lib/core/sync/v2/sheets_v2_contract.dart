// Google Sheets V2 compatibility contract (blueprint section 8,
// ADR-006, ADR-015).
//
// Pure Dart: no Flutter, googleapis, or Drift imports, so the contract
// is unit-testable on its own. Columns A:J keep the V1 headers in V1
// order; K:Y are the frozen V2 extension. Amounts cross the Sheets
// boundary only through [sheetAmountFromMinorUnits] and
// [minorUnitsFromSheetAmount]; no code divides paise by 100 as a
// double.

import '../../domain/money.dart';

/// Worksheet headers A:Y, frozen for sheet schema version 2.
const List<String> sheetV2Headers = <String>[
  'Date', // A
  'Type', // B
  'Category', // C
  'Description', // D
  'Amount', // E
  'UUID', // F
  'PaymentMethod', // G
  'Notes', // H
  'UpdatedAt', // I
  'Deleted', // J
  'Kind', // K
  'CategoryId', // L
  'AccountId', // M
  'Account', // N
  'FromAccountId', // O
  'FromAccount', // P
  'ToAccountId', // Q
  'ToAccount', // R
  'CardId', // S
  'Merchant', // T
  'Tags', // U
  'OriginalUuid', // V
  'RelatedUuid', // W
  'Source', // X
  'BalanceDirection', // Y
];

/// Last column letter of the V2 contract.
const String sheetV2LastColumn = 'Y';

/// Spreadsheet title of the V2 identity. The V1 spreadsheet is titled
/// `Expense Tracker` and is never written by V2 code.
const String sheetsV2SpreadsheetTitle = 'Expense Tracker v2';

/// Drive `appProperties` marker that identifies the V2 spreadsheet.
const String sheetsV2AppPropertyKey = 'expenseTrackerSchemaVersion';
const String sheetsV2AppPropertyValue = '2';

/// Worksheet recording the sheet schema version. A spreadsheet without
/// it (and with data) is treated as V1 and never written.
const String sheetsV2MetaTitle = '_meta';
const String sheetsV2MetaVersionKey = 'sheetSchemaVersion';
const String sheetsV2MetaVersionValue = '2';
const String sheetsV2MetaWriterKey = 'writerVersion';
const String sheetsV2WriterVersion = 'expense_tracker 1.0.0';

/// Largest paise value whose numeric cell round-trips exactly
/// (blueprint section 8.5): the largest value below 2^46 rupees.
const int maxSheetAmountPaise = 7036874417766399;

/// Local `FinancialTransaction.kind` -> Sheets `Type`/`Kind` label.
const Map<String, String> sheetKindLabels = <String, String>{
  'expense': 'Expense',
  'income': 'Income',
  'transfer': 'Transfer',
  'card_payment': 'CardPayment',
  'refund': 'Refund',
  'adjustment': 'Adjustment',
  'opening_balance': 'OpeningBalance',
  'reversal': 'Reversal',
};

/// Sheets label for a local kind. Unknown kinds are a programming
/// error and throw [ArgumentError]; they are never coerced.
String sheetKindLabelFor(String kind) {
  final label = sheetKindLabels[kind];
  if (label == null) {
    throw ArgumentError('Unknown transaction kind: $kind');
  }
  return label;
}

/// Local kind for a Sheets label, by exact match. Unknown labels throw
/// [FormatException] and are never read as Expense/Income.
String kindFromSheetLabel(String label) {
  for (final entry in sheetKindLabels.entries) {
    if (entry.value == label) {
      return entry.key;
    }
  }
  throw FormatException('Unknown sheet transaction type: $label');
}

/// Opening-balance sign relative to the account's normal balance
/// (column Y).
enum SheetBalanceDirection {
  positive('positive'),
  negative('negative');

  const SheetBalanceDirection(this.value);

  final String value;

  SheetBalanceDirection get inverted => this == SheetBalanceDirection.positive
      ? SheetBalanceDirection.negative
      : SheetBalanceDirection.positive;

  static SheetBalanceDirection? tryParse(String value) {
    for (final direction in values) {
      if (direction.value == value) {
        return direction;
      }
    }
    return null;
  }
}

/// An amount that cannot be represented exactly as a numeric cell.
class SheetAmountOutOfRangeException implements Exception {
  const SheetAmountOutOfRangeException(this.amountMinorUnits);

  final int amountMinorUnits;

  @override
  String toString() =>
      'SheetAmountOutOfRangeException: amount exceeds the Sheets limit '
      'of $maxSheetAmountPaise minor units.';
}

/// Converts stored minor units to the numeric cell value written to
/// `Amount`. The decimal is derived from the integer by string
/// arithmetic ([Money.toDecimalString]) and then parsed; there is no
/// floating-point division. Throws [SheetAmountOutOfRangeException]
/// for negative values or values above [maxSheetAmountPaise].
num sheetAmountFromMinorUnits(
  int amountMinorUnits, {
  String currencyCode = 'INR',
}) {
  if (amountMinorUnits < 0 || amountMinorUnits > maxSheetAmountPaise) {
    throw SheetAmountOutOfRangeException(amountMinorUnits);
  }
  final decimal = Money(amountMinorUnits, currencyCode).toDecimalString();
  return num.parse(decimal);
}

/// Reads a numeric (or numeric-text) `Amount` cell back to minor units
/// via decimal-string parsing with importer normalisation. Throws
/// [FormatException] for a non-numeric cell and
/// [SheetAmountOutOfRangeException] above the representation limit.
int minorUnitsFromSheetAmount(Object? cell, {String currencyCode = 'INR'}) {
  if (cell == null) {
    throw const FormatException('Amount cell is empty.');
  }
  final text = cell is num ? _numToDecimalText(cell) : cell.toString().trim();
  final minorUnits = Money.parseNormalised(
    text,
    currencyCode: currencyCode,
  ).amountMinorUnits;
  if (minorUnits < 0 || minorUnits > maxSheetAmountPaise) {
    throw SheetAmountOutOfRangeException(minorUnits);
  }
  return minorUnits;
}

String _numToDecimalText(num value) {
  if (value is int) {
    return value.toString();
  }
  final text = value.toString();
  if (text.contains('e') || text.contains('E')) {
    // Exponent notation only appears far outside the supported range
    // (or for sub-paisa values); reject rather than guess.
    throw FormatException('Amount cell is out of range: $text');
  }
  return text;
}

/// One row of a V2 year worksheet, A:Y. [rowIndex] is the 1-based sheet
/// row when the row already exists, `null` for a row not yet written.
///
/// [amount] holds the cell value as written/read, so a tombstone
/// rewrite of an existing row never re-derives or alters the amount.
class SheetV2Row {
  const SheetV2Row({
    required this.dateText,
    required this.type,
    required this.category,
    required this.description,
    required this.amount,
    required this.uuid,
    required this.paymentMethod,
    required this.notes,
    required this.updatedAt,
    required this.deleted,
    required this.kind,
    this.categoryId = '',
    this.accountId = '',
    this.account = '',
    this.fromAccountId = '',
    this.fromAccount = '',
    this.toAccountId = '',
    this.toAccount = '',
    this.cardId = '',
    this.merchant = '',
    this.tags = '',
    this.originalUuid = '',
    this.relatedUuid = '',
    this.source = '',
    this.balanceDirection = '',
    this.rowIndex,
  });

  final String dateText;
  final String type;
  final String category;
  final String description;
  final Object? amount;
  final String uuid;
  final String paymentMethod;
  final String notes;
  final String updatedAt;
  final bool deleted;
  final String kind;
  final String categoryId;
  final String accountId;
  final String account;
  final String fromAccountId;
  final String fromAccount;
  final String toAccountId;
  final String toAccount;
  final String cardId;
  final String merchant;
  final String tags;
  final String originalUuid;
  final String relatedUuid;
  final String source;
  final String balanceDirection;
  final int? rowIndex;

  factory SheetV2Row.fromValues(List<Object?> values, int rowIndex) {
    String textAt(int index) {
      if (index >= values.length) {
        return '';
      }
      final value = values[index];
      return value == null ? '' : value.toString();
    }

    return SheetV2Row(
      dateText: textAt(0),
      type: textAt(1),
      category: textAt(2),
      description: textAt(3),
      amount: values.length > 4 ? values[4] : null,
      uuid: textAt(5),
      paymentMethod: textAt(6),
      notes: textAt(7),
      updatedAt: textAt(8),
      deleted: textAt(9).toLowerCase() == 'true',
      kind: textAt(10),
      categoryId: textAt(11),
      accountId: textAt(12),
      account: textAt(13),
      fromAccountId: textAt(14),
      fromAccount: textAt(15),
      toAccountId: textAt(16),
      toAccount: textAt(17),
      cardId: textAt(18),
      merchant: textAt(19),
      tags: textAt(20),
      originalUuid: textAt(21),
      relatedUuid: textAt(22),
      source: textAt(23),
      balanceDirection: textAt(24),
      rowIndex: rowIndex,
    );
  }

  List<Object?> toValues() {
    return <Object?>[
      dateText,
      type,
      category,
      description,
      amount,
      uuid,
      paymentMethod,
      notes,
      updatedAt,
      deleted ? 'TRUE' : 'FALSE',
      kind,
      categoryId,
      accountId,
      account,
      fromAccountId,
      fromAccount,
      toAccountId,
      toAccount,
      cardId,
      merchant,
      tags,
      originalUuid,
      relatedUuid,
      source,
      balanceDirection,
    ];
  }

  /// Copy used for tombstoning an existing row: only [deleted],
  /// [updatedAt] and [rowIndex] change; every other cell is kept.
  SheetV2Row copyWith({bool? deleted, String? updatedAt, int? rowIndex}) {
    return SheetV2Row(
      dateText: dateText,
      type: type,
      category: category,
      description: description,
      amount: amount,
      uuid: uuid,
      paymentMethod: paymentMethod,
      notes: notes,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      kind: kind,
      categoryId: categoryId,
      accountId: accountId,
      account: account,
      fromAccountId: fromAccountId,
      fromAccount: fromAccount,
      toAccountId: toAccountId,
      toAccount: toAccount,
      cardId: cardId,
      merchant: merchant,
      tags: tags,
      originalUuid: originalUuid,
      relatedUuid: relatedUuid,
      source: source,
      balanceDirection: balanceDirection,
      rowIndex: rowIndex ?? this.rowIndex,
    );
  }
}
