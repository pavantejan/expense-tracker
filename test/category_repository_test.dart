import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_stage2_helpers.dart';

void main() {
  late Stage2Fixture fx;

  setUp(() async {
    fx = await Stage2Fixture.create();
  });

  tearDown(() async {
    await fx.close();
  });

  group('seeded built-in categories', () {
    test('eight built-ins, all both, each with two system ledgers', () async {
      final categories = await fx.categories.listCategories();
      expect(categories.length, 8);
      for (final category in categories) {
        expect(category.kind, 'both');
        expect(category.origin, 'builtin');
        final ledgers = await fx.categories.ledgersForCategory(
          category.categoryId,
        );
        expect(ledgers.length, 2);
        expect(ledgers['expense:${category.categoryId}'], isNotNull);
        expect(ledgers['income:${category.categoryId}'], isNotNull);
      }
    });

    test('built-in renaming is rejected', () async {
      await expectLater(
        fx.categories.updateCategoryPresentation('food', name: 'Meals'),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('createCategory', () {
    test('custom id prefix and per-side ledgers follow the kind', () async {
      final both = await fx.categories.createCategory(
        name: 'Pets',
        kind: 'both',
        iconCodePoint: 0xe000,
      );
      expect(both.categoryId, startsWith('custom_'));
      expect(
        (await fx.categories.ledgersForCategory(both.categoryId)).length,
        2,
      );

      final expenseOnly = await fx.categories.createCategory(
        name: 'Fees',
        kind: 'expense',
        iconCodePoint: 0xe001,
      );
      final expenseLedgers = await fx.categories.ledgersForCategory(
        expenseOnly.categoryId,
      );
      expect(expenseLedgers.length, 1);
      expect(
        expenseLedgers.containsKey('expense:${expenseOnly.categoryId}'),
        isTrue,
      );

      final incomeOnly = await fx.categories.createCategory(
        name: 'Gifts',
        kind: 'income',
        iconCodePoint: 0xe002,
      );
      final incomeLedgers = await fx.categories.ledgersForCategory(
        incomeOnly.categoryId,
      );
      expect(incomeLedgers.length, 1);
      expect(
        incomeLedgers.containsKey('income:${incomeOnly.categoryId}'),
        isTrue,
      );
    });

    test('custom category can be renamed', () async {
      final category = await fx.categories.createCategory(
        name: 'Pets',
        kind: 'both',
        iconCodePoint: 0xe000,
      );
      final renamed = await fx.categories.updateCategoryPresentation(
        category.categoryId,
        name: 'Animals',
      );
      expect(renamed.name, 'Animals');
    });

    test('unknown kind and empty name are rejected', () async {
      await expectLater(
        fx.categories.createCategory(
          name: 'X',
          kind: 'bothways',
          iconCodePoint: 0,
        ),
        throwsA(isA<PostingValidationException>()),
      );
      await expectLater(
        fx.categories.createCategory(name: ' ', kind: 'both', iconCodePoint: 0),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('changeCategoryKind', () {
    test(
      'at zero postings, included sides are created and removed sides archived',
      () async {
        final category = await fx.categories.createCategory(
          name: 'Pets',
          kind: 'expense',
          iconCodePoint: 0xe000,
        );
        expect(
          (await fx.categories.ledgersForCategory(category.categoryId)).length,
          1,
        );
        await fx.categories.changeCategoryKind(
          category.categoryId,
          newKind: 'both',
        );
        final ledgers = await fx.categories.ledgersForCategory(
          category.categoryId,
        );
        expect(ledgers.length, 2);
        expect(ledgers['income:${category.categoryId}']!.isArchived, isFalse);

        await fx.categories.changeCategoryKind(
          category.categoryId,
          newKind: 'income',
        );
        // The expense ledger row still exists (never hard-deleted) but
        // is archived; the income side is live.
        final expenseRow = await fx.categories.ledgerForCategorySide(
          category.categoryId,
          ReportingKind.expense,
        );
        expect(expenseRow, isNotNull);
        expect(expenseRow!.isArchived, isTrue);
        final incomeRow = await fx.categories.ledgerForCategorySide(
          category.categoryId,
          ReportingKind.income,
        );
        expect(incomeRow, isNotNull);
        expect(incomeRow!.isArchived, isFalse);
      },
    );

    test('rejected once postings exist, including soft-deleted ones', () async {
      final category = await fx.categories.createCategory(
        name: 'Pets',
        kind: 'both',
        iconCodePoint: 0xe000,
      );
      final bank = await fx.bank();
      final expense = await fx.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: category.categoryId,
        amount: inr(5000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      await fx.transactions.deleteTransaction(expense.uuid);
      await expectLater(
        fx.categories.changeCategoryKind(
          category.categoryId,
          newKind: 'expense',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('archive and restore', () {
    test(
      'archival mirrors onto ledgers; new use rejected, history kept',
      () async {
        final bank = await fx.bank();
        final expense = await fx.transactions.createExpense(
          accountUuid: bank.uuid,
          categoryId: 'food',
          amount: inr(5000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        );
        expect(expense.status, 'active');
        await fx.categories.archiveCategory('food');
        final ledgers = await fx.categories.ledgersForCategory('food');
        expect(ledgers.length, 2);
        expect(ledgers.values.every((ledger) => ledger.isArchived), isTrue);

        await expectLater(
          fx.transactions.createExpense(
            accountUuid: bank.uuid,
            categoryId: 'food',
            amount: inr(1000),
            occurredAt: dt(2026, 1, 11),
            paymentChannel: 'Cash',
          ),
          throwsA(isA<PostingValidationException>()),
        );

        // Restoring the category restores its ledgers and the history
        // still balances.
        await fx.categories.restoreCategory('food');
        final restored = await fx.categories.ledgersForCategory('food');
        expect(restored.length, 2);
        final withPostings = await fx.transactions.getTransactionWithPostings(
          expense.uuid,
        );
        fx.assertBalanced(withPostings);
      },
    );
  });
}
