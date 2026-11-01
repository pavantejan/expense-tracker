import 'package:drift/drift.dart';

/// A place money lives or is owed (blueprint section 5.2, V2 model).
///
/// Stage 1 only: table definition for the separate V2 database. No
/// balance column exists here; balances derive from postings in a later
/// stage. The mapping to a [LedgerAccounts] row is one-directional from
/// the ledger side, so account creation cannot deadlock on insertion
/// order. There is no `openingPostingId`: an opening balance is a
/// dedicated financial event, introduced in a later stage.
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get name => text()();

  /// `bank`, `cash`, `wallet`, `other_asset`, or
  /// `credit_card_liability`. Asset kinds map to a `user_asset` ledger
  /// account; `credit_card_liability` maps to a `user_liability` ledger
  /// account. The classification rules live in a later stage.
  TextColumn get kind => text()();

  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  /// Material icon code point, nullable when no icon was chosen.
  IntColumn get iconCodePoint => integer().nullable()();

  /// ARGB colour value, nullable when no colour was chosen.
  IntColumn get colorValue => integer().nullable()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get archivedAt => dateTime().nullable()();

  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
}
