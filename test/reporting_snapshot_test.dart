import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_stage2_helpers.dart';

/// Builds the approved fixture through the repositories, then proves
/// the snapshot loader's three-output semantics.
Future<(dynamic, dynamic, dynamic)> buildFixture(Stage2Fixture fx) async {
  final bank = await fx.bankWithOpening(inr(1000000));
  final cash = await fx.cash();
  final card = await fx.card();
  await fx.transactions.createExpense(
    accountUuid: bank.uuid,
    categoryId: 'food',
    amount: inr(50000),
    occurredAt: dt(2026, 1, 10),
    paymentChannel: 'Cash',
  );
  final cardPurchase = await fx.transactions.createExpense(
    accountUuid: card.uuid,
    categoryId: 'shopping',
    amount: inr(200000),
    occurredAt: dt(2026, 1, 12),
    paymentChannel: 'Card',
  );
  await fx.transactions.createTransfer(
    sourceAccountUuid: bank.uuid,
    destinationAccountUuid: cash.uuid,
    amount: inr(100000),
    occurredAt: dt(2026, 1, 15),
    paymentChannel: 'Bank Transfer',
  );
  await fx.transactions.createCardPayment(
    sourceAccountUuid: bank.uuid,
    cardAccountUuid: card.uuid,
    amount: inr(200000),
    occurredAt: dt(2026, 1, 20),
    paymentChannel: 'Bank Transfer',
  );
  final janFood = (await fx.transactions.listTransactions()).firstWhere(
    (t) => t.categoryId == 'food' && t.kind == 'expense',
  );
  await fx.transactions.createRefund(
    originalUuid: janFood.uuid,
    refundAccountUuid: bank.uuid,
    amount: inr(20000),
    occurredAt: dt(2026, 2, 5),
    paymentChannel: 'Cash',
  );
  await fx.transactions.createReversal(
    originalUuid: cardPurchase.uuid,
    occurredAt: dt(2026, 2, 10),
  );
  await fx.transactions.createAdjustment(
    accountUuid: bank.uuid,
    adjustmentReason: 'fee_correction',
    direction: AdjustmentDirection.decrease,
    amount: inr(10000),
    occurredAt: dt(2026, 2, 15),
    paymentChannel: 'Bank Transfer',
    categoryId: 'food',
    reportingKind: ReportingKind.expense,
  );
  await fx.transactions.createAdjustment(
    accountUuid: bank.uuid,
    adjustmentReason: 'balance_correction',
    direction: AdjustmentDirection.increase,
    amount: inr(5000),
    occurredAt: dt(2026, 2, 18),
    paymentChannel: 'Bank Transfer',
  );
  return (bank, cash, card);
}

Future<ReportingPeriod> febPeriod(Stage2Fixture fx) async {
  final snapshot = await fx.transactions.loadReportingSnapshot(
    periodStart: DateTime.utc(2026, 2, 1),
    periodEndExclusive: DateTime.utc(2026, 3, 1),
  );
  return computeReporting(snapshot);
}

