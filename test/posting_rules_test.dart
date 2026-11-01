import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const String inr = 'INR';

LedgerDescriptor userAsset(String id, {bool archived = false}) =>
    LedgerDescriptor(
      ledgerAccountId: id,
      kind: ledgerKindUserAsset,
      normalBalance: LedgerDirection.debit,
      userAccountId: id,
      isArchived: archived,
    );

LedgerDescriptor userLiability(String id, {bool archived = false}) =>
    LedgerDescriptor(
      ledgerAccountId: id,
      kind: ledgerKindUserLiability,
      normalBalance: LedgerDirection.credit,
      userAccountId: id,
      isArchived: archived,
    );

LedgerDescriptor categoryLedger(
  String ledgerId, {
  required String categoryId,
  required String kind,
  bool archived = false,
}) => LedgerDescriptor(
  ledgerAccountId: ledgerId,
  kind: kind,
  normalBalance: kind == ledgerKindSystemExpense
      ? LedgerDirection.debit
      : LedgerDirection.credit,
  categoryId: categoryId,
  isArchived: archived,
);

LedgerDescriptor expenseLedger(String categoryId, {bool archived = false}) =>
    categoryLedger(
      'expense:$categoryId',
      categoryId: categoryId,
      kind: ledgerKindSystemExpense,
      archived: archived,
    );

LedgerDescriptor incomeLedger(String categoryId, {bool archived = false}) =>
    categoryLedger(
      'income:$categoryId',
      categoryId: categoryId,
      kind: ledgerKindSystemIncome,
      archived: archived,
    );

LedgerDescriptor openingEquity() => const LedgerDescriptor(
  ledgerAccountId: openingEquityLedgerId,
  kind: ledgerKindSystemOpeningEquity,
  normalBalance: LedgerDirection.credit,
  isSystem: true,
);

LedgerDescriptor adjustments() => const LedgerDescriptor(
  ledgerAccountId: adjustmentsLedgerId,
  kind: ledgerKindSystemAdjustment,
  normalBalance: LedgerDirection.credit,
  isSystem: true,
);

void expectBalanced(List<PostingDraft> drafts) {
  expect(drafts.length, greaterThanOrEqualTo(2));
  var debits = 0;
  var credits = 0;
  for (final draft in drafts) {
    expect(draft.amountMinorUnits, greaterThan(0));
    if (draft.direction == LedgerDirection.debit) {
      debits += draft.amountMinorUnits;
    } else {
      credits += draft.amountMinorUnits;
    }
  }
  expect(debits, credits);
}

void expectDirections(
  List<PostingDraft> drafts,
  Map<String, LedgerDirection> expected,
) {
  for (final draft in drafts) {
    expect(
      draft.direction,
      expected[draft.ledgerAccountId],
      reason: 'direction of ${draft.ledgerAccountId}',
    );
  }
}

