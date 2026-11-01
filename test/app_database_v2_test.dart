import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/database_factory.dart';
import 'package:expense_tracker/data/database/v2/app_database_v2.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 1 tests for the separate V2 database.
///
/// These tests use only the V2 database and the V2 factory. They never
/// open the existing database, and they import no existing table,
/// repository, or provider file. Production startup is untouched in
/// Stage 1, so the old database remains the only database the app
/// opens in production.
void main() {
  const factory = AppDatabaseV2Factory();

  group('AppDatabaseV2 schema and baseline seeding', () {
    late AppDatabaseV2 database;

    setUp(() async {
      database = await factory.create(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('schema version is 8 and all V2 tables exist', () async {
      expect(database.schemaVersion, 8);
      final rows = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = rows.map((row) => row.data['name'] as String).toSet();
      expect(
        names,
        containsAll(<String>[
          'accounts',
          'ledger_accounts',
          'categories',
          'financial_transactions',
          'postings',
          'transaction_history',
          'app_settings',
          'notifications',
        ]),
      );
    });

    test('schema SQL declares foreign keys and amount checks', () async {
      final rows = await database
          .customSelect(
            "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('financial_transactions', 'postings')",
          )
          .get();
      final sqlByName = <String, String>{
        for (final row in rows)
          row.data['name'] as String: row.data['sql'] as String,
      };
      final transactionsSql = sqlByName['financial_transactions']!;
      expect(transactionsSql, contains('REFERENCES categories'));
      expect(transactionsSql, contains('REFERENCES accounts'));
      expect(transactionsSql, contains('REFERENCES financial_transactions'));
      expect(transactionsSql, contains('CHECK (amount_minor_units > 0)'));
      final postingsSql = sqlByName['postings']!;
      expect(postingsSql, contains('REFERENCES financial_transactions'));
      expect(postingsSql, contains('REFERENCES ledger_accounts'));
      expect(postingsSql, contains('CHECK (amount_minor_units > 0)'));
    });

    test('seeds eight built-in categories, all kind both', () async {
      final categories = await database.select(database.categories).get();
      expect(categories, hasLength(8));
      expect(categories.map((c) => c.categoryId).toSet(), <String>{
        'food',
        'travel',
        'shopping',
        'bills',
        'entertainment',
        'health',
        'education',
        'other',
      });
      for (final category in categories) {
        expect(category.kind, 'both');
        expect(category.origin, 'builtin');
        expect(category.isArchived, isFalse);
        expect(category.parentCategoryId, isNull);
      }
      final names = {for (final c in categories) c.categoryId: c.name};
      expect(names['food'], 'Food');
      expect(names['travel'], 'Travel');
      expect(names['other'], 'Other');
    });

    test('seeds eighteen system ledger accounts', () async {
      final ledgers = await database.select(database.ledgerAccounts).get();
      // One opening-equity row, one adjustments row, and two rows
      // (expense and income) for each of the eight categories.
      expect(ledgers, hasLength(18));
      final byId = {for (final l in ledgers) l.ledgerAccountId: l};
      final opening = byId['opening_equity']!;
      expect(opening.kind, 'system_opening_equity');
      expect(opening.normalBalance, 'credit');
      expect(opening.isSystem, isTrue);
      expect(opening.userAccountId, isNull);
      expect(opening.categoryId, isNull);
      final adjustments = byId['adjustments']!;
      expect(adjustments.kind, 'system_adjustment');
      expect(adjustments.normalBalance, 'credit');
      expect(adjustments.isSystem, isTrue);
      final foodExpense = byId['expense:food']!;
      expect(foodExpense.kind, 'system_expense');
      expect(foodExpense.categoryId, 'food');
      expect(foodExpense.normalBalance, 'debit');
      final foodIncome = byId['income:food']!;
      expect(foodIncome.kind, 'system_income');
      expect(foodIncome.categoryId, 'food');
      expect(foodIncome.normalBalance, 'credit');
      for (final ledger in ledgers) {
        expect(ledger.isArchived, isFalse);
      }
    });

    test('seeds exactly one settings row', () async {
      final settings = await database.select(database.appSettings).get();
      expect(settings, hasLength(1));
      final row = settings.single;
      expect(row.id, 1);
      expect(row.currencyCode, 'INR');
      expect(row.defaultAccountId, isNull);
      expect(row.themeMode, 'system');
      expect(row.appLockEnabled, isFalse);
      // Retention default is unresolved (blueprint section 16.2).
      expect(row.documentRetentionDays, isNull);
      expect(row.defaultReminderDays, 1);
      expect(row.sheetsBackupEnabled, isTrue);
      expect(row.setupCompleted, isFalse);
    });

    test('seeds no accounts, transactions, postings, or history', () async {
      expect(await database.select(database.accounts).get(), isEmpty);
      expect(
        await database.select(database.financialTransactions).get(),
        isEmpty,
      );
      expect(await database.select(database.postings).get(), isEmpty);
      expect(await database.select(database.transactionHistory).get(), isEmpty);
      expect(await database.select(database.notifications).get(), isEmpty);
    });

    test('creating a second in-memory database seeds independently', () async {
      final second = await factory.create(executor: NativeDatabase.memory());
      addTearDown(second.close);
      final categories = await second.select(second.categories).get();
      expect(categories, hasLength(8));
      final ledgers = await second.select(second.ledgerAccounts).get();
      expect(ledgers, hasLength(18));
    });
  });

  group('AppDatabaseV2Factory database identity', () {
    test(
      'production factory configuration uses exactly expense_tracker_v2',
      () async {
        expect(expenseTrackerV2DatabaseName, 'expense_tracker_v2');
        expect(expenseTrackerV2DatabaseName, isNot('expense_tracker'));

        final requestedNames = <String>[];
        QueryExecutor fakeOpener(String name) {
          requestedNames.add(name);
          return NativeDatabase.memory();
        }

        // No explicit executor: this exercises the production code path
        // (default opener) with the opener seam substituted, and needs
        // no Flutter platform channels.
        final database = await factory.create(opener: fakeOpener);
        addTearDown(database.close);

        expect(requestedNames, ['expense_tracker_v2']);
        expect(requestedNames, isNot(contains('expense_tracker')));
        // The database returned through that path is seeded and usable.
        expect(await database.select(database.categories).get(), hasLength(8));
      },
    );

    test('explicit executor bypasses the opener entirely', () async {
      var openerCalled = false;
      QueryExecutor fakeOpener(String name) {
        openerCalled = true;
        return NativeDatabase.memory();
      }

      final database = await factory.create(
        executor: NativeDatabase.memory(),
        opener: fakeOpener,
      );
      addTearDown(database.close);
      expect(openerCalled, isFalse);
      expect(await database.select(database.categories).get(), hasLength(8));
    });
  });

  group('AppDatabaseV2 reopen and idempotent seeding', () {
    late Directory tempDir;
    late File dbFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('expense-tracker-v2-');
      dbFile = File('${tempDir.path}/expense_tracker_v2.db');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reopening the same file never duplicates seed rows', () async {
      final first = await factory.create(executor: NativeDatabase(dbFile));
      // A marker row proves persistence across reopen, not just
      // seeding: it must survive close and reopen exactly once.
      await first
          .into(first.accounts)
          .insert(
            AccountsCompanion.insert(
              uuid: 'acct-reopen',
              name: 'Bank',
              kind: 'bank',
            ),
          );
      await first.close();

      final second = await factory.create(executor: NativeDatabase(dbFile));
      addTearDown(second.close);
      expect(await second.select(second.categories).get(), hasLength(8));
      expect(await second.select(second.ledgerAccounts).get(), hasLength(18));
      expect(await second.select(second.appSettings).get(), hasLength(1));
      final accounts = await second.select(second.accounts).get();
      expect(accounts, hasLength(1));
      expect(accounts.single.uuid, 'acct-reopen');

      await second.close();
      final third = await factory.create(executor: NativeDatabase(dbFile));
      addTearDown(third.close);
      expect(await third.select(third.categories).get(), hasLength(8));
      expect(await third.select(third.ledgerAccounts).get(), hasLength(18));
      expect(await third.select(third.accounts).get(), hasLength(1));
    });
  });

  group('AppDatabaseV2 foreign-key enforcement', () {
    late AppDatabaseV2 database;

    setUp(() async {
      database = await factory.create(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    test('foreign keys are enabled', () async {
      final rows = await database.customSelect('PRAGMA foreign_keys').get();
      expect(rows, hasLength(1));
      expect(rows.single.data.values.single, 1);
    });

    FinancialTransactionsCompanion transactionWith({
      Value<String?> categoryId = const Value.absent(),
      Value<String?> reversesId = const Value.absent(),
      Value<String?> relatedId = const Value.absent(),
      Value<String?> sourceId = const Value.absent(),
      Value<String?> destinationId = const Value.absent(),
      Value<String?> refundId = const Value.absent(),
      String kind = 'expense',
      String? uuid,
    }) {
      final now = DateTime(2026, 1, 15);
      return FinancialTransactionsCompanion.insert(
        uuid: uuid ?? 'v2-txn-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        categoryId: categoryId,
        reversesTransactionId: reversesId,
        relatedTransactionId: relatedId,
        sourceAccountId: sourceId,
        destinationAccountId: destinationId,
        refundAccountId: refundId,
        amountMinorUnits: 50000,
        paymentChannel: 'UPI',
        occurredAt: now,
        status: 'active',
        source: 'manual',
        createdAt: now,
        updatedAt: now,
        syncStatus: 'pending',
      );
    }

    Future<void> insertAccount(String uuid) async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(uuid: uuid, name: 'Bank', kind: 'bank'),
          );
    }

    test(
      'rejects a ledger account referencing a missing user account',
      () async {
        // No category reference: the user-account FK is the only
        // reference that can reject this row.
        await expectLater(
          () => database
              .into(database.ledgerAccounts)
              .insert(
                LedgerAccountsCompanion.insert(
                  ledgerAccountId: 'ledger-missing-account',
                  kind: 'user_asset',
                  userAccountId: const Value('missing-account'),
                  normalBalance: 'debit',
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('rejects a ledger account referencing a missing category', () async {
      // No user-account reference: the category FK is the only
      // reference that can reject this row.
      await expectLater(
        () => database
            .into(database.ledgerAccounts)
            .insert(
              LedgerAccountsCompanion.insert(
                ledgerAccountId: 'expense:missing-category',
                kind: 'system_expense',
                categoryId: const Value('missing-category'),
                isSystem: const Value(true),
                normalBalance: 'debit',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a category referencing a missing parent category', () async {
      await expectLater(
        () => database
            .into(database.categories)
            .insert(
              CategoriesCompanion.insert(
                categoryId: 'custom_orphan-parent',
                name: 'Orphan',
                iconCodePoint: 0xe000,
                kind: 'both',
                origin: 'custom',
                parentCategoryId: const Value('missing-category'),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a transaction referencing a missing category', () async {
      await expectLater(
        () => database
            .into(database.financialTransactions)
            .insert(transactionWith(categoryId: const Value('missing'))),
        throwsA(isA<Exception>()),
      );
      expect(
        await database.select(database.financialTransactions).get(),
        isEmpty,
      );
    });

    test(
      'rejects a transaction referencing a missing related transaction',
      () async {
        // Category is a valid seeded row, so the related-transaction
        // FK is the only reference that can reject this row.
        await expectLater(
          () => database
              .into(database.financialTransactions)
              .insert(
                transactionWith(
                  categoryId: const Value('food'),
                  relatedId: const Value('missing-txn'),
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('rejects a transfer referencing a missing source account', () async {
      // Destination is a valid inserted account; category is absent,
      // so the source-account FK is the only reference that can
      // reject this row.
      await insertAccount('acct-dest-valid');
      await expectLater(
        () => database
            .into(database.financialTransactions)
            .insert(
              transactionWith(
                kind: 'transfer',
                sourceId: const Value('missing-account'),
                destinationId: const Value('acct-dest-valid'),
                uuid: 'v2-txn-missing-source',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'rejects a transfer referencing a missing destination account',
      () async {
        // Source is a valid inserted account; category is absent,
        // so the destination-account FK is the only reference that
        // can reject this row.
        await insertAccount('acct-source-valid');
        await expectLater(
          () => database
              .into(database.financialTransactions)
              .insert(
                transactionWith(
                  kind: 'transfer',
                  sourceId: const Value('acct-source-valid'),
                  destinationId: const Value('missing-account'),
                  uuid: 'v2-txn-missing-destination',
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('rejects a refund referencing a missing refund account', () async {
      // Original transaction and category are both valid, so the
      // refund-account FK is the only reference that can reject
      // this row.
      await database
          .into(database.financialTransactions)
          .insert(
            transactionWith(
              categoryId: const Value('food'),
              uuid: 'v2-txn-refund-original',
            ),
          );
      await expectLater(
        () => database
            .into(database.financialTransactions)
            .insert(
              transactionWith(
                kind: 'refund',
                categoryId: const Value('food'),
                reversesId: const Value('v2-txn-refund-original'),
                refundId: const Value('missing-account'),
                uuid: 'v2-txn-missing-refund-account',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a self-reference to a missing transaction', () async {
      await expectLater(
        () => database
            .into(database.financialTransactions)
            .insert(transactionWith(reversesId: const Value('missing-txn'))),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a settings row referencing a missing account', () async {
      await expectLater(
        () => database
            .into(database.appSettings)
            .insert(
              AppSettingsCompanion.insert(
                id: const Value(2),
                defaultAccountId: const Value('missing-account'),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a posting referencing a missing transaction', () async {
      // Ledger account is the valid seeded opening_equity row, so the
      // transaction FK is the only reference that can reject this row.
      await expectLater(
        () => database
            .into(database.postings)
            .insert(
              PostingsCompanion.insert(
                uuid: 'v2-posting-missing-txn',
                transactionId: 99999,
                ledgerAccountId: 'opening_equity',
                direction: 'debit',
                amountMinorUnits: 100,
                postingDate: DateTime(2026, 1, 15),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects a posting referencing a missing ledger account', () async {
      // Transaction is a valid inserted row, so the ledger-account FK
      // is the only reference that can reject this row.
      final transactionId = await database
          .into(database.financialTransactions)
          .insert(transactionWith(categoryId: const Value('food')));
      await expectLater(
        () => database
            .into(database.postings)
            .insert(
              PostingsCompanion.insert(
                uuid: 'v2-posting-missing-ledger',
                transactionId: transactionId,
                ledgerAccountId: 'missing-ledger',
                direction: 'debit',
                amountMinorUnits: 100,
                postingDate: DateTime(2026, 1, 15),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects history referencing a missing transaction', () async {
      await expectLater(
        () => database
            .into(database.transactionHistory)
            .insert(
              TransactionHistoryCompanion.insert(
                uuid: 'v2-history-missing-txn',
                transactionId: 99999,
                changedAt: DateTime(2026, 1, 15),
                changeKind: 'created',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('accepts a valid account, ledger, transaction, and posting', () async {
      final accountId = await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              uuid: 'acct-valid',
              name: 'Bank',
              kind: 'bank',
            ),
          );
      await database
          .into(database.ledgerAccounts)
          .insert(
            LedgerAccountsCompanion.insert(
              ledgerAccountId: 'acct-valid',
              kind: 'user_asset',
              userAccountId: const Value('acct-valid'),
              normalBalance: 'debit',
            ),
          );
      final transactionId = await database
          .into(database.financialTransactions)
          .insert(transactionWith(categoryId: const Value('food')));
      await database
          .into(database.postings)
          .insert(
            PostingsCompanion.insert(
              uuid: 'v2-posting-valid',
              transactionId: transactionId,
              ledgerAccountId: 'acct-valid',
              direction: 'credit',
              amountMinorUnits: 50000,
              postingDate: DateTime(2026, 1, 15),
            ),
          );
      expect(accountId, greaterThan(0));
      expect(transactionId, greaterThan(0));
      expect(await database.select(database.postings).get(), hasLength(1));
    });

    test('rejects a second ledger account for the same user account', () async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              uuid: 'acct-dup',
              name: 'Bank',
              kind: 'bank',
            ),
          );
      await database
          .into(database.ledgerAccounts)
          .insert(
            LedgerAccountsCompanion.insert(
              ledgerAccountId: 'acct-dup',
              kind: 'user_asset',
              userAccountId: const Value('acct-dup'),
              normalBalance: 'debit',
            ),
          );
      await expectLater(
        () => database
            .into(database.ledgerAccounts)
            .insert(
              LedgerAccountsCompanion.insert(
                ledgerAccountId: 'acct-dup-second',
                kind: 'user_asset',
                userAccountId: const Value('acct-dup'),
                normalBalance: 'debit',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'rejects a duplicate category ledger for one category and kind',
      () async {
        await expectLater(
          () => database
              .into(database.ledgerAccounts)
              .insert(
                LedgerAccountsCompanion.insert(
                  ledgerAccountId: 'expense:food-duplicate',
                  kind: 'system_expense',
                  categoryId: const Value('food'),
                  isSystem: const Value(true),
                  normalBalance: 'debit',
                ),
              ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('rejects zero posting and transaction amounts', () async {
      final transactionId = await database
          .into(database.financialTransactions)
          .insert(transactionWith(categoryId: const Value('food')));
      await expectLater(
        () => database
            .into(database.postings)
            .insert(
              PostingsCompanion.insert(
                uuid: 'v2-posting-zero',
                transactionId: transactionId,
                ledgerAccountId: 'opening_equity',
                direction: 'debit',
                amountMinorUnits: 0,
                postingDate: DateTime(2026, 1, 15),
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => database
            .into(database.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                uuid: 'v2-txn-zero',
                kind: 'expense',
                amountMinorUnits: 0,
                paymentChannel: 'UPI',
                occurredAt: DateTime(2026, 1, 15),
                status: 'active',
                source: 'manual',
                createdAt: DateTime(2026, 1, 15),
                updatedAt: DateTime(2026, 1, 15),
                syncStatus: 'pending',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });

    test('rejects negative posting and transaction amounts', () async {
      final transactionId = await database
          .into(database.financialTransactions)
          .insert(transactionWith(categoryId: const Value('food')));
      await expectLater(
        () => database
            .into(database.postings)
            .insert(
              PostingsCompanion.insert(
                uuid: 'v2-posting-negative',
                transactionId: transactionId,
                ledgerAccountId: 'opening_equity',
                direction: 'debit',
                amountMinorUnits: -100,
                postingDate: DateTime(2026, 1, 15),
              ),
            ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        () => database
            .into(database.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                uuid: 'v2-txn-negative',
                kind: 'expense',
                amountMinorUnits: -100,
                paymentChannel: 'UPI',
                occurredAt: DateTime(2026, 1, 15),
                status: 'active',
                source: 'manual',
                createdAt: DateTime(2026, 1, 15),
                updatedAt: DateTime(2026, 1, 15),
                syncStatus: 'pending',
              ),
            ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
