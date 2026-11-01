import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
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

  group('createAccount', () {
    test(
      'creates the account and its 1:1 ledger through userAccountId',
      () async {
        final account = await fx.bank();
        final ledger = await fx.accounts.ledgerForAccount(account.uuid);
        expect(ledger, isNotNull);
        expect(ledger!.userAccountId, account.uuid);
        expect(ledger.kind, ledgerKindUserAsset);
        expect(ledger.normalBalance, 'debit');
        // The mapping is through userAccountId; callers must never
        // assume the ledger id equals the account uuid.
      },
    );

    test('positive asset opening creates one balanced opening event', () async {
      final account = await fx.bankWithOpening(inr(1000000));
      final list = await fx.transactions.listTransactions();
      expect(list.length, 1);
      final opening = list.single;
      expect(opening.kind, 'opening_balance');
      expect(opening.amountMinorUnits, 1000000);
      final withPostings = await fx.transactions.getTransactionWithPostings(
        opening.uuid,
      );
      fx.assertBalanced(withPostings);
      final snapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEndExclusive: DateTime.utc(2026, 2, 1),
      );
      final period = computeReporting(snapshot);
      expect(period.closingBalances[account.uuid]!.amountMinorUnits, 1000000);
      expect(period.openingBalanceTotal.amountMinorUnits, 1000000);
    });

    test('negative asset opening reverses posting directions', () async {
      final account = await fx.accounts.createAccount(
        name: 'Overdrawn',
        kind: 'bank',
        openingBalance: inr(-25000),
        openingOccurredAt: dt(2026, 1, 1, 9),
      );
      final snapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEndExclusive: DateTime.utc(2026, 2, 1),
      );
      final period = computeReporting(snapshot);
      expect(period.closingBalances[account.uuid]!.amountMinorUnits, -25000);
    });

    test(
      'liability opening is the amount owed; negative is a credit balance',
      () async {
        final owed = await fx.accounts.createAccount(
          name: 'Card',
          kind: 'credit_card_liability',
          openingBalance: inr(200000),
          openingOccurredAt: dt(2026, 1, 1, 9),
        );
        final credit = await fx.accounts.createAccount(
          name: 'Card2',
          kind: 'credit_card_liability',
          openingBalance: inr(-50000),
          openingOccurredAt: dt(2026, 1, 1, 9),
        );
        final snapshot = await fx.transactions.loadReportingSnapshot(
          periodStart: DateTime.utc(2026, 1, 1),
          periodEndExclusive: DateTime.utc(2026, 2, 1),
        );
        final period = computeReporting(snapshot);
        expect(period.closingBalances[owed.uuid]!.amountMinorUnits, 200000);
        expect(period.closingBalances[credit.uuid]!.amountMinorUnits, -50000);
      },
    );

    test('zero opening creates no event and no postings', () async {
      await fx.accounts.createAccount(
        name: 'Bank',
        kind: 'bank',
        openingBalance: Money.zero('INR'),
        openingOccurredAt: dt(2026, 1, 1, 9),
      );
      expect(await fx.transactions.listTransactions(), isEmpty);
    });

    test(
      'future opening, non-INR, empty name, and unknown kind rejected',
      () async {
        await expectLater(
          fx.accounts.createAccount(
            name: 'Bank',
            kind: 'bank',
            openingBalance: inr(1000),
            openingOccurredAt: DateTime.utc(2026, 3, 16),
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.accounts.createAccount(
            name: 'Bank',
            kind: 'bank',
            currencyCode: 'USD',
          ),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.accounts.createAccount(name: '  ', kind: 'bank'),
          throwsA(isA<PostingValidationException>()),
        );
        await expectLater(
          fx.accounts.createAccount(name: 'Bank', kind: 'nope'),
          throwsA(isA<PostingValidationException>()),
        );
        expect(await fx.accounts.listAccounts(), isEmpty);
      },
    );

    test('a second opening event for the same account is rejected', () async {
      final account = await fx.bankWithOpening(inr(1000000));
      await expectLater(
        fx.transactions.createOpeningBalance(
          accountUuid: account.uuid,
          signedAmount: inr(5000),
          occurredAt: dt(2026, 1, 2),
          paymentChannel: 'Bank Transfer',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('changeClassification', () {
    test('flips ledger kind and normal balance at zero postings', () async {
      final account = await fx.bank();
      final before = await fx.accounts.ledgerForAccount(account.uuid);
      final changed = await fx.accounts.changeClassification(
        account.uuid,
        newKind: 'credit_card_liability',
      );
      expect(changed.kind, 'credit_card_liability');
      final after = await fx.accounts.ledgerForAccount(account.uuid);
      expect(after!.ledgerAccountId, before!.ledgerAccountId);
      expect(after.kind, ledgerKindUserLiability);
      expect(after.normalBalance, 'credit');
    });

    test('rejected once postings exist, including soft-deleted ones', () async {
      final account = await fx.bankWithOpening(inr(1000000));
      await expectLater(
        fx.accounts.changeClassification(
          account.uuid,
          newKind: 'credit_card_liability',
        ),
        throwsA(isA<PostingValidationException>()),
      );

      final plain = await fx.bank(name: 'Plain');
      final expense = await fx.transactions.createExpense(
        accountUuid: plain.uuid,
        categoryId: 'food',
        amount: inr(5000),
        occurredAt: dt(2026, 1, 10),
        paymentChannel: 'Cash',
      );
      await fx.transactions.deleteTransaction(expense.uuid);
      await expectLater(
        fx.accounts.changeClassification(
          plain.uuid,
          newKind: 'credit_card_liability',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('archive and restore', () {
    test('archival mirrors onto the ledger; balances keep history', () async {
      final account = await fx.bankWithOpening(inr(1000000));
      await fx.accounts.archiveAccount(account.uuid);
      final ledger = await fx.accounts.ledgerForAccount(account.uuid);
      expect(ledger!.isArchived, isTrue);
      final archived = await fx.accounts.getAccountByUuid(account.uuid);
      expect(archived!.isArchived, isTrue);

      // New transactions reject the archived account.
      await expectLater(
        fx.transactions.createExpense(
          accountUuid: account.uuid,
          categoryId: 'food',
          amount: inr(1000),
          occurredAt: dt(2026, 1, 10),
          paymentChannel: 'Cash',
        ),
        throwsA(isA<PostingValidationException>()),
      );

      // History and balances are preserved.
      final snapshot = await fx.transactions.loadReportingSnapshot(
        periodStart: DateTime.utc(2026, 1, 1),
        periodEndExclusive: DateTime.utc(2026, 2, 1),
      );
      final period = computeReporting(snapshot);
      expect(period.closingBalances[account.uuid]!.amountMinorUnits, 1000000);

      await fx.accounts.restoreAccount(account.uuid);
      final restoredLedger = await fx.accounts.ledgerForAccount(account.uuid);
      expect(restoredLedger!.isArchived, isFalse);
    });
  });

  group('presentation', () {
    test('rename updates presentation only', () async {
      final account = await fx.bank();
      final renamed = await fx.accounts.updateAccountPresentation(
        account.uuid,
        name: 'Main Bank',
      );
      expect(renamed.name, 'Main Bank');
      expect(renamed.currencyCode, 'INR');
      expect(renamed.kind, 'bank');
    });
  });
}
