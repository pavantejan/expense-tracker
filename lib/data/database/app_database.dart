import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'transactions.dart';
import 'custom_categories.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Transactions,
    CustomCategories,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'expense_tracker',
    );
  }

  @override
  int get schemaVersion => 5;

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
            await m.database.customStatement(
              'DROP TABLE IF EXISTS app_settings',
            );
          }
        },
      );
}