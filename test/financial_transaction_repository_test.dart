import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
import 'package:expense_tracker/data/repositories/financial_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_stage2_helpers.dart';

Future<int> historyCount(Stage2Fixture fx, int transactionId) async {
  final rows = await (fx.db.select(
    fx.db.transactionHistory,
  )..where((h) => h.transactionId.equals(transactionId))).get();
  return rows.length;
}

void main() {
  late Stage2Fixture fx;

  setUp(() async {
    fx = await Stage2Fixture.create();
  });

  tearDown(() async {
    await fx.close();
  });

  Future<(dynamic, dynamic)> twoAccounts() async {
    final bank = await fx.bankWithOpening(inr(1000000));
    final cash = await fx.cash();
    return (bank, cash);
  }

  group('create expense and income', () {
    test('creates balanced postings, history, revision 0, pending', () async {
      final bank = await fx.bank();
      final tx = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
        description: 'Lunch',
      );
      expect(tx.kind, 'expense');
      expect(tx.categoryId, 'food');
      expect(tx.status, 'active');
      expect(tx.syncRevision, 0);
      expect(tx.syncStatus, 'pending');
      final withPostings = await fx.transactions.getTransactionWithPostings(
        tx.uuid,
      );
      fx.assertBalanced(withPostings);
      expect(withPostings.postings.length, 2);
      expect(await historyCount(fx, tx.id), 1);

      final income = await fx.transactions.createIncome(
        accountUuid: bank.uuid,
        categoryId: 'other',
        amount: inr(100000),
        occurredAt: dt(2026, 1, 11),
        paymentChannel: 'UPI',
      );
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(income.uuid),
      );
    });

    test(
      'zero, negative, unknown account/category, bad channel rejected',
      () async {
        final bank = await fx.bank();
        await expectLater(
          fx.transactions.createExpense(
            accountUuid: bank.uuid,
            categoryId: 'food',
            amount: Money.zero('INR'),
            occurredAt: dt(2026, 1, 10),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.transactions.createExpense(
            accountUuid: bank.uuid,
            categoryId: 'food',
            amount: inr(-100),
            occurredAt: dt(2026, 1, 10),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.transactions.createExpense(
            accountUuid: 'missing',
            categoryId: 'food',
            amount: inr(100),
            occurredAt: dt(2026, 1, 10),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.transactions.createExpense(
            accountUuid: bank.uuid,
            categoryId: 'nope',
            amount: inr(100),
            occurredAt: dt(2026, 1, 10),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.transactions.createExpense(
            accountUuid: bank.uuid,
            categoryId: 'food',
            amount: inr(100),
            occurredAt: dt(2026, 1, 10),
            paymentChannel: 'Cheque',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        expect(await fx.transactions.listTransactions(), isEmpty);
      },
    );

    test('expense with an income-only category is rejected', () async {
      final bank = await fx.bank();
      final incomeOnly = await fx.categories.createCategory(
        name: 'Gifts',
        kind: 'income',
        iconCodePoint: 0xe002,
      );
      await expectLater(
        fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: incomeOnly.categoryId,
          amount: inr(100),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('transfer and card payment', () {
    test('transfer moves between accounts with balanced postings', () async {
      final (bank, cash) = await twoAccounts();
      final tx = await fx.transactions.createTransfer(
        sourceAccountUuid: bank.uuid,
        destinationAccountUuid: cash.uuid,
        amount: inr(100000),
        occurredAt: dt(2026, 1, 15),
        paymentChannel: 'Bank Transfer',
      );
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(tx.uuid),
      );
      final snapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEndExclusive: DateTime.utc(2026, 2, 1),
      );
      final period = computeReporting(snapshot);
      expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 900000);
      expect(period.closingBalances[cash.uuid]!.amountMinorUnits, 100000);
      expect(period.transferTotal.amountMinorUnits, 100000);
      expect(period.expenseTotal.amountMinorUnits, 0);
    });

    test(
      'same-account transfer and wrong card-payment sides rejected',
      () async {
        final bank = await fx.bank();
        await expectLater(
          fx.transactions.createTransfer(
            sourceAccountUuid: bank.uuid,
            destinationAccountUuid: bank.uuid,
            amount: inr(1000),
            occurredAt: dt(2026, 1, 15),
            paymentChannel: 'Bank Transfer',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        final card = await fx.card();
        await expectLater(
          fx.transactions.createCardPayment(
            sourceAccountUuid: card.uuid,
            cardAccountUuid: card.uuid,
            amount: inr(1000),
            occurredAt: dt(2026, 1, 15),
            paymentChannel: 'Bank Transfer',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.transactions.createCardPayment(
            sourceAccountUuid: bank.uuid,
            cardAccountUuid: bank.uuid,
            amount: inr(1000),
            occurredAt: dt(2026, 1, 15),
            paymentChannel: 'Bank Transfer',
          ),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );

    test('card payment debits the card and credits the bank', () async {
      final bank = await fx.bankWithOpening(inr(1000000));
      final card = await fx.card();
      await fx.transactions.createExpense(
        accountUuid: card.uuid,
        categoryId: 'shopping',
        amount: inr(200000),
        occurredAt: dt(2026, 1, 12),
        paymentChannel: 'Card',
      );
      await fx.transactions.createCardPayment(
        sourceAccountUuid: bank.uuid,
        cardAccountUuid: card.uuid,
        amount: inr(200000),
        occurredAt: dt(2026, 1, 20),
        paymentChannel: 'Bank Transfer',
      );
      final snapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEndExclusive: DateTime.utc(2026, 2, 1),
      );
      final period = computeReporting(snapshot);
      expect(period.closingBalances[bank.uuid]!.amountMinorUnits, 800000);
      expect(period.closingBalances[card.uuid]!.amountMinorUnits, 0);
      expect(period.cardPaymentTotal.amountMinorUnits, 200000);
    });
  });

  group('refunds', () {
    test('partial refunds, capacity, and restore-capacity guard', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      expect(await fx.transactions.refundableCapacity(original.uuid), 50000);
      final refund1 = await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(20000),
        occurredAt: dt(2026, 2, 5),
        paymentChannel: 'Cash',
      );
      expect(refund1.categoryId, 'food');
      expect(refund1.refundAccountId, bank.uuid);
      expect(await fx.transactions.refundableCapacity(original.uuid), 30000);
      await expectLater(
        fx.transactions.createRefund(
          originalUuid: original.uuid,
          refundAccountUuid: bank.uuid,
          amount: inr(30001),
          occurredAt: dt(2026, 2, 6),
          paymentChannel: 'Cash',
        ),
        throwsA(isA<PostingValidationException>()),
      );

      // Deleting a refund restores capacity; restoring past capacity
      // is rejected once a replacement refund has taken the room.
      final refund2 = await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(20000),
        occurredAt: dt(2026, 2, 6),
        paymentChannel: 'Cash',
      );
      await fx.transactions.deleteTransaction(refund1.uuid);
      expect(await fx.transactions.refundableCapacity(original.uuid), 30000);
      final refund3 = await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(30000),
        occurredAt: dt(2026, 2, 7),
        paymentChannel: 'Cash',
      );
      await expectLater(
        fx.transactions.restoreTransaction(refund1.uuid),
        throwsA(isA<PostingValidationException>()),
      );
      await fx.transactions.deleteTransaction(refund2.uuid);
      await fx.transactions.deleteTransaction(refund3.uuid);
      final restored = await fx.transactions.restoreTransaction(refund1.uuid);
      expect(restored.status, 'active');
    });

    test('refund through a different account and income refund', () async {
      final bank = await fx.bank();
      final cash = await fx.cash();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      final refund = await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: cash.uuid,
        amount: inr(20000),
        occurredAt: dt(2026, 2, 5),
        paymentChannel: 'Cash',
      );
      expect(refund.refundAccountId, cash.uuid);
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(refund.uuid),
      );

      final income = await fx.transactions.createIncome(
        accountUuid: bank.uuid,
        categoryId: 'other',
        amount: inr(100000),
        occurredAt: dt(2026, 1, 11),
        paymentChannel: 'UPI',
      );
      final incomeRefund = await fx.transactions.createRefund(
        originalUuid: income.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(30000),
        occurredAt: dt(2026, 2, 5),
        paymentChannel: 'UPI',
      );
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(incomeRefund.uuid),
      );
    });

    test(
      'refund of a transfer is rejected; refund + reversal cannot coexist',
      () async {
        final bank = await fx.bank();
        final cash = await fx.cash();
        final transfer = await fx.transactions.createTransfer(
          sourceAccountUuid: bank.uuid,
          destinationAccountUuid: cash.uuid,
          amount: inr(10000),
          occurredAt: dt(2026, 1, 15),
          paymentChannel: 'Bank Transfer',
        );
        await expectLater(
          fx.transactions.createRefund(
            originalUuid: transfer.uuid,
            refundAccountUuid: bank.uuid,
            amount: inr(1000),
            occurredAt: dt(2026, 2, 5),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );

        final original = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(50000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        await fx.transactions.createRefund(
          originalUuid: original.uuid,
          refundAccountUuid: bank.uuid,
          amount: inr(10000),
          occurredAt: dt(2026, 2, 5),
          paymentChannel: 'Cash',
        );
        await expectLater(
          fx.transactions.createReversal(
            originalUuid: original.uuid,
            occurredAt: dt(2026, 2, 6),
          ),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );

    test(
      'refund category snapshot survives recategorising the original',
      () async {
        final bank = await fx.bank();
        final original = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(50000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        final refund = await fx.transactions.createRefund(
          originalUuid: original.uuid,
          refundAccountUuid: bank.uuid,
          amount: inr(20000),
          occurredAt: dt(2026, 2, 5),
          paymentChannel: 'Cash',
        );
        await fx.transactions.editTransaction(
          original.uuid,
          const TransactionEdit(categoryId: 'shopping'),
        );
        final refundAfter = await fx.transactions.getTransactionByUuid(
          refund.uuid,
        );
        expect(refundAfter!.categoryId, 'food');
        final snapshot = await fx.transactions.loadReportingSnapshot(
          periodStart: DateTime.utc(2026, 2, 1),
          periodEndExclusive: DateTime.utc(2026, 3, 1),
        );
        final period = computeReporting(snapshot);
        expect(period.expenseByCategory['food']!.amountMinorUnits, -20000);
        expect(period.expenseByCategory.containsKey('shopping'), isFalse);
      },
    );

    test('refund amount and category snapshot are immutable on edit', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      final refund = await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(20000),
        occurredAt: dt(2026, 2, 5),
        paymentChannel: 'Cash',
      );
      await expectLater(
        fx.transactions.editTransaction(
          refund.uuid,
          TransactionEdit(amount: inr(10000)),
        ),
        throwsA(isA<PostingValidationException>()),
      );
      final edited = await fx.transactions.editTransaction(
        refund.uuid,
        const TransactionEdit(description: 'Returned'),
      );
      expect(edited.description, 'Returned');
    });

    test(
      'refund with an archived category ledger is allowed (inherited)',
      () async {
        final bank = await fx.bank();
        final original = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(50000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        await fx.categories.archiveCategory('food');
        final refund = await fx.transactions.createRefund(
          originalUuid: original.uuid,
          refundAccountUuid: bank.uuid,
          amount: inr(20000),
          occurredAt: dt(2026, 2, 5),
          paymentChannel: 'Cash',
        );
        fx.assertBalanced(
          await fx.transactions.getTransactionWithPostings(refund.uuid),
        );
      },
    );
  });

  group('adjustments', () {
    test(
      'all four reasons with the correct counterparts and buckets',
      () async {
        final bank = await fx.bankWithOpening(inr(1000000));
        await fx.transactions.createAdjustment(
          accountUuid: bank.uuid,
          adjustmentReason: 'balance_correction',
          direction: AdjustmentDirection.increase,
          amount: inr(5000),
          occurredAt: dt(2026, 2, 1),
          paymentChannel: 'Bank Transfer',
        );
        await fx.transactions.createAdjustment(
          accountUuid: bank.uuid,
          adjustmentReason: 'fee_correction',
          direction: AdjustmentDirection.decrease,
          amount: inr(10000),
          occurredAt: dt(2026, 2, 2),
          paymentChannel: 'Bank Transfer',
          categoryId: 'food',
          reportingKind: ReportingKind.expense,
        );
        await fx.transactions.createAdjustment(
          accountUuid: bank.uuid,
          adjustmentReason: 'other',
          direction: AdjustmentDirection.increase,
          amount: inr(7500),
          occurredAt: dt(2026, 2, 3),
          paymentChannel: 'Bank Transfer',
        );
        final snapshot = await fx.transactions.loadReportingSnapshot(
          periodStart: DateTime.utc(2026, 2, 1),
          periodEndExclusive: DateTime.utc(2026, 3, 1),
        );
        final period = computeReporting(snapshot);
        expect(period.balanceCorrectionEffect.amountMinorUnits, 5000);
        expect(period.feeCorrectionEffect.amountMinorUnits, 0);
        expect(period.otherAdjustmentEffect.amountMinorUnits, 7500);
        expect(period.expenseByCategory['food']!.amountMinorUnits, 10000);
        expect(period.expenseTotal.amountMinorUnits, 10000);
      },
    );

    test(
      'opening_balance_correction requires an opening_balance related row',
      () async {
        final bank = await fx.bankWithOpening(inr(1000000));
        final opening = (await fx.transactions.listTransactions()).single;
        final correction = await fx.transactions.createAdjustment(
          accountUuid: bank.uuid,
          adjustmentReason: 'opening_balance_correction',
          direction: AdjustmentDirection.increase,
          amount: inr(30000),
          occurredAt: dt(2026, 2, 1),
          paymentChannel: 'Bank Transfer',
          relatedTransactionUuid: opening.uuid,
        );
        expect(correction.adjustmentReason, 'opening_balance_correction');

        final expense = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(5000),
          occurredAt: dt(2026, 2, 2),
          paymentChannel: 'Cash',
        );
        await expectLater(
          fx.transactions.createAdjustment(
            accountUuid: bank.uuid,
            adjustmentReason: 'opening_balance_correction',
            direction: AdjustmentDirection.increase,
            amount: inr(1000),
            occurredAt: dt(2026, 2, 3),
            paymentChannel: 'Bank Transfer',
            relatedTransactionUuid: expense.uuid,
          ),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );

    test('categorised reason without reportingKind is rejected', () async {
      final bank = await fx.bank();
      await expectLater(
        fx.transactions.createAdjustment(
          accountUuid: bank.uuid,
          adjustmentReason: 'fee_correction',
          direction: AdjustmentDirection.increase,
          amount: inr(1000),
          occurredAt: dt(2026, 2, 1),
          paymentChannel: 'Bank Transfer',
          categoryId: 'food',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('opening balances', () {
    test(
      'create blocked once the account has activity; edit before activity',
      () async {
        final bank = await fx.bank();
        await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(5000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        await expectLater(
          fx.transactions.createOpeningBalance(
            accountUuid: bank.uuid,
            signedAmount: inr(100000),
            occurredAt: dt(2026, 1, 1),
            paymentChannel: 'Bank Transfer',
          ),
          throwsA(isA<PostingValidationException>()),
        );

        final fresh = await fx.bank(name: 'Fresh');
        final opening = await fx.transactions.createOpeningBalance(
          accountUuid: fresh.uuid,
          signedAmount: inr(100000),
          occurredAt: dt(2026, 1, 1),
          paymentChannel: 'Bank Transfer',
        );
        expect(opening.kind, 'opening_balance');
        final edited = await fx.transactions.editOpeningBalance(
          accountUuid: fresh.uuid,
          signedAmount: inr(150000),
        );
        expect(edited.amountMinorUnits, 150000);
        expect(edited.syncRevision, 1);
      },
    );

    test(
      'opening edit blocked after activity; delete blocked after activity',
      () async {
        final bank = await fx.bankWithOpening(inr(1000000));
        await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(5000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        await expectLater(
          fx.transactions.editOpeningBalance(
            accountUuid: bank.uuid,
            signedAmount: inr(2000000),
          ),
          throwsA(isA<PostingValidationException>()),
        );
        final opening = (await fx.transactions.listTransactions()).firstWhere(
          (t) => t.kind == 'opening_balance',
        );
        await expectLater(
          fx.transactions.deleteTransaction(opening.uuid),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );

    test(
      'restore of a deleted opening is blocked by a replacement opening',
      () async {
        final bank = await fx.bankWithOpening(inr(1000000));
        final first = (await fx.transactions.listTransactions()).firstWhere(
          (t) => t.kind == 'opening_balance',
        );
        await fx.transactions.deleteTransaction(first.uuid);
        await fx.transactions.createOpeningBalance(
          accountUuid: bank.uuid,
          signedAmount: inr(2000000),
          occurredAt: dt(2026, 1, 1),
          paymentChannel: 'Bank Transfer',
        );
        await expectLater(
          fx.transactions.restoreTransaction(first.uuid),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );
  });

  group('reversals', () {
    test('full reversal mirrors postings and isReversed derives', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      expect(await fx.transactions.isReversed(original.uuid), isFalse);
      final reversal = await fx.transactions.createReversal(
        originalUuid: original.uuid,
        occurredAt: dt(2026, 2, 10),
      );
      expect(reversal.kind, 'reversal');
      expect(reversal.amountMinorUnits, 50000);
      expect(reversal.reversesTransactionId, original.uuid);
      expect(await fx.transactions.isReversed(original.uuid), isTrue);
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(reversal.uuid),
      );

      await expectLater(
        fx.transactions.createReversal(
          originalUuid: original.uuid,
          occurredAt: dt(2026, 2, 11),
        ),
        throwsA(isA<PostingValidationException>()),
      );
      await expectLater(
        fx.transactions.createReversal(
          originalUuid: reversal.uuid,
          occurredAt: dt(2026, 2, 11),
        ),
        throwsA(isA<PostingValidationException>()),
      );

      // Deleting the reversal restores the original effect.
      await fx.transactions.deleteTransaction(reversal.uuid);
      expect(await fx.transactions.isReversed(original.uuid), isFalse);
    });

    test('reversal with archived account ledgers still succeeds', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      await fx.accounts.archiveAccount(bank.uuid);
      final reversal = await fx.transactions.createReversal(
        originalUuid: original.uuid,
        occurredAt: dt(2026, 2, 10),
      );
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(reversal.uuid),
      );
    });

    test(
      'reversal of a transfer swaps source and destination fields',
      () async {
        final bank = await fx.bank();
        final cash = await fx.cash();
        final transfer = await fx.transactions.createTransfer(
          sourceAccountUuid: bank.uuid,
          destinationAccountUuid: cash.uuid,
          amount: inr(10000),
          occurredAt: dt(2026, 1, 15),
          paymentChannel: 'Bank Transfer',
        );
        final reversal = await fx.transactions.createReversal(
          originalUuid: transfer.uuid,
          occurredAt: dt(2026, 2, 5),
        );
        expect(reversal.sourceAccountId, cash.uuid);
        expect(reversal.destinationAccountId, bank.uuid);
      },
    );

    test('reversal metadata-only edit; amount edit rejected', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      final reversal = await fx.transactions.createReversal(
        originalUuid: original.uuid,
        occurredAt: dt(2026, 2, 10),
      );
      final edited = await fx.transactions.editTransaction(
        reversal.uuid,
        const TransactionEdit(description: 'Bank error'),
      );
      expect(edited.description, 'Bank error');
      await expectLater(
        fx.transactions.editTransaction(
          reversal.uuid,
          TransactionEdit(amount: inr(100)),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('edit', () {
    test('amount and account edits rebuild postings atomically', () async {
      final bank = await fx.bank();
      final cash = await fx.cash();
      final tx = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      final edited = await fx.transactions.editTransaction(
        tx.uuid,
        TransactionEdit(amount: inr(75000), accountUuid: cash.uuid),
      );
      expect(edited.amountMinorUnits, 75000);
      expect(edited.syncRevision, 1);
      fx.assertBalanced(
        await fx.transactions.getTransactionWithPostings(tx.uuid),
      );
    });

    test('edit with active refunds: amount below refunded rejected, account change rejected', () async {
      final bank = await fx.bank();
      final cash = await fx.cash();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(20000),
        occurredAt: dt(2026, 2, 5),
        paymentChannel: 'Cash',
      );
      await expectLater(
        fx.transactions.editTransaction(
          original.uuid,
          TransactionEdit(amount: inr(15000)),
        ),
        throwsA(isA<PostingValidationException>()),
      );
      await expectLater(
        fx.transactions.editTransaction(
          original.uuid,
          TransactionEdit(accountUuid: cash.uuid),
        ),
        throwsA(isA<PostingValidationException>()),
      );
      final grown = await fx.transactions.editTransaction(
        original.uuid,
        TransactionEdit(amount: inr(60000)),
      );
      expect(grown.amountMinorUnits, 60000);
    });

    test('edit blocked with an active reversal', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      await fx.transactions.createReversal(
        originalUuid: original.uuid,
        occurredAt: dt(2026, 2, 10),
      );
      await expectLater(
        fx.transactions.editTransaction(
          original.uuid,
          const TransactionEdit(description: 'x'),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test(
      'edit bumps revision, sets pending, and writes history snapshots',
      () async {
        final bank = await fx.bank();
        final tx = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(50000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        final before = await historyCount(fx, tx.id);
        final edited = await fx.transactions.editTransaction(
          tx.uuid,
          TransactionEdit(amount: inr(60000)),
        );
        expect(edited.syncRevision, tx.syncRevision + 1);
        expect(edited.syncStatus, 'pending');
        final rows = await (fx.db.select(
          fx.db.transactionHistory,
        )..where((h) => h.transactionId.equals(tx.id))).get();
        expect(rows.length, before + 1);
        final last = rows.last;
        expect(last.changeKind, 'edited');
        expect(last.beforeSnapshot, contains('50000'));
        expect(last.afterSnapshot, contains('60000'));
      },
    );

    test('balancing invariant holds across every created kind', () async {
      final bank = await fx.bankWithOpening(inr(1000000));
      final cash = await fx.cash();
      final card = await fx.card();
      final created = <String>[];
      created.add(
        (await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(5000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        )).uuid,
      );
      created.add(
        (await fx.transactions.createIncome(
          accountUuid: bank.uuid,
          categoryId: 'other',
          amount: inr(9000),
          occurredAt: dt(2026, 1, 11),
          paymentChannel: 'UPI',
        )).uuid,
      );
      created.add(
        (await fx.transactions.createTransfer(
          sourceAccountUuid: bank.uuid,
          destinationAccountUuid: cash.uuid,
          amount: inr(1000),
          occurredAt: dt(2026, 1, 12),
          paymentChannel: 'Bank Transfer',
        )).uuid,
      );
      created.add(
        (await fx.transactions.createCardPayment(
          sourceAccountUuid: bank.uuid,
          cardAccountUuid: card.uuid,
          amount: inr(2000),
          occurredAt: dt(2026, 1, 13),
          paymentChannel: 'Bank Transfer',
        )).uuid,
      );
      created.add(
        (await fx.transactions.createAdjustment(
          accountUuid: bank.uuid,
          adjustmentReason: 'balance_correction',
          direction: AdjustmentDirection.increase,
          amount: inr(300),
          occurredAt: dt(2026, 1, 14),
          paymentChannel: 'Bank Transfer',
        )).uuid,
      );
      for (final uuid in created) {
        fx.assertBalanced(
          await fx.transactions.getTransactionWithPostings(uuid),
        );
      }
    });
  });

  group('delete and restore', () {
    test('delete removes the balance effect; restore brings it back', () async {
      final bank = await fx.bankWithOpening(inr(1000000));
      final expense = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      Future<int> bankBalance() async {
        final snapshot = await fx.transactions.loadReportingSnapshot(
          periodStart: DateTime.utc(2026, 1, 1),
          periodEndExclusive: DateTime.utc(2026, 2, 1),
        );
        return computeReporting(snapshot)
            .closingBalances[bank.uuid]!
            .amountMinorUnits;
      }

      expect(await bankBalance(), 950000);
      final deleted = await fx.transactions.deleteTransaction(expense.uuid);
      expect(deleted.status, 'deleted');
      expect(deleted.syncRevision, 1);
      expect(await bankBalance(), 1000000);
      final restored = await fx.transactions.restoreTransaction(expense.uuid);
      expect(restored.status, 'active');
      expect(await bankBalance(), 950000);
    });

    test('delete blocked with active refunds or reversal', () async {
      final bank = await fx.bank();
      final original = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(50000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      final refund = await fx.transactions.createRefund(
        originalUuid: original.uuid,
        refundAccountUuid: bank.uuid,
        amount: inr(10000),
        occurredAt: dt(2026, 2, 5),
        paymentChannel: 'Cash',
      );
      await expectLater(
        fx.transactions.deleteTransaction(original.uuid),
        throwsA(isA<PostingValidationException>()),
      );
      await fx.transactions.deleteTransaction(refund.uuid);
      final reversal = await fx.transactions.createReversal(
        originalUuid: original.uuid,
        occurredAt: dt(2026, 2, 10),
      );
      await expectLater(
        fx.transactions.deleteTransaction(original.uuid),
        throwsA(isA<PostingValidationException>()),
      );
      await fx.transactions.deleteTransaction(reversal.uuid);
      final deleted = await fx.transactions.deleteTransaction(original.uuid);
      expect(deleted.status, 'deleted');
    });
  });

  group('future-dated transactions', () {
    test(
      'exactly at the clock is accepted; after the clock is rejected',
      () async {
        final bank = await fx.bank();
        final atClock = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(1000),
          occurredAt: testNow(),
          paymentChannel: 'Cash',
        );
        expect(atClock.status, 'active');
        await expectLater(
          fx.transactions.createExpense(
            accountUuid: bank.uuid,
            categoryId: 'food',
            amount: inr(1000),
            occurredAt: testNow().add(const Duration(seconds: 1)),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.transactions.editTransaction(
            atClock.uuid,
            TransactionEdit(occurredAt: testNow().add(const Duration(days: 1))),
          ),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );

    test('backdated transactions are supported', () async {
      final bank = await fx.bank();
      final tx = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(1000),
        occurredAt: dt(2020, 5, 5),
        paymentChannel: 'Cash',
      );
      expect(tx.occurredAt.toUtc(), dt(2020, 5, 5));
    });

    test(
      'restore revalidates the future-date rule against the clock',
      () async {
        final bank = await fx.bank();
        final tx = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(1000),
          occurredAt: dt(2026, 3, 10),
          paymentChannel: 'Cash',
        );
        await fx.transactions.deleteTransaction(tx.uuid);
        // A repository whose clock is earlier than the transaction date
        // must refuse to restore it: it would be future-dated there.
        final earlier = FinancialTransactionRepository(
          fx.db,
          clock: () => DateTime.utc(2026, 3, 1, 12),
          uuidGenerator: () => 'test-early',
        );
        await expectLater(
          earlier.restoreTransaction(tx.uuid),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );
  });
}
