import 'package:drift/drift.dart';

import 'financial_transactions.dart';
import 'ledger_accounts.dart';

/// One side of a balanced financial event (blueprint section 5.2, V2
/// model). Postings are the single source of truth for balances.
///
/// Stage 1 only: table definition for the separate V2 database. A
/// posting references one valid ledger account, carries a distinct
/// direction, and an always-positive integer amount. Postings are never
/// edited directly; they are replaced atomically with their transaction
/// in a later stage.
class Postings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId =>
      integer().references(FinancialTransactions, #id)();

  TextColumn get ledgerAccountId =>
      text().references(LedgerAccounts, #ledgerAccountId)();

  /// `debit` or `credit`. Distinct values, never a signed amount.
  TextColumn get direction => text()();

  /// Always strictly positive; direction carries the sign. Zero-amount
  /// postings are forbidden by the table-level CHECK constraint below
  /// (a column-level `.check(...)` expression would read as a
  /// self-referencing getter to the analyzer).
  IntColumn get amountMinorUnits => integer()();

  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  /// Equals the transaction date in V1.
  DateTimeColumn get postingDate => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (amount_minor_units > 0)',
  ];
}
