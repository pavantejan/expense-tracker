import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'transactions.dart';
import 'custom_categories.dart';
import 'notifications.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Transactions, CustomCategories, Notifications])
class AppDatabase extends _$AppDatabase {
  /// [executor] is test-only: production code uses the default
  /// file-backed connection. Tests pass `NativeDatabase.memory()`
  /// for an in-memory database. This changes no schema, table,
  /// or migration: the schema version and migration strategy
  /// below are untouched.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'expense_tracker');
  }

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.database.customStatement(
          'CREATE TABLE IF NOT EXISTS app_settings '
          '(id INTEGER NOT NULL PRIMARY KEY, '
          'opening_balance REAL NOT NULL DEFAULT 0)',
        );
      }

      if (from < 3) {
        await m.database.customStatement(
          'ALTER TABLE app_settings '
          'ADD COLUMN opening_balance_date INTEGER',
        );
      }

      if (from < 4) {
        await m.createTable(customCategories);
      }

      if (from < 5) {
        await m.database.customStatement('DROP TABLE IF EXISTS app_settings');
      }

      if (from < 6) {
        await m.createTable(notifications);
      }

      if (from < 7) {
        // Local-only conditional-acknowledgement token (see
        // Transactions.syncRevision). Existing rows start at
        // revision 0; their first subsequent local mutation
        // advances it. No data is moved or rewritten.
        await m.addColumn(transactions, transactions.syncRevision);
      }
    },
  );
}
