import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/features/transactions/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

/// Home with a button that pushes [page], so the page's own pop on
/// save returns here like it does in the app.
class _Launcher extends StatelessWidget {
  const _Launcher(this.page);

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  late AppServices services;

  Future<void> open(WidgetTester tester, Widget page) async {
    await pumpWithServices(tester, services, _Launcher(page));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('save-transaction')));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for an account first when none exists', (tester) async {
    services = (await tester.runAsync(createTestServices))!;
    await open(tester, const AddTransactionPage());

    expect(find.text('Add an account first'), findsOneWidget);
    expect(find.byKey(const Key('save-transaction')), findsNothing);
    await closeServices(tester, services);
  });

  testWidgets('saves an expense in paise against the chosen account', (
    tester,
  ) async {
    services = (await tester.runAsync(createTestServices))!;
    final bank = (await tester.runAsync(
      () => services.accounts.createAccount(name: 'HDFC', kind: 'bank'),
    ))!;
    await open(tester, const AddTransactionPage());

    await tester.enterText(find.byKey(const Key('amount-field')), '250.50');
    await save(tester);

    expect(find.text('open'), findsOneWidget, reason: 'page closed on save');
    final rows = (await tester.runAsync(
      () => services.transactions.listTransactions(),
    ))!;
    expect(rows, hasLength(1));
    expect(rows.single.kind, 'expense');
    expect(rows.single.amountMinorUnits, 25050);
    expect(rows.single.categoryId, 'food');
    final posted = (await tester.runAsync(
      () => services.queries.loadTransactions(accountUuid: bank.uuid),
    ))!;
    expect(posted.single.account?.name, 'HDFC');

    await tester.pump(const Duration(seconds: 6));
    await closeServices(tester, services);
  });

  testWidgets('more than two decimals is rejected, nothing saved', (
    tester,
  ) async {
    services = (await tester.runAsync(createTestServices))!;
    await tester.runAsync(
      () => services.accounts.createAccount(name: 'Cash', kind: 'cash'),
    );
    await open(tester, const AddTransactionPage());

    await tester.enterText(find.byKey(const Key('amount-field')), '10.555');
    await save(tester);

    expect(find.text('Amounts support up to 2 decimal places'), findsOneWidget);
    final rows = (await tester.runAsync(
      () => services.transactions.listTransactions(),
    ))!;
    expect(rows, isEmpty);
    await closeServices(tester, services);
  });

  testWidgets('a transfer to a credit card is saved as a card payment', (
    tester,
  ) async {
    services = (await tester.runAsync(createTestServices))!;
    await tester.runAsync(() async {
      await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: Money(1000000, 'INR'),
      );
      await services.accounts.createAccount(
        name: 'Visa',
        kind: 'credit_card_liability',
      );
    });
    await open(
      tester,
      const AddTransactionPage(initialType: EntryType.transfer),
    );

    expect(find.textContaining('Paying a credit card'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount-field')), '500');
    await save(tester);

    final rows = (await tester.runAsync(
      () => services.transactions.listTransactions(),
    ))!;
    final payment = rows.singleWhere((r) => r.kind != 'opening_balance');
    expect(payment.kind, 'card_payment');
    expect(payment.amountMinorUnits, 50000);

    await tester.pump(const Duration(seconds: 6));
    await closeServices(tester, services);
  });

  testWidgets('editing an expense updates it in place', (tester) async {
    services = (await tester.runAsync(createTestServices))!;
    final expense = (await tester.runAsync(() async {
      final bank = await services.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
      );
      return services.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'travel',
        amount: Money(12000, 'INR'),
        occurredAt: DateTime.now().subtract(const Duration(days: 1)),
        paymentChannel: 'UPI',
        description: 'Cab',
      );
    }))!;
    await open(tester, AddTransactionPage(transactionUuid: expense.uuid));

    expect(find.text('Cab'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('amount-field')), '130');
    await save(tester);

    final updated = (await tester.runAsync(
      () => services.transactions.getTransactionByUuid(expense.uuid),
    ))!;
    expect(updated.amountMinorUnits, 13000);
    expect(updated.categoryId, 'travel');
    expect(updated.syncStatus, 'pending');

    await tester.pump(const Duration(seconds: 6));
    await closeServices(tester, services);
  });
}
