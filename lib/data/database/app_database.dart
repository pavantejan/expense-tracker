import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'transactions.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'expense_tracker',
    );
  }

  @override
  int get schemaVersion => 1;
}