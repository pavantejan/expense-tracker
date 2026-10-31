import 'package:drift/drift.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get type => text()();

  RealColumn get amount => real()();

  TextColumn get category => text()();

  TextColumn get description => text().nullable()();

  TextColumn get paymentMethod => text()();

  DateTimeColumn get transactionDate => dateTime()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// Local-only conditional-acknowledgement token. Incremented by
  /// one on every local mutation of the row (edit, delete,
  /// restore, category rename). Never written to Google Sheets:
  /// it exists only so a stale sync acknowledgement cannot mark
  /// a newer local revision as synced. `updatedAt` is timestamp
  /// metadata only and must not be used as the version token:
  /// Drift stores DateTime values with second precision, so
  /// same-second mutations can share an `updatedAt` value.
  IntColumn get syncRevision => integer().withDefault(const Constant(0))();

  TextColumn get syncStatus => text()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}
