import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
import 'package:expense_tracker/features/accounts/account_form_page.dart';
import 'package:expense_tracker/features/accounts/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';
import 'v2_stage2_helpers.dart' show inr;

Future<ReportingPeriod> _report(AppServices services) async {
  final now = DateTime.now();
  return computeReporting(
    await services.transactions.loadReportingSnapshot(
      periodStart: DateTime(now.year, now.month),
      periodEndExclusive: DateTime(now.year, now.month + 1),
    ),
  );
}

Future<Money> _balance(AppServices services, String accountUuid) async {
  return (await _report(services)).currentBalances[accountUuid]!;
}

void main() {
  group('correctAccountBalance', () {
    late AppServices services;

    setUp(() async {
      services = await createTestServices();
    });

    tearDown(() => services.close());

    test('no activity: records an opening balance', () async {
      final account = await services.accounts.createAccount(
        name: 'Cash',
        kind: 'cash',
      );
      await correctAccountBalance(
        services,
        account,
        Money.zero('INR'),
        inr(150000),
      );
      final views = await services.queries.loadTransactions();
      expect(views.single.kind, 'opening_balance');
      expect(await _balance(services, account.uuid), inr(150000));
    });

    test('only an opening balance: edits it instead of stacking', () async {
      final account = await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: inr(100000),
      );
      await correctAccountBalance(services, account, inr(100000), inr(80000));
      final views = await services.queries.loadTransactions();
      expect(views.single.kind, 'opening_balance');
      expect(await _balance(services, account.uuid), inr(80000));
    });

    test('with activity: adds a balance-correction adjustment', () async {
      final account = await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: inr(100000),
      );
      await services.transactions.createExpense(
        accountUuid: account.uuid,
        categoryId: 'food',
        amount: inr(20000),
        occurredAt: DateTime.now(),
        paymentChannel: 'UPI',
      );
      await correctAccountBalance(services, account, inr(80000), inr(75000));
      final views = await services.queries.loadTransactions();
      final adjustment = views.firstWhere((v) => v.kind == 'adjustment');
      expect(adjustment.transaction.adjustmentReason, 'balance_correction');
      expect(adjustment.transaction.amountMinorUnits, 5000);
      expect(await _balance(services, account.uuid), inr(75000));

      // Income/expense totals are untouched by the correction.
      final report = await _report(services);
      expect(report.expenseTotal, inr(20000));
      expect(report.incomeTotal, Money.zero('INR'));
    });

    test('no change does nothing', () async {
      final account = await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
      );
      await correctAccountBalance(services, account, inr(0), inr(0));
      expect(await services.queries.loadTransactions(), isEmpty);
    });
  });

  testWidgets('adding an account with an opening balance shows it', (
    tester,
  ) async {
    final services = (await tester.runAsync(createTestServices))!;
    await pumpWithServices(tester, services, const AccountsPage());

    expect(find.text('Add your first account'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-account')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountFormPage), findsOneWidget);

    await tester.enterText(find.byKey(const Key('account-name')), 'SBI');
    await tester.enterText(
      find.byKey(const Key('opening-balance')),
      '12500.75',
    );
    await tester.tap(find.byKey(const Key('save-account')));
    await tester.pumpAndSettle();

    expect(find.text('SBI'), findsOneWidget);
    expect(find.text('₹12,500.75'), findsWidgets);

    await closeServices(tester, services);
  });

  testWidgets('credit card dues are shown separately from assets', (
    tester,
  ) async {
    final services = (await tester.runAsync(createTestServices))!;
    await tester.runAsync(() async {
      await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: inr(500000),
      );
      await services.accounts.createAccount(
        name: 'Visa',
        kind: 'credit_card_liability',
        openingBalance: inr(20000),
      );
    });
    await pumpWithServices(tester, services, const AccountsPage());

    expect(find.text('Available balance'), findsOneWidget);
    expect(find.text('₹5,000.00'), findsWidgets);
    expect(find.text('Credit card dues'), findsOneWidget);
    expect(find.text('₹200.00'), findsWidgets);

    await closeServices(tester, services);
  });
}
