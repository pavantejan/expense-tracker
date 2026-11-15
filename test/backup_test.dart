import 'dart:convert';

import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/backup/backup_codec.dart';
import 'package:expense_tracker/core/backup/csv_export.dart';
import 'package:expense_tracker/core/backup/file_gateway.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
import 'package:expense_tracker/data/repositories/quick_entry_service.dart';
import 'package:expense_tracker/features/settings/backup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

Money inr(int minor) => Money(minor, 'INR');

/// Builds a varied data set: accounts with opening balances, an expense
/// with merchant and tags, a transfer, a refund and a template.
Future<void> _populate(AppServices s) async {
  final bank = await s.accounts.createAccount(
    name: 'HDFC, Savings',
    kind: 'bank',
    openingBalance: inr(1000000),
  );
  final cash = await s.accounts.createAccount(name: 'Cash', kind: 'cash');
  final expense = await s.entries.create(
    EntryDraft(
      kind: EntryKind.expense,
      amount: inr(25050),
      occurredAt: DateTime.now().subtract(const Duration(hours: 2)),
      paymentChannel: 'UPI',
      accountUuid: bank.uuid,
      categoryId: 'food',
      description: '=HYPERLINK("x") "quoted"',
      merchantName: 'Swiggy',
      tagNames: ['goa', 'work'],
    ),
  );
  await s.entries.create(
    EntryDraft(
      kind: EntryKind.transfer,
      amount: inr(100000),
      occurredAt: DateTime.now().subtract(const Duration(hours: 1)),
      paymentChannel: 'Cash',
      fromAccountUuid: bank.uuid,
      toAccountUuid: cash.uuid,
    ),
  );
  await s.transactions.createRefund(
    originalUuid: expense.uuid,
    refundAccountUuid: cash.uuid,
    amount: inr(5000),
    occurredAt: DateTime.now(),
    paymentChannel: 'Cash',
  );
  await s.templates.createTemplate(name: 'Coffee', kind: 'expense');
}

Future<Map<String, List<Map<String, Object?>>>> _dump(AppServices s) async {
  final result = <String, List<Map<String, Object?>>>{};
  for (final table in s.database.allTables) {
    if (table.actualTableName == 'notifications') {
      continue;
    }
    final rows = await s.database
        .customSelect('SELECT * FROM ${table.actualTableName} ORDER BY rowid')
        .get();
    result[table.actualTableName] = rows.map((r) => r.data).toList();
  }
  return result;
}

Future<ReportingPeriod> _report(AppServices s) async {
  final now = DateTime.now();
  return computeReporting(
    await s.transactions.loadReportingSnapshot(
      periodStart: DateTime(now.year, now.month),
      periodEndExclusive: DateTime(now.year, now.month + 1),
    ),
  );
}

