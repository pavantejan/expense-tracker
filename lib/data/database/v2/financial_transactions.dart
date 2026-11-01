import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';

/// The business event the user understands (blueprint section 5.2, V2
/// model): a purchase, salary, transfer, payment, refund, adjustment,
/// opening balance, or reversal.
///
/// Stage 1 only: table definition for the separate V2 database. Amounts
/// are integer minor units and always positive; direction lives in
/// postings. There is no `accountId` column: the account for an
/// expense or income row is derived from its postings in a later stage
/// (approved decision 3). There is no `candidateId` and no
/// `transferGroupId`. `status` has only `active` and `deleted`;
/// "reversed" is derived from an active reversal row, never stored.
@TableIndex(name: 'financial_transactions_occurred_at', columns: {#occurredAt})
@TableIndex(
  name: 'financial_transactions_reverses',
  columns: {#reversesTransactionId},
)
@TableIndex(
  name: 'financial_transactions_related',
  columns: {#relatedTransactionId},
)
@TableIndex(name: 'financial_transactions_kind', columns: {#kind})
class FinancialTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  /// `expense`, `income`, `transfer`, `card_payment`, `refund`,
  /// `adjustment`, `opening_balance`, or `reversal`.
  TextColumn get kind => text()();

  /// Stable category id. Nullable for transfers, card payments, and
  /// opening balances. For a refund, the immutable category snapshot
  /// taken from the original at refund creation (later stages).
  TextColumn get categoryId =>
      text().nullable().references(Categories, #categoryId)();

  /// Set on refunds and reversals, pointing at the original
  /// transaction by uuid.
  @ReferenceName('reversingTransactions')
  TextColumn get reversesTransactionId =>
      text().nullable().references(FinancialTransactions, #uuid)();

  /// Set on adjustments that correct another transaction, for
  /// example an opening-balance correction.
  @ReferenceName('relatedTransactions')
  TextColumn get relatedTransactionId =>
      text().nullable().references(FinancialTransactions, #uuid)();

  /// Required exactly when [kind] is `transfer` or `card_payment`:
  /// the funding account for a card payment.
  @ReferenceName('sourceTransactions')
  TextColumn get sourceAccountId =>
      text().nullable().references(Accounts, #uuid)();

  /// Required exactly when [kind] is `transfer` or `card_payment`.
  @ReferenceName('destinationTransactions')
  TextColumn get destinationAccountId =>
      text().nullable().references(Accounts, #uuid)();

  /// Required exactly when [kind] is `refund`: the account money
  /// returns to or is paid out of.
  @ReferenceName('refundTransactions')
  TextColumn get refundAccountId =>
      text().nullable().references(Accounts, #uuid)();

  /// Event amount in integer minor units, always strictly positive.
  /// For a refund, the refunded amount; for a transfer, the moved
  /// amount; for an opening balance, the absolute opening amount.
  /// Positivity is enforced by the table-level CHECK constraint below
  /// (a column-level `.check(...)` expression would read as a
  /// self-referencing getter to the analyzer).
  IntColumn get amountMinorUnits => integer()();

  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  TextColumn get description => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// UPI, cash, card, or bank. Replaces the old free-text payment
  /// method; canonical stored values are used internally while the
  /// existing display labels remain (approved decision 5).
  TextColumn get paymentChannel => text()();

  DateTimeColumn get occurredAt => dateTime()();

  /// `active` or `deleted` only.
  TextColumn get status => text()();

  /// `manual`, `recurring`, `import`, or `template`.
  TextColumn get source => text()();

  /// Required exactly when [kind] is `adjustment`:
  /// `opening_balance_correction`, `balance_correction`,
  /// `fee_correction`, or `other`.
  TextColumn get adjustmentReason => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Local-only conditional-acknowledgement token, as established in
  /// PR #2. Never written to Google Sheets.
  IntColumn get syncRevision => integer().withDefault(const Constant(0))();

  TextColumn get syncStatus => text()();

  @override
  List<String> get customConstraints => const [
    'CHECK (amount_minor_units > 0)',
  ];
}
