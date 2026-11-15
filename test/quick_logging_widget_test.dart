import 'package:expense_tracker/app/app.dart';
import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/data/repositories/quick_entry_service.dart';
import 'package:expense_tracker/features/transactions/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  testWidgets('the five tabs open their landing pages', (tester) async {
    final services = (await tester.runAsync(createTestServices))!;
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(ExpenseTrackerApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Welcome! Add your first account'), findsOneWidget);
    for (final (tab, landing) in [
      ('Track', 'Templates & favourites'),
      ('Manage', 'Accounts'),
      ('Understand', 'Monthly summary'),
      ('Automate', 'Recurring transactions'),
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.text(landing), findsWidgets, reason: tab);
    }

    // A tab keeps its own stack: open Accounts under Manage.
    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manage-accounts')));
    await tester.pumpAndSettle();
    expect(find.text('Add your first account'), findsOneWidget);

    await closeServices(tester, services);
  });

  group('fast entry on the add screen', () {
    late AppServices services;
    late String bank;

    Future<void> setUpData(WidgetTester tester) async {
      services = (await tester.runAsync(createTestServices))!;
      bank = (await tester.runAsync(
        () => services.accounts.createAccount(name: 'Bank', kind: 'bank'),
      ))!.uuid;
    }

    testWidgets('a known merchant suggests its usual category', (tester) async {
      await setUpData(tester);
      await tester.runAsync(
        () => services.entries.create(
          EntryDraft(
            kind: EntryKind.expense,
            amount: Money(9900, 'INR'),
            occurredAt: DateTime.now().subtract(const Duration(days: 1)),
            paymentChannel: 'UPI',
            accountUuid: bank,
            categoryId: 'entertainment',
            merchantName: 'Netflix',
          ),
        ),
      );
      await pumpWithServices(tester, services, const AddTransactionPage());

      // Smart default: last expense category.
      expect(find.text('Entertainment'), findsOneWidget);
      // Change the category to something else, then reset by picking
      // the merchant on a fresh form.
      await tester.enterText(find.byKey(const Key('merchant-field')), 'Netf');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Netflix').last);
      await tester.pumpAndSettle();
      expect(find.text('Entertainment'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('amount-field')), '199');
      await tester.enterText(find.byKey(const Key('tag-field')), 'subs');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'subs'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-transaction')));
      await tester.pumpAndSettle();
      final views = (await tester.runAsync(
        () => services.queries.loadTransactions(),
      ))!;
      final latest = views.firstWhere(
        (v) => v.transaction.amountMinorUnits == 19900,
      );
      expect(latest.merchant?.name, 'Netflix');
      expect(latest.tags.map((t) => t.name), ['subs']);
      expect(latest.category?.categoryId, 'entertainment');

      await tester.pump(const Duration(seconds: 6));
      await closeServices(tester, services);
    });

    testWidgets('a favourite chip fills the form in one tap', (tester) async {
      await setUpData(tester);
      await tester.runAsync(
        () => services.templates.createTemplate(
          name: 'Metro card',
          kind: 'expense',
          amountMinorUnits: 50000,
          accountId: bank,
          categoryId: 'travel',
          description: 'Metro recharge',
        ),
      );
      await pumpWithServices(tester, services, const AddTransactionPage());

      await tester.tap(find.text('Metro card'));
      await tester.pumpAndSettle();
      expect(find.text('500.00'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Metro recharge'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save-transaction')));
      await tester.pumpAndSettle();
      final rows = (await tester.runAsync(
        () => services.transactions.listTransactions(),
      ))!;
      expect(rows.single.source, 'template');
      expect(rows.single.amountMinorUnits, 50000);

      await tester.pump(const Duration(seconds: 6));
      await closeServices(tester, services);
    });

    testWidgets('save as template creates a favourite', (tester) async {
      await setUpData(tester);
      await pumpWithServices(tester, services, const AddTransactionPage());

      await tester.enterText(find.byKey(const Key('amount-field')), '45');
      await tester.enterText(find.byKey(const Key('merchant-field')), 'Chai');
      await tester.tap(find.byKey(const Key('save-as-template')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('template-name')), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final templates = (await tester.runAsync(
        () => services.templates.listTemplates(),
      ))!;
      expect(templates.single.name, 'Chai');
      expect(templates.single.amountMinorUnits, 4500);
      expect(templates.single.isFavourite, isTrue);
      expect(templates.single.merchantId, isNotNull);

      await tester.pump(const Duration(seconds: 6));
      await closeServices(tester, services);
    });
  });
}
