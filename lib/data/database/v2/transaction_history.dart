import 'package:drift/drift.dart';

import 'financial_transactions.dart';

/// Audit trail for transaction edits (blueprint section 5.2, V2 model).
///
/// Stage 1 only: table definition for the separate V2 database.
/// Append-only; retained with the transaction. Snapshots hold
/// structured field values (amounts as minor units, category id,
/// account ids), never full document text.
class TransactionHistory extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId =>
      integer().references(FinancialTransactions, #id)();

  DateTimeColumn get changedAt => dateTime()();

  /// `created`, `edited`, `deleted`, `restored`, or
  /// `renamed_category`. Stage 1 seeds no history rows; later stages
  /// write the first four kinds only.
  TextColumn get changeKind => text()();

  TextColumn get beforeSnapshot => text().nullable()();

  TextColumn get afterSnapshot => text().nullable()();
}
