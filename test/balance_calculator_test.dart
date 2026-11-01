import 'package:expense_tracker/core/domain/ledger/balance_calculator.dart';
import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

BalancePosting posting(
  String ledgerId,
  LedgerDirection direction,
  int amount, {
  LedgerDirection normal = LedgerDirection.debit,
  String currency = 'INR',
}) => BalancePosting(
  ledgerAccountId: ledgerId,
  direction: direction,
  amountMinorUnits: amount,
  currencyCode: currency,
  normalBalance: normal,
);

void main() {
  const calculator = BalanceCalculator();

  group('balanceForLedger', () {
    test('asset: normal-side postings positive, opposite negative', () {
      final balance = calculator.balanceForLedger(
        [
          posting('bank', LedgerDirection.debit, 100000),
          posting('bank', LedgerDirection.credit, 30000),
        ],
        ledgerAccountId: 'bank',
        normalBalance: LedgerDirection.debit,
        currencyCode: 'INR',
      );
      expect(balance.amountMinorUnits, 70000);
    });

    test('liability: natural balance is the amount owed (C4)', () {
      // Card purchase 200000 (credit) then payment 200000 (debit).
      final zero = calculator.balanceForLedger(
        [
          posting(
            'card',
            LedgerDirection.credit,
            200000,
            normal: LedgerDirection.credit,
          ),
          posting(
            'card',
            LedgerDirection.debit,
            200000,
            normal: LedgerDirection.credit,
          ),
        ],
        ledgerAccountId: 'card',
        normalBalance: LedgerDirection.credit,
        currencyCode: 'INR',
      );
      expect(zero.amountMinorUnits, 0);

      // Approved fixture shape: a 200000 purchase (credit) plus
      // 400000 of debits (payment + reversal) nets to -200000 owed.
      final owed = calculator.balanceForLedger(
        [
          posting(
            'card',
            LedgerDirection.debit,
            400000,
            normal: LedgerDirection.credit,
          ),
          posting(
            'card',
            LedgerDirection.credit,
            200000,
            normal: LedgerDirection.credit,
          ),
        ],
        ledgerAccountId: 'card',
        normalBalance: LedgerDirection.credit,
        currencyCode: 'INR',
      );
      expect(owed.amountMinorUnits, -200000);
    });

    test('empty postings return zero', () {
      final balance = calculator.balanceForLedger(
        [],
        ledgerAccountId: 'bank',
        normalBalance: LedgerDirection.debit,
        currencyCode: 'INR',
      );
      expect(balance, Money.zero('INR'));
    });

    test('overflow throws StateError instead of wrapping (D5)', () {
      expect(
        () => calculator.balanceForLedger(
          [
            posting('bank', LedgerDirection.debit, 9223372036854775807),
            posting('bank', LedgerDirection.debit, 1),
          ],
          ledgerAccountId: 'bank',
          normalBalance: LedgerDirection.debit,
          currencyCode: 'INR',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('foreign posting, currency mismatch, and normal mismatch fail', () {
      expect(
        () => calculator.balanceForLedger(
          [posting('other', LedgerDirection.debit, 100)],
          ledgerAccountId: 'bank',
          normalBalance: LedgerDirection.debit,
          currencyCode: 'INR',
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => calculator.balanceForLedger(
          [posting('bank', LedgerDirection.debit, 100, currency: 'USD')],
          ledgerAccountId: 'bank',
          normalBalance: LedgerDirection.debit,
          currencyCode: 'INR',
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => calculator.balanceForLedger(
          [
            posting('bank', LedgerDirection.debit, 100),
            posting(
              'bank',
              LedgerDirection.debit,
              50,
              normal: LedgerDirection.credit,
            ),
          ],
          ledgerAccountId: 'bank',
          normalBalance: LedgerDirection.debit,
          currencyCode: 'INR',
        ),
        throwsA(isA<PostingValidationException>()),
      );
      expect(
        () => calculator.balanceForLedger(
          [posting('bank', LedgerDirection.debit, 0)],
          ledgerAccountId: 'bank',
          normalBalance: LedgerDirection.debit,
          currencyCode: 'INR',
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('balancesByLedger', () {
    test('groups postings and omits ledgers with no postings', () {
      final balances = calculator.balancesByLedger([
        posting('bank', LedgerDirection.debit, 100000),
        posting('bank', LedgerDirection.credit, 30000),
        posting(
          'card',
          LedgerDirection.credit,
          200000,
          normal: LedgerDirection.credit,
        ),
      ]);
      expect(balances['bank']!.amountMinorUnits, 70000);
      expect(balances['card']!.amountMinorUnits, 200000);
      expect(balances.containsKey('cash'), isFalse);
    });

    test('mixed currencies within one ledger fail closed', () {
      expect(
        () => calculator.balancesByLedger([
          posting('bank', LedgerDirection.debit, 100),
          posting('bank', LedgerDirection.debit, 50, currency: 'USD'),
        ]),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });
}
