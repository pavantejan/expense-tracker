import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:expense_tracker/data/database/v2/app_database_v2.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the frozen schema-8 fixture (captured from the Module 1
/// baseline before schema 9 existed) with some Module 1 data, then lets
/// Drift run the real upgrade.
AppDatabaseV2 _openV8WithData() {
  final schema = File('test/fixtures/schema_v8.sql').readAsStringSync();
  return AppDatabaseV2(
    NativeDatabase.memory(
      setup: (raw) {
        if (raw.select('PRAGMA user_version').single.values.first != 0) {
          return;
        }
        raw.execute(schema);
        raw.execute('''
          INSERT INTO categories (category_id, name, icon_code_point, kind, origin)
            VALUES ('food', 'Food', 1, 'both', 'builtin');
          INSERT INTO accounts (uuid, name, kind) VALUES ('acc-1', 'Bank', 'bank');
          INSERT INTO financial_transactions
            (uuid, kind, category_id, amount_minor_units, payment_channel,
             occurred_at, status, source, created_at, updated_at, sync_status)
            VALUES ('tx-1', 'expense', 'food', 25050, 'UPI', 1767225600,
                    'active', 'manual', 1767225600, 1767225600, 'synced');
        ''');
        raw.execute('PRAGMA user_version = 8');
      },
    ),
  );
}

void main() {
  test('v8 to v9 adds merchants, tags, templates and keeps data', () async {
    final db = _openV8WithData();
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 9);

    final tables =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='table'",
                )
                .get())
            .map((r) => r.read<String>('name'))
            .toSet();
    expect(
      tables,
      containsAll([
        'merchants',
        'tags',
        'transaction_tags',
        'transaction_templates',
      ]),
    );
    final indexes =
        (await db
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='index'",
                )
                .get())
            .map((r) => r.read<String>('name'));
    expect(indexes, contains('transaction_tags_tag'));

    final tx = await db.select(db.financialTransactions).getSingle();
    expect(tx.uuid, 'tx-1');
    expect(tx.amountMinorUnits, 25050);
    expect(tx.merchantId, isNull);
    expect(tx.syncStatus, 'synced', reason: 'migration never re-syncs');

    // The new relationships work and foreign keys are enforced.
    await db
        .into(db.merchants)
        .insert(
          MerchantsCompanion.insert(
            uuid: 'm-1',
            name: 'Swiggy',
            nameKey: 'swiggy',
            createdAt: DateTime(2026),
          ),
        );
    await (db.update(db.financialTransactions)
          ..where((t) => t.uuid.equals('tx-1')))
        .write(const FinancialTransactionsCompanion(merchantId: Value('m-1')));
    expect(
      () =>
          (db.update(
            db.financialTransactions,
          )..where((t) => t.uuid.equals('tx-1'))).write(
            const FinancialTransactionsCompanion(merchantId: Value('nope')),
          ),
      throwsA(isA<SqliteException>()),
    );
    final problems = await db.customSelect('PRAGMA foreign_key_check').get();
    expect(problems, isEmpty);
  });
}
