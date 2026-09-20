import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'transactions.dart';
import 'app_settings.dart';

part 'app_database.g.dart';



@DriftDatabase(
  tables: [
    Transactions,
    AppSettings,
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(appSettings);
          }

          if (from < 3) {
            await m.addColumn(
              appSettings,
              appSettings.openingBalanceDate,
            );
          }
        },
      );
}