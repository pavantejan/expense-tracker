// Fresh-database validation (blueprint section 7.3), automated part.
// Device checks (old file size unchanged, Drive shows the new V2
// spreadsheet) are in the PR device checklist.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/database/database_factory.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';
import 'v2_stage2_helpers.dart' show inr;

Future<ReportingPeriod> _currentReport(AppServices services) async {
  final now = DateTime.now();
  return computeReporting(
    await services.transactions.loadReportingSnapshot(
      periodStart: DateTime(now.year, now.month),
      periodEndExclusive: DateTime(now.year, now.month + 1),
    ),
  );
}

void main() {
  test(
    'smoke: opening balance + expense give derived, balanced results',
    () async {
      final services = await createTestServices();
      addTearDown(services.close);

      final bank = await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: inr(1000000),
      );
      final expense = await services.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(25050),
        occurredAt: DateTime.now(),
        paymentChannel: 'UPI',
      );

      final report = await _currentReport(services);
      expect(report.currentBalances[bank.uuid], inr(974950));
      expect(report.expenseTotal, inr(25050));

      for (final tx in await services.transactions.listTransactions()) {
        final postings = await services.transactions.getPostingsForTransaction(
          tx.uuid,
        );
        final debits = postings
            .where((p) => p.direction == 'debit')
            .fold<int>(0, (sum, p) => sum + p.amountMinorUnits);
        final credits = postings
            .where((p) => p.direction == 'credit')
            .fold<int>(0, (sum, p) => sum + p.amountMinorUnits);
        expect(debits, credits, reason: 'postings of ${tx.kind} balance');
        expect(postings, hasLength(2));
      }
      final history = await services.database
          .select(services.database.transactionHistory)
          .get();
      expect(history, hasLength(2));
      expect(history.map((h) => h.changeKind), everyElement('created'));
      expect(expense.syncStatus, 'pending');
    },
  );

  test(
    'restart: a reopened database keeps data, no reset, no duplicates',
    () async {
      final dir = await Directory.systemTemp.createTemp('et_v2_restart');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/expense_tracker_v2.db');

      Future<AppServices> open() async => AppServices(
        database: await const AppDatabaseV2Factory().create(
          executor: NativeDatabase(file),
        ),
        syncBackend: SignedOutBackend(),
      );

      final first = await open();
      final bank = await first.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: inr(50000),
      );
      await first.close();

      final second = await open();
      addTearDown(second.close);
      final accounts = await second.accounts.listAccounts();
      expect(accounts.single.uuid, bank.uuid);
      final transactions = await second.transactions.listTransactions();
      expect(
        transactions.where((t) => t.kind == 'opening_balance'),
        hasLength(1),
      );
      expect(
        (await _currentReport(second)).currentBalances[bank.uuid],
        inr(50000),
      );
      expect(await second.categories.listCategories(), hasLength(8));
    },
  );

  test('cleanup gating: lib/ never deletes or opens another database', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
    final openers = <String>[];
    for (final file in sources) {
      final text = file.readAsStringSync();
      final normalized = file.path.replaceAll(r'\', '/');
      if (normalized.endsWith('lib/core/backup/file_gateway.dart')) {
        // The only file deletion in the app: the temporary copy used
        // for sharing, inside the app's temporary directory.
        expect(text, contains('getTemporaryDirectory()'));
        expect(text, isNot(contains('getApplicationDocumentsDirectory')));
        continue;
      }
      expect(
        RegExp(r'\.delete(Sync)?\(').hasMatch(text) && text.contains('dart:io'),
        isFalse,
        reason: '${file.path} must not delete files',
      );
      expect(
        text.contains("'expense_tracker'") ||
            text.contains('"expense_tracker"'),
        isFalse,
        reason: '${file.path} must not reference the old database name',
      );
      if (text.contains('driftDatabase(')) {
        openers.add(file.path);
      }
    }
    expect(openers, hasLength(1), reason: 'only the V2 database opener');
    expect(openers.single, contains('app_database_v2.dart'));
  });
}
