// CSV export of transactions (Module 3).
//
// RFC 4180 quoting, CRLF line endings, UTF-8 with a BOM so spreadsheet
// apps detect the encoding. Amounts are decimal strings derived from
// integer paise (no `double`). Cells that a spreadsheet would treat as
// a formula (=, +, -, @, tab, CR) are prefixed with an apostrophe to
// block CSV formula injection; the numeric Amount column is never text
// that starts with those characters because amounts are always
// positive and the sign lives in the Direction column.

import '../../data/repositories/ledger_query_service.dart';
import '../domain/money.dart';

const List<String> csvHeaders = <String>[
  'Date',
  'Type',
  'Direction',
  'Amount',
  'Currency',
  'Category',
  'Merchant',
  'Description',
  'Account',
  'From account',
  'To account',
  'Payment method',
  'Tags',
  'Notes',
  'Source',
  'UUID',
];

const Map<String, String> _kindLabels = <String, String>{
  'expense': 'Expense',
  'income': 'Income',
  'transfer': 'Transfer',
  'card_payment': 'Card payment',
  'refund': 'Refund',
  'adjustment': 'Adjustment',
  'opening_balance': 'Opening balance',
  'reversal': 'Reversal',
};

String transactionsToCsv(List<TransactionView> views) {
  final buffer = StringBuffer('\uFEFF');
  buffer.write(csvHeaders.map(_cell).join(','));
  buffer.write('\r\n');
  for (final view in views) {
    final tx = view.transaction;
    final local = tx.occurredAt.toLocal();
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final direction = switch (view.flow) {
      DisplayFlow.inflow => 'In',
      DisplayFlow.outflow => 'Out',
      DisplayFlow.neutral => 'Between accounts',
    };
    final fields = <String>[
      date,
      _kindLabels[tx.kind] ?? tx.kind,
      direction,
      Money(tx.amountMinorUnits, tx.currencyCode).toDecimalString(),
      tx.currencyCode,
      view.category?.name ?? '',
      view.merchant?.name ?? '',
      tx.description ?? '',
      view.account?.name ?? '',
      view.sourceAccount?.name ?? '',
      view.destinationAccount?.name ?? '',
      tx.paymentChannel,
      view.tags.map((t) => t.name).join(', '),
      tx.notes ?? '',
      tx.source,
      tx.uuid,
    ];
    buffer.write(fields.map(_cell).join(','));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

String _cell(String value) {
  var text = value;
  if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
    text = "'$text";
  }
  if (text.contains(RegExp('[",\r\n]'))) {
    return '"${text.replaceAll('"', '""')}"';
  }
  return text;
}