void main() {
  late Stage2Fixture fx;

  setUp(() async {
    fx = await Stage2Fixture.create();
  });

  tearDown(() async {
    await fx.close();
  });

  test(
    'February closing includes January; movements are February-only',
    () async {
      final (bank, cash, card) = await buildFixture(fx);
      final period = await febPeriod(fx);
      expect(period.expenseTotal.amountMinorUnits, -210000);
      expect(period.incomeTotal.amountMinorUnits, 0);
      expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 665000);
      expect(period.closingBalances[cash.uuid]!.amountMinorUnits, 100000);
      expect(period.closingBalances[card.uuid]!.amountMinorUnits, -200000);
      expect(period.currentBalances, period.closingBalances);
    },
  );

  test(
    'February closing excludes March; current balances include it',
    () async {
      final (bank, _, _) = await buildFixture(fx);
      await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(30000),
        occurredAt: dt(2026, 3, 5),
        paymentChannel: 'Cash',
      );
      final period = await febPeriod(fx);
      expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 665000);
      expect(period.currentBalances[bank.uuid]!.amountMinorUnits, 635000);
      expect(period.expenseTotal.amountMinorUnits, -210000);
    },
  );

  test(
    'a transaction at exactly the period end belongs to the next period',
    () async {
      final bank = await fx.bank();
      await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(30000),
        occurredAt: DateTime.utc(2026, 3, 1),
        paymentChannel: 'Cash',
      );
      final feb = await febPeriod(fx);
      expect(feb.expenseTotal.amountMinorUnits, 0);
      expect(feb.closingBalances[bank.uuid]!.amountMinorUnits, 0);
      final marSnapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 3, 1),
        periodEndExclusive: DateTime.utc(2026, 4, 1),
      );
      final mar = computeReporting(marSnapshot);
      expect(mar.expenseTotal.amountMinorUnits, 30000);
      expect(mar.closingBalances[bank.uuid]!.amountMinorUnits, -30000);
    },
  );

  test(
    'deleting and restoring the February reversal updates all three outputs',
    () async {
      final (bank, _, card) = await buildFixture(fx);
      final reversal = (await fx.transactions.listTransactions()).firstWhere(
        (t) => t.kind == 'reversal',
      );
      await fx.transactions.deleteTransaction(reversal.uuid);
      final deleted = await febPeriod(fx);
      expect(deleted.expenseTotal.amountMinorUnits, -10000);
      expect(deleted.closingBalances[card.uuid]!.amountMinorUnits, 0);
      expect(deleted.closingBalances[bank.uuid]!.amountMinorUnits, 665000);
      await fx.transactions.restoreTransaction(reversal.uuid);
      final restored = await febPeriod(fx);
      expect(restored.expenseTotal.amountMinorUnits, -210000);
      expect(restored.closingBalances[card.uuid]!.amountMinorUnits, -200000);
    },
  );

  test('deleting a January expense (after its refund) leaves February movements consistent', () async {
    final (bank, _, _) = await buildFixture(fx);
    final refund = (await fx.transactions.listTransactions()).firstWhere(
      (t) => t.kind == 'refund',
    );
    await fx.transactions.deleteTransaction(refund.uuid);
    final janExpense = (await fx.transactions.listTransactions()).firstWhere(
      (t) =>
          t.kind == 'expense' &&
          t.categoryId == 'food' &&
          t.occurredAt.month == 1,
    );
    await fx.transactions.deleteTransaction(janExpense.uuid);
    final period = await febPeriod(fx);
    // February movements now hold only the reversal and the
    // categorised adjustment; the January expense is gone from
    // closing balances.
    expect(period.expenseTotal.amountMinorUnits, -190000);
    expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 695000);
  });

  test(
    'opening balances appear in closing and current, never in movements',
    () async {
      final bank = await fx.bankWithOpening(inr(1000000));
      final snapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEndExclusive: DateTime.utc(2026, 2, 1),
      );
      final period = computeReporting(snapshot);
      expect(period.incomeTotal.amountMinorUnits, 0);
      expect(period.expenseTotal.amountMinorUnits, 0);
      expect(period.openingBalanceTotal.amountMinorUnits, 1000000);
      expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 1000000);
      expect(period.currentBalances[bank.uuid]!.amountMinorUnits, 1000000);
    },
  );

  test(
    'archived ledgers keep their history in closing and current balances',
    () async {
      final (bank, _, _) = await buildFixture(fx);
      await fx.categories.archiveCategory('food');
      final period = await febPeriod(fx);
      expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 665000);
    },
  );

  test('movements are a subset of closing postings; contexts never double-count', () async {
    await buildFixture(fx);
    final snapshot = await fx.transactions.loadReportingSnapshot(
      periodStart: DateTime.utc(2026, 2, 1),
      periodEndExclusive: DateTime.utc(2026, 3, 1),
    );
    final movementKeys = {
      for (final event in snapshot.movements)
        for (final posting in event.postings)
          '${posting.transactionUuid}|${posting.ledgerAccountId}|${posting.amountMinorUnits}',
    };
    final closingKeys = {
      for (final posting in snapshot.closingPostings)
        '${posting.transactionUuid}|${posting.ledgerAccountId}|${posting.amountMinorUnits}',
    };
    expect(movementKeys.difference(closingKeys), isEmpty);
    // The reversal context for the January purchase is present, but
    // its postings are not in the closing set a second time.
    expect(snapshot.reversalContexts.length, 1);
    final period = computeReporting(snapshot);
    expect(
      period.closingBalances.values.fold<int>(
        0,
        (sum, money) => sum + money.amountMinorUnits,
      ),
      565000,
    );
  });

  test('invalid period interval is rejected by the loader', () async {
    await expectLater(
      fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 3, 1),
        periodEndExclusive: DateTime.utc(2026, 3, 1),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'March reversal of a February fee correction negates in March only',
    () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createAdjustment(
        accountUuid: bank.uuid,
        adjustmentReason: 'fee_correction',
        direction: AdjustmentDirection.decrease,
        amount: inr(7500),
        occurredAt: dt(2026, 2, 10),
        paymentChannel: 'Bank Transfer',
      );
      await fx.transactions.createReversal(
        originalUuid: original.uuid,
        occurredAt: dt(2026, 3, 5),
      );
      final feb = await febPeriod(fx);
      expect(feb.feeCorrectionEffect.amountMinorUnits, -7500);
      final marSnapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 3, 1),
        periodEndExclusive: DateTime.utc(2026, 4, 1),
      );
      final mar = computeReporting(marSnapshot);
      expect(mar.feeCorrectionEffect.amountMinorUnits, 7500);
      expect(mar.closingBalances[bank.uuid]!.amountMinorUnits, 0);
    },
  );

  test('watchReportingSnapshot re-emits after a write', () async {
    final bank = await fx.bank();
    final emissions = <ReportingSnapshot>[];
    final subscription = fx.transactions
        .watchReportingSnapshot(
          periodStart: DateTime.utc(2026, 2, 1),
          periodEndExclusive: DateTime.utc(2026, 3, 1),
        )
        .listen(emissions.add);
    // Wait for the initial emission before writing, so the second
    // emission is provably caused by the write.
    for (var i = 0; i < 50 && emissions.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(emissions.length, 1);
    expect(computeReporting(emissions.single).expenseTotal.amountMinorUnits, 0);
    await fx.transactions.createExpense(
      accountUuid: bank.uuid,
      categoryId: 'food',
      amount: inr(50000),
      occurredAt: dt(2026, 2, 10),
      paymentChannel: 'Cash',
    );
    for (var i = 0; i < 50 && emissions.length < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await subscription.cancel();
    expect(emissions.length, 2);
    expect(
      computeReporting(emissions.last).expenseTotal.amountMinorUnits,
      50000,
    );
  });
}