void main() {
  group('BackupCodec', () {
    late AppServices source;
    late AppServices target;

    setUp(() async {
      source = await createTestServices();
      target = await createTestServices();
    });

    tearDown(() async {
      await source.close();
      await target.close();
    });

    test('round trip restores every table exactly', () async {
      await _populate(source);
      final json = await source.backup.export();
      expect(json, contains('"format": "expense-tracker-backup"'));
      expect(json, isNot(contains('notifications')));

      // Target has unrelated data that must be replaced.
      await target.accounts.createAccount(name: 'Old', kind: 'wallet');
      final summary = await target.backup.restore(json);
      expect(summary.accounts, 2);
      expect(summary.transactions, 4);

      final before = await _dump(source);
      final after = await _dump(target);
      for (final table in before.keys) {
        if (table == 'financial_transactions') {
          continue;
        }
        expect(after[table], before[table], reason: table);
      }
      final txBefore = before['financial_transactions']!;
      final txAfter = after['financial_transactions']!;
      expect(txAfter, hasLength(txBefore.length));
      for (var i = 0; i < txBefore.length; i++) {
        final expected = Map.of(txBefore[i])..['sync_status'] = 'pending';
        expect(txAfter[i], expected);
      }

      final a = await _report(source);
      final b = await _report(target);
      expect(b.currentBalances, a.currentBalances);
      expect(b.expenseTotal, a.expenseTotal);
    });

    test('restored data stays fully usable', () async {
      await _populate(source);
      await target.backup.restore(await source.backup.export());
      final bank = (await target.accounts.listAccounts()).first;
      await target.entries.create(
        EntryDraft(
          kind: EntryKind.expense,
          amount: inr(100),
          occurredAt: DateTime.now(),
          paymentChannel: 'UPI',
          accountUuid: bank.uuid,
          categoryId: 'food',
          merchantName: 'swiggy',
        ),
      );
      expect(await target.merchantsTags.listMerchants(), hasLength(1));
    });

    test('rejects files that are not valid backups', () async {
      Matcher fails(String message) => throwsA(
        isA<BackupFormatException>().having(
          (e) => e.message,
          'message',
          contains(message),
        ),
      );
      expect(() => target.backup.inspect('not json'), fails('not a backup'));
      expect(
        () => target.backup.inspect('{"format":"other"}'),
        fails('not a backup'),
      );
      final valid =
          jsonDecode(await source.backup.export()) as Map<String, Object?>;

      final newer = Map.of(valid)..['schemaVersion'] = 999;
      expect(
        () => target.backup.inspect(jsonEncode(newer)),
        fails('newer version'),
      );

      final tables = Map.of(valid['tables']! as Map<String, Object?>);
      tables['sqlite_master'] = {'columns': [], 'rows': []};
      expect(
        () => target.backup.inspect(jsonEncode({...valid, 'tables': tables})),
        fails('Unknown table'),
      );

      final injected = Map.of(valid['tables']! as Map<String, Object?>);
      injected['accounts'] = {
        'columns': ['uuid"); DROP TABLE accounts; --'],
        'rows': [],
      };
      expect(
        () => target.backup.inspect(jsonEncode({...valid, 'tables': injected})),
        fails('Unknown column'),
      );
    });

    test('a tampered backup is rejected and nothing changes', () async {
      await _populate(source);
      await target.accounts.createAccount(name: 'Keep me', kind: 'cash');
      final valid =
          jsonDecode(await source.backup.export()) as Map<String, Object?>;
      final tables = valid['tables']! as Map<String, Object?>;
      final postings = tables['postings']! as Map<String, Object?>;
      final columns = (postings['columns']! as List).cast<String>();
      final rows = (postings['rows']! as List).cast<List<Object?>>();
      rows.first[columns.indexOf('amount_minor_units')] = 1;

      await expectLater(
        target.backup.restore(jsonEncode(valid)),
        throwsA(isA<BackupFormatException>()),
      );
      final accounts = await target.accounts.listAccounts();
      expect(accounts.single.name, 'Keep me');
    });

    test('a schema-8 backup restores into the current schema', () async {
      await _populate(source);
      final valid =
          jsonDecode(await source.backup.export()) as Map<String, Object?>;
      final tables = Map.of(valid['tables']! as Map<String, Object?>)
        ..remove('merchants')
        ..remove('tags')
        ..remove('transaction_tags')
        ..remove('transaction_templates');
      final txTable = Map.of(tables['financial_transactions']! as Map);
      final columns = (txTable['columns'] as List).cast<String>().toList();
      final merchantIndex = columns.indexOf('merchant_id');
      columns.removeAt(merchantIndex);
      txTable['columns'] = columns;
      txTable['rows'] = [
        for (final row in (txTable['rows'] as List).cast<List<Object?>>())
          [...row]..removeAt(merchantIndex),
      ];
      tables['financial_transactions'] = txTable;

      await target.backup.restore(
        jsonEncode({...valid, 'schemaVersion': 8, 'tables': tables}),
      );
      final restored = await target.transactions.listTransactions();
      expect(restored, hasLength(4));
      expect(restored.every((t) => t.merchantId == null), isTrue);
      expect(await target.merchantsTags.listMerchants(), isEmpty);
    });
  });

  group('CSV export', () {
    test('quotes, formula guard, exact amounts and BOM', () async {
      final s = await createTestServices();
      addTearDown(s.close);
      await _populate(s);
      final csv = transactionsToCsv(await s.queries.loadTransactions());
      expect(csv.startsWith('\uFEFF'), isTrue);
      final lines = csv.substring(1).split('\r\n');
      expect(lines.first, csvHeaders.join(','));
      final expenseLine = lines.firstWhere((l) => l.contains('Swiggy'));
      expect(expenseLine, contains(',Expense,Out,250.50,INR,Food,Swiggy,'));
      expect(expenseLine, contains('"\'=HYPERLINK(""x"") ""quoted"""'));
      expect(expenseLine, contains('"HDFC, Savings"'));
      expect(expenseLine, contains('"goa, work"'));
      final transfer = lines.firstWhere((l) => l.contains(',Transfer,'));
      expect(transfer, contains(',Between accounts,1000.00,'));
    });
  });

  group('BackupPage', () {
    testWidgets('export requires acknowledging the plain-file warning', (
      tester,
    ) async {
      final files = _FakeFiles();
      final services = (await tester.runAsync(
        () => createTestServices(files: files),
      ))!;
      await tester.runAsync(
        () => services.accounts.createAccount(
          name: 'Bank',
          kind: 'bank',
          openingBalance: inr(5000),
        ),
      );
      await pumpWithServices(tester, services, const BackupPage());

      await tester.tap(find.byKey(const Key('save-csv')));
      await tester.pumpAndSettle();
      final continueButton = find.byKey(const Key('ack-continue'));
      expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
      await tester.tap(find.byKey(const Key('ack-plain-file')));
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      expect(
        files.saved.single.$1,
        startsWith('expense-tracker-transactions-'),
      );
      expect(files.saved.single.$2, contains('Opening balance'));

      await tester.pump(const Duration(seconds: 6));
      await closeServices(tester, services);
    });

    testWidgets('restore needs typed confirmation', (tester) async {
      final files = _FakeFiles();
      final services = (await tester.runAsync(() async {
        final donor = await createTestServices();
        await _populate(donor);
        files.toPick = await donor.backup.export();
        await donor.close();
        return createTestServices(files: files);
      }))!;
      await pumpWithServices(tester, services, const BackupPage());

      await tester.tap(find.byKey(const Key('restore-backup')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('2 account(s), 4 transaction(s)'),
        findsOneWidget,
      );
      final go = find.byKey(const Key('restore-go'));
      expect(tester.widget<FilledButton>(go).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('restore-confirm')),
        'RESTORE',
      );
      await tester.pumpAndSettle();
      await tester.tap(go);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();

      final accounts = (await tester.runAsync(
        () => services.accounts.listAccounts(),
      ))!;
      expect(accounts, hasLength(2));

      await tester.pump(const Duration(seconds: 6));
      await closeServices(tester, services);
    });
  });
}

class _FakeFiles implements FileGateway {
  final List<(String, String)> saved = [];
  String? toPick;

  @override
  Future<bool> saveText({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    saved.add((fileName, content));
    return true;
  }

  @override
  Future<void> shareText({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    saved.add((fileName, content));
  }

  @override
  Future<String?> pickText({required List<String> extensions}) async => toPick;
}
