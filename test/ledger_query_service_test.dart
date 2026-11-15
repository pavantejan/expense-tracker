import 'package:expense_tracker/data/repositories/ledger_query_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_stage2_helpers.dart';

void main() {
  late Stage2Fixture f;
  late LedgerQueryService queries;

  setUp(() async {
    f = await Stage2Fixture.create();
    queries = LedgerQueryService(f.db, f.transactions);
  });

  tearDown(() => f.close());

  test('flows and accounts are resolved per kind', () async {
    final bank = await f.bank();
    final cash = await f.cash();
    final card = await f.card();
    final expense = await f.transactions.createExpense(
      accountUuid: bank.uuid,
      categoryId: 'food',
      amount: inr(5000),
      occurredAt: dt(2026, 3, 1),
      paymentChannel: 'UPI',
    );
    final income = await f.transactions.createIncome(
      accountUuid: bank.uuid,
      categoryId: 'other',
      amount: inr(90000),
      occurredAt: dt(2026, 3, 2),
      paymentChannel: 'Bank Transfer',
    );
    final cardPurchase = await f.transactions.createExpense(
      accountUuid: card.uuid,
      categoryId: 'shopping',
      amount: inr(3000),
      occurredAt: dt(2026, 3, 3),
      paymentChannel: 'Card',
    );
    final transfer = await f.transactions.createTransfer(
      sourceAccountUuid: bank.uuid,
      destinationAccountUuid: cash.uuid,
      amount: inr(1000),
      occurredAt: dt(2026, 3, 4),
      paymentChannel: 'Cash',
    );

    final views = {for (final v in await queries.loadTransactions()) v.uuid: v};
    expect(views[expense.uuid]!.flow, DisplayFlow.outflow);
    expect(views[expense.uuid]!.account?.uuid, bank.uuid);
    expect(views[expense.uuid]!.category?.name, 'Food');
    expect(views[income.uuid]!.flow, DisplayFlow.inflow);
    // A card purchase raises what is owed: money out.
    expect(views[cardPurchase.uuid]!.flow, DisplayFlow.outflow);
    expect(views[cardPurchase.uuid]!.account?.uuid, card.uuid);
    expect(views[transfer.uuid]!.flow, DisplayFlow.neutral);
    expect(views[transfer.uuid]!.sourceAccount?.uuid, bank.uuid);
    expect(views[transfer.uuid]!.destinationAccount?.uuid, cash.uuid);

    // Newest first.
    final ordered = await queries.loadTransactions();
    expect(ordered.first.uuid, transfer.uuid);
  });

  test('filters by period, account and deletion; marks reversals', () async {
    final bank = await f.bank();
    final cash = await f.cash();
    final march = await f.transactions.createExpense(
      accountUuid: bank.uuid,
      categoryId: 'food',
      amount: inr(5000),
      occurredAt: dt(2026, 3, 1),
      paymentChannel: 'UPI',
    );
    final february = await f.transactions.createExpense(
      accountUuid: cash.uuid,
      categoryId: 'food',
      amount: inr(700),
      occurredAt: dt(2026, 2, 10),
      paymentChannel: 'Cash',
    );
    await f.transactions.createReversal(
      originalUuid: march.uuid,
      occurredAt: dt(2026, 3, 2),
    );
    await f.transactions.deleteTransaction(february.uuid);

    final inMarch = await queries.loadTransactions(
      from: DateTime.utc(2026, 3),
      toExclusive: DateTime.utc(2026, 4),
    );
    expect(inMarch.map((v) => v.kind), ['reversal', 'expense']);
    expect(inMarch.last.isReversed, isTrue);

    expect(await queries.loadTransactions(accountUuid: cash.uuid), isEmpty);
    final withDeleted = await queries.loadTransactions(
      accountUuid: cash.uuid,
      includeDeleted: true,
    );
    expect(withDeleted.single.isDeleted, isTrue);
  });

  test('search text covers description, category and account', () async {
    final bank = await f.bank(name: 'HDFC Savings');
    final expense = await f.transactions.createExpense(
      accountUuid: bank.uuid,
      categoryId: 'health',
      amount: inr(5000),
      occurredAt: dt(2026, 3, 1),
      paymentChannel: 'UPI',
      description: 'Pharmacy',
    );
    final view = (await queries.loadTransactions()).singleWhere(
      (v) => v.uuid == expense.uuid,
    );
    expect(view.searchText, contains('pharmacy'));
    expect(view.searchText, contains('health'));
    expect(view.searchText, contains('hdfc savings'));
  });

  test('year-by-month reporting has twelve months plus the year', () async {
    final bank = await f.bank();
    await f.transactions.createExpense(
      accountUuid: bank.uuid,
      categoryId: 'food',
      amount: inr(5000),
      occurredAt: dt(2026, 2, 1),
      paymentChannel: 'UPI',
    );
    final reports = await queries.watchYearByMonth(2026).first;
    expect(reports, hasLength(13));
    expect(reports[1].expenseTotal, inr(5000));
    expect(reports[0].expenseTotal, inr(0));
    expect(reports.last.expenseTotal, inr(5000));
  });
}
