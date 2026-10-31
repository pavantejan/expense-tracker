import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:expense_tracker/data/database/app_database.dart';
import 'package:expense_tracker/data/repositories/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Migration test for schema v6 -> v7.
///
/// A version-6 database is built with raw SQL (the exact v6
/// column set, no `sync_revision` column, `user_version` 6),
/// containing one transaction and one custom category. Opening
/// it with the current [AppDatabase] must run the migration,
/// preserve the data, and initialize `syncRevision` to 0.
/// The generated Drift code is exercised as-is; nothing here
/// hand-writes generated schema code.
void main() {
  late Directory tempDir;
  late File dbFile;
  AppDatabase? database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expense-tracker-v6-');
    dbFile = File('${tempDir.path}/expense_tracker.db');
  });

  tearDown(() async {
    await database?.close();
    database = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> createVersion6Database() async {
    // Raw sqlite3 (test-only dependency): no Drift schema is
    // involved in building the fixture, so the fixture really
    // is a version-6 database.
    final db = sqlite3.open(dbFile.path);
    try {
      db.execute('''
        CREATE TABLE transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          type TEXT NOT NULL,
          amount REAL NOT NULL,
          category TEXT NOT NULL,
          description TEXT,
          payment_method TEXT NOT NULL,
          transaction_date INTEGER NOT NULL,
          notes TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          sync_status TEXT NOT NULL,
          deleted INTEGER NOT NULL DEFAULT 0 CHECK ("deleted" IN (0, 1))
        )
      ''');
      db.execute('''
        CREATE TABLE custom_categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          icon_code_point INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      db.execute('''
        CREATE TABLE notifications (
          id TEXT NOT NULL PRIMARY KEY,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_read INTEGER NOT NULL DEFAULT 0 CHECK ("is_read" IN (0, 1))
        )
      ''');
      // DateTime values are stored as Unix timestamps in seconds.
      const createdAt = 1767225600; // 2026-01-01T00:00:00Z
      db.execute(
        "INSERT INTO transactions (uuid, type, amount, category, "
        "description, payment_method, transaction_date, notes, "
        "created_at, updated_at, sync_status, deleted) VALUES "
        "('mig-txn-1', 'Expense', 250.0, 'Food', 'Lunch', 'UPI', "
        "$createdAt, NULL, $createdAt, $createdAt, 'pending', 0)",
      );
      db.execute(
        "INSERT INTO custom_categories (uuid, name, icon_code_point, "
        "created_at) VALUES ('mig-cat-1', 'Gym', 57444, $createdAt)",
      );
      db.execute('PRAGMA user_version = 6');
    } finally {
      db.close();
    }
  }

  test('v6 database upgrades to v7 preserving data with revision 0', () async {
    await createVersion6Database();

    database = AppDatabase(NativeDatabase(dbFile));
    expect(database!.schemaVersion, 7);

    final transactions = TransactionRepository(database!);
    final row = await transactions.getTransactionById(1);
    expect(row, isNotNull);
    expect(row!.uuid, 'mig-txn-1');
    expect(row.type, 'Expense');
    expect(row.amount, 250);
    expect(row.category, 'Food');
    expect(row.description, 'Lunch');
    expect(row.paymentMethod, 'UPI');
    expect(row.syncStatus, 'pending');
    expect(row.deleted, isFalse);
    expect(row.syncRevision, 0);

    final categories = await database!.select(database!.customCategories).get();
    expect(categories, hasLength(1));
    expect(categories.single.name, 'Gym');

    // The migrated row behaves like any other row: its first
    // local mutation advances the revision from 0 to 1.
    await transactions.updateTransaction(
      1,
      TransactionsCompanion(amount: const Value(260)),
    );
    final mutated = await transactions.getTransactionById(1);
    expect(mutated!.syncRevision, 1);
    expect(mutated.amount, 260);
    expect(mutated.category, 'Food');

    // A new transaction in the migrated database starts at 0.
    final newId = await transactions.addTransaction(
      TransactionsCompanion.insert(
        uuid: 'mig-txn-2',
        type: 'Expense',
        amount: 50,
        category: 'Travel',
        paymentMethod: 'Cash',
        transactionDate: DateTime(2026, 1, 20),
        createdAt: DateTime(2026, 1, 20),
        updatedAt: DateTime(2026, 1, 20),
        syncStatus: 'pending',
      ),
    );
    expect((await transactions.getTransactionById(newId))!.syncRevision, 0);
  });
}