void main() {
  group('LedgerDescriptor shape', () {
    test('exactly one reference shape is enforced by validateShape', () {
      final bothRefs = LedgerDescriptor(
        ledgerAccountId: 'x',
        kind: ledgerKindUserAsset,
        normalBalance: LedgerDirection.debit,
        userAccountId: 'u',
        categoryId: 'c',
      );
      expect(
        bothRefs.validateShape,
        throwsA(isA<PostingValidationException>()),
      );

      final categoryWithoutId = LedgerDescriptor(
        ledgerAccountId: 'expense:food',
        kind: ledgerKindSystemExpense,
        normalBalance: LedgerDirection.debit,
      );
      expect(
        categoryWithoutId.validateShape,
        throwsA(isA<PostingValidationException>()),
      );

      final systemWithRef = LedgerDescriptor(
        ledgerAccountId: adjustmentsLedgerId,
        kind: ledgerKindSystemAdjustment,
        normalBalance: LedgerDirection.credit,
        userAccountId: 'u',
      );
      expect(
        systemWithRef.validateShape,
        throwsA(isA<PostingValidationException>()),
      );

      final unknownKind = LedgerDescriptor(
        ledgerAccountId: 'x',
        kind: 'both',
        normalBalance: LedgerDirection.debit,
        userAccountId: 'u',
      );
      expect(
        unknownKind.validateShape,
        throwsA(isA<PostingValidationException>()),
      );

      final wrongNormal = LedgerDescriptor(
        ledgerAccountId: 'bank',
        kind: ledgerKindUserAsset,
        normalBalance: LedgerDirection.credit,
        userAccountId: 'bank',
      );
      expect(
        wrongNormal.validateShape,
        throwsA(isA<PostingValidationException>()),
      );

      expect(userAsset('bank').validateShape, returnsNormally);
      expect(expenseLedger('builtin_Food').validateShape, returnsNormally);
      expect(openingEquity().validateShape, returnsNormally);
    });

    test('system ledger ids are recognised', () {
      expect(openingEquityLedgerId, 'opening_equity');
      expect(adjustmentsLedgerId, 'adjustments');
    });
  });

  group('expense and income', () {
    test('expense: debit category, credit account', () {
      final drafts = buildExpensePostings(
        categoryLedger: expenseLedger('builtin_Food'),
        accountLedger: userAsset('bank'),
        amountMinorUnits: 50000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'expense:builtin_Food': LedgerDirection.debit,
        'bank': LedgerDirection.credit,
      });
    });

    test('income: debit account, credit category', () {
      final drafts = buildIncomePostings(
        categoryLedger: incomeLedger('builtin_Salary'),
        accountLedger: userAsset('bank'),
        amountMinorUnits: 200000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'bank': LedgerDirection.debit,
        'income:builtin_Salary': LedgerDirection.credit,
      });
    });

    test('expense with an income category ledger is rejected', () {
      expect(
        () => buildExpensePostings(
          categoryLedger: incomeLedger('builtin_Salary'),
          accountLedger: userAsset('bank'),
          amountMinorUnits: 50000,
          currencyCode: inr,
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('zero, negative, and unsupported-currency amounts are rejected', () {
      for (final amount in [0, -1]) {
        expect(
          () => buildExpensePostings(
            categoryLedger: expenseLedger('builtin_Food'),
            accountLedger: userAsset('bank'),
            amountMinorUnits: amount,
            currencyCode: inr,
          ),
          throwsA(isA<PostingValidationException>()),
        );
      }
      expect(
        () => buildExpensePostings(
          categoryLedger: expenseLedger('builtin_Food'),
          accountLedger: userAsset('bank'),
          amountMinorUnits: 100,
          currencyCode: 'XXX',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('transfer and card payment', () {
    test('transfer: debit destination, credit source', () {
      final drafts = buildTwoAccountPostings(
        sourceLedger: userAsset('bank'),
        destinationLedger: userAsset('cash'),
        amountMinorUnits: 100000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'cash': LedgerDirection.debit,
        'bank': LedgerDirection.credit,
      });
    });

    test('card payment: debit card liability, credit bank', () {
      final drafts = buildTwoAccountPostings(
        sourceLedger: userAsset('bank'),
        destinationLedger: userLiability('card'),
        amountMinorUnits: 200000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'card': LedgerDirection.debit,
        'bank': LedgerDirection.credit,
      });
    });

    test('same source and destination is rejected', () {
      expect(
        () => buildTwoAccountPostings(
          sourceLedger: userAsset('bank'),
          destinationLedger: userAsset('bank'),
          amountMinorUnits: 1000,
          currencyCode: inr,
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('archived ledger rejected for new references, allowed inherited', () {
      expect(
        () => buildTwoAccountPostings(
          sourceLedger: userAsset('bank', archived: true),
          destinationLedger: userAsset('cash'),
          amountMinorUnits: 1000,
          currencyCode: inr,
        ),
        throwsA(isA<PostingValidationException>()),
      );
      final inherited = buildTwoAccountPostings(
        sourceLedger: userAsset('bank', archived: true),
        destinationLedger: userAsset('cash', archived: true),
        amountMinorUnits: 1000,
        currencyCode: inr,
        mode: ReferenceMode.inherited,
      );
      expectBalanced(inherited);
    });
  });

  group('refund', () {
    test('expense refund mirrors the original with reversed directions', () {
      final drafts = buildRefundPostings(
        originalKind: 'expense',
        refundAccountLedger: userAsset('bank'),
        categoryLedger: expenseLedger('builtin_Food'),
        amountMinorUnits: 20000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'bank': LedgerDirection.debit,
        'expense:builtin_Food': LedgerDirection.credit,
      });
    });

    test('refund of an income transaction mirrors it', () {
      final drafts = buildRefundPostings(
        originalKind: 'income',
        refundAccountLedger: userAsset('bank'),
        categoryLedger: incomeLedger('builtin_Salary'),
        amountMinorUnits: 30000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'income:builtin_Salary': LedgerDirection.debit,
        'bank': LedgerDirection.credit,
      });
    });

    test(
      'refund of a transfer, card payment, refund, or reversal rejected',
      () {
        for (final kind in ['transfer', 'card_payment', 'refund', 'reversal']) {
          expect(
            () => buildRefundPostings(
              originalKind: kind,
              refundAccountLedger: userAsset('bank'),
              categoryLedger: expenseLedger('builtin_Food'),
              amountMinorUnits: 100,
              currencyCode: inr,
            ),
            throwsA(isA<PostingValidationException>()),
          );
        }
      },
    );

    test(
      'archived category ledger allowed inherited; archived account rejected',
      () {
        final drafts = buildRefundPostings(
          originalKind: 'expense',
          refundAccountLedger: userAsset('bank'),
          categoryLedger: expenseLedger('builtin_Food', archived: true),
          amountMinorUnits: 10000,
          currencyCode: inr,
        );
        expectBalanced(drafts);

        expect(
          () => buildRefundPostings(
            originalKind: 'expense',
            refundAccountLedger: userAsset('bank', archived: true),
            categoryLedger: expenseLedger('builtin_Food'),
            amountMinorUnits: 10000,
            currencyCode: inr,
          ),
          throwsA(isA<PostingValidationException>()),
        );
      },
    );

    test('refund with a mismatched category side is rejected', () {
      expect(
        () => buildRefundPostings(
          originalKind: 'expense',
          refundAccountLedger: userAsset('bank'),
          categoryLedger: incomeLedger('builtin_Salary'),
          amountMinorUnits: 10000,
          currencyCode: inr,
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('adjustment counterpart matrix', () {
    final bank = userAsset('bank');
    final card = userLiability('card');
    final foodExpense = expenseLedger('builtin_Food');
    final salaryIncome = incomeLedger('builtin_Salary');

    test('counterpart ids follow the reason', () {
      expect(
        counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonOpeningCorrection,
        ),
        'opening_equity',
      );
      expect(
        counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonBalanceCorrection,
        ),
        'adjustments',
      );
      expect(
        counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonFeeCorrection,
          categoryId: 'builtin_Food',
          reportingKind: ReportingKind.expense,
        ),
        'expense:builtin_Food',
      );
      expect(
        counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonOther,
          categoryId: 'builtin_Salary',
          reportingKind: ReportingKind.income,
        ),
        'income:builtin_Salary',
      );
    });

    test('counterpart rule violations are rejected', () {
      expect(
        () => counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonOpeningCorrection,
          categoryId: 'builtin_Food',
          reportingKind: ReportingKind.expense,
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonBalanceCorrection,
          categoryId: 'builtin_Food',
          reportingKind: ReportingKind.expense,
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonFeeCorrection,
          categoryId: 'builtin_Food',
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        counterpartLedgerIdForAdjustment(
          adjustmentReason: adjustmentReasonFeeCorrection,
        ),
        'adjustments',
      );
      expect(
        () => counterpartLedgerIdForAdjustment(adjustmentReason: 'nonsense'),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('asset increase debits the account; decrease credits it', () {
      final increase = buildAdjustmentPostings(
        accountLedger: bank,
        counterpartLedger: adjustments(),
        direction: AdjustmentDirection.increase,
        adjustmentReason: adjustmentReasonBalanceCorrection,
        amountMinorUnits: 5000,
        currencyCode: inr,
      );
      expectDirections(increase, {
        'bank': LedgerDirection.debit,
        'adjustments': LedgerDirection.credit,
      });
      final decrease = buildAdjustmentPostings(
        accountLedger: bank,
        counterpartLedger: adjustments(),
        direction: AdjustmentDirection.decrease,
        adjustmentReason: adjustmentReasonBalanceCorrection,
        amountMinorUnits: 5000,
        currencyCode: inr,
      );
      expectDirections(decrease, {
        'bank': LedgerDirection.credit,
        'adjustments': LedgerDirection.debit,
      });
    });

    test('liability increase credits the account; decrease debits it', () {
      final increase = buildAdjustmentPostings(
        accountLedger: card,
        counterpartLedger: adjustments(),
        direction: AdjustmentDirection.increase,
        adjustmentReason: adjustmentReasonBalanceCorrection,
        amountMinorUnits: 5000,
        currencyCode: inr,
      );
      expectDirections(increase, {
        'card': LedgerDirection.credit,
        'adjustments': LedgerDirection.debit,
      });
      final decrease = buildAdjustmentPostings(
        accountLedger: card,
        counterpartLedger: adjustments(),
        direction: AdjustmentDirection.decrease,
        adjustmentReason: adjustmentReasonBalanceCorrection,
        amountMinorUnits: 5000,
        currencyCode: inr,
      );
      expectDirections(decrease, {
        'card': LedgerDirection.debit,
        'adjustments': LedgerDirection.credit,
      });
    });

    test('categorised adjustment uses the category ledger', () {
      final drafts = buildAdjustmentPostings(
        accountLedger: bank,
        counterpartLedger: foodExpense,
        direction: AdjustmentDirection.decrease,
        adjustmentReason: adjustmentReasonFeeCorrection,
        amountMinorUnits: 10000,
        currencyCode: inr,
        categoryId: 'builtin_Food',
        reportingKind: ReportingKind.expense,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'bank': LedgerDirection.credit,
        'expense:builtin_Food': LedgerDirection.debit,
      });
      final incomeDrafts = buildAdjustmentPostings(
        accountLedger: bank,
        counterpartLedger: salaryIncome,
        direction: AdjustmentDirection.increase,
        adjustmentReason: adjustmentReasonOther,
        amountMinorUnits: 10000,
        currencyCode: inr,
        categoryId: 'builtin_Salary',
        reportingKind: ReportingKind.income,
      );
      expectDirections(incomeDrafts, {
        'bank': LedgerDirection.debit,
        'income:builtin_Salary': LedgerDirection.credit,
      });
    });

    test('adjustment against the wrong counterpart ledger is rejected', () {
      expect(
        () => buildAdjustmentPostings(
          accountLedger: bank,
          counterpartLedger: foodExpense,
          direction: AdjustmentDirection.increase,
          adjustmentReason: adjustmentReasonBalanceCorrection,
          amountMinorUnits: 1000,
          currencyCode: inr,
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => buildAdjustmentPostings(
          accountLedger: bank,
          counterpartLedger: salaryIncome,
          direction: AdjustmentDirection.increase,
          adjustmentReason: adjustmentReasonFeeCorrection,
          amountMinorUnits: 1000,
          currencyCode: inr,
          categoryId: 'builtin_Food',
          reportingKind: ReportingKind.expense,
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('opening balance', () {
    test('positive asset opening debits the account', () {
      final drafts = buildOpeningBalancePostings(
        accountLedger: userAsset('bank'),
        openingEquityLedger: openingEquity(),
        signedAmountMinorUnits: 1000000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'bank': LedgerDirection.debit,
        'opening_equity': LedgerDirection.credit,
      });
    });

    test('negative asset opening reverses directions', () {
      final drafts = buildOpeningBalancePostings(
        accountLedger: userAsset('bank'),
        openingEquityLedger: openingEquity(),
        signedAmountMinorUnits: -25000,
        currencyCode: inr,
      );
      expectBalanced(drafts);
      expectDirections(drafts, {
        'bank': LedgerDirection.credit,
        'opening_equity': LedgerDirection.debit,
      });
      expect(drafts.first.amountMinorUnits, 25000);
    });

    test('positive liability opening credits the account (owed)', () {
      final drafts = buildOpeningBalancePostings(
        accountLedger: userLiability('card'),
        openingEquityLedger: openingEquity(),
        signedAmountMinorUnits: 200000,
        currencyCode: inr,
      );
      expectDirections(drafts, {
        'card': LedgerDirection.credit,
        'opening_equity': LedgerDirection.debit,
      });
    });

    test('negative liability opening debits the account (credit balance)', () {
      final drafts = buildOpeningBalancePostings(
        accountLedger: userLiability('card'),
        openingEquityLedger: openingEquity(),
        signedAmountMinorUnits: -50000,
        currencyCode: inr,
      );
      expectDirections(drafts, {
        'card': LedgerDirection.debit,
        'opening_equity': LedgerDirection.credit,
      });
    });

    test('zero opening and minimum magnitude are rejected', () {
      expect(
        () => buildOpeningBalancePostings(
          accountLedger: userAsset('bank'),
          openingEquityLedger: openingEquity(),
          signedAmountMinorUnits: 0,
          currencyCode: inr,
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => buildOpeningBalancePostings(
          accountLedger: userAsset('bank'),
          openingEquityLedger: openingEquity(),
          signedAmountMinorUnits: -9223372036854775808,
          currencyCode: inr,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('reversal', () {
    test('reversal is the exact mirror of the original postings', () {
      final bank = userAsset('bank');
      final food = expenseLedger('builtin_Food');
      final original = buildExpensePostings(
        categoryLedger: food,
        accountLedger: bank,
        amountMinorUnits: 50000,
        currencyCode: inr,
      );
      final reversal = buildReversalPostings(
        originalDrafts: original,
        originalDescriptors: {
          bank.ledgerAccountId: bank,
          food.ledgerAccountId: food,
        },
      );
      expectBalanced(reversal);
      expectDirections(reversal, {
        'expense:builtin_Food': LedgerDirection.credit,
        'bank': LedgerDirection.debit,
      });
      expect(
        reversal.map((d) => d.amountMinorUnits),
        original.map((d) => d.amountMinorUnits),
      );
    });

    test('reversal of unbalanced or empty postings is rejected', () {
      expect(
        () =>
            buildReversalPostings(originalDrafts: [], originalDescriptors: {}),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => buildReversalPostings(
          originalDrafts: [
            const PostingDraft(
              ledgerAccountId: 'bank',
              direction: LedgerDirection.debit,
              amountMinorUnits: 100,
              currencyCode: inr,
            ),
          ],
          originalDescriptors: {'bank': userAsset('bank')},
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('validatePostingSet', () {
    test('rejects single, unbalanced, and mixed-currency sets', () {
      final bank = userAsset('bank');
      final food = expenseLedger('builtin_Food');
      final descriptors = {
        bank.ledgerAccountId: bank,
        food.ledgerAccountId: food,
      };
      final good = buildExpensePostings(
        categoryLedger: food,
        accountLedger: bank,
        amountMinorUnits: 1000,
        currencyCode: inr,
      );
      validatePostingSet(good, descriptors);
      expect(
        () => validatePostingSet(good.sublist(0, 1), descriptors),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => validatePostingSet([
          const PostingDraft(
            ledgerAccountId: 'bank',
            direction: LedgerDirection.debit,
            amountMinorUnits: 100,
            currencyCode: inr,
          ),
          const PostingDraft(
            ledgerAccountId: 'expense:builtin_Food',
            direction: LedgerDirection.credit,
            amountMinorUnits: 99,
            currencyCode: inr,
          ),
        ], descriptors),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => validatePostingSet([
          const PostingDraft(
            ledgerAccountId: 'bank',
            direction: LedgerDirection.debit,
            amountMinorUnits: 100,
            currencyCode: inr,
          ),
          const PostingDraft(
            ledgerAccountId: 'expense:builtin_Food',
            direction: LedgerDirection.credit,
            amountMinorUnits: 100,
            currencyCode: 'USD',
          ),
        ], descriptors),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => validatePostingSet([
          const PostingDraft(
            ledgerAccountId: 'unknown-ledger',
            direction: LedgerDirection.debit,
            amountMinorUnits: 100,
            currencyCode: inr,
          ),
          const PostingDraft(
            ledgerAccountId: 'expense:builtin_Food',
            direction: LedgerDirection.credit,
            amountMinorUnits: 100,
            currencyCode: inr,
          ),
        ], descriptors),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });
}
