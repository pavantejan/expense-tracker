import 'package:expense_tracker/core/domain/ledger/balance_calculator.dart';
import 'package:expense_tracker/core/domain/ledger/posting_rules.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/core/domain/reporting.dart';
import 'package:flutter_test/flutter_test.dart';

const String food = 'builtin_Food';
const String shopping = 'builtin_Shopping';
const String salary = 'builtin_Salary';

Map<String, LedgerDescriptor> ledgerMap() => {
  'bank-ledger': const LedgerDescriptor(
    ledgerAccountId: 'bank-ledger',
    kind: ledgerKindUserAsset,
    normalBalance: LedgerDirection.debit,
    userAccountId: 'bank',
  ),
  'cash-ledger': const LedgerDescriptor(
    ledgerAccountId: 'cash-ledger',
    kind: ledgerKindUserAsset,
    normalBalance: LedgerDirection.debit,
    userAccountId: 'cash',
  ),
  'card-ledger': const LedgerDescriptor(
    ledgerAccountId: 'card-ledger',
    kind: ledgerKindUserLiability,
    normalBalance: LedgerDirection.credit,
    userAccountId: 'card',
  ),
  'expense:$food': const LedgerDescriptor(
    ledgerAccountId: 'expense:$food',
    kind: ledgerKindSystemExpense,
    normalBalance: LedgerDirection.debit,
    categoryId: food,
  ),
  'expense:$shopping': const LedgerDescriptor(
    ledgerAccountId: 'expense:$shopping',
    kind: ledgerKindSystemExpense,
    normalBalance: LedgerDirection.debit,
    categoryId: shopping,
  ),
  'income:$salary': const LedgerDescriptor(
    ledgerAccountId: 'income:$salary',
    kind: ledgerKindSystemIncome,
    normalBalance: LedgerDirection.credit,
    categoryId: salary,
  ),
  openingEquityLedgerId: const LedgerDescriptor(
    ledgerAccountId: openingEquityLedgerId,
    kind: ledgerKindSystemOpeningEquity,
    normalBalance: LedgerDirection.credit,
    isSystem: true,
  ),
  adjustmentsLedgerId: const LedgerDescriptor(
    ledgerAccountId: adjustmentsLedgerId,
    kind: ledgerKindSystemAdjustment,
    normalBalance: LedgerDirection.credit,
    isSystem: true,
  ),
};

ReportingPosting rp(
  String tx,
  String ledger,
  LedgerDirection direction,
  int amount,
  DateTime at,
) => ReportingPosting(
  transactionUuid: tx,
  ledgerAccountId: ledger,
  direction: direction,
  amountMinorUnits: amount,
  currencyCode: 'INR',
  occurredAt: at,
);

ReportingEvent ev(
  String uuid,
  String kind,
  int amount,
  DateTime at,
  List<ReportingPosting> postings, {
  String? categoryId,
  String? adjustmentReason,
  String? reversesTransactionId,
  String status = 'active',
}) => ReportingEvent(
  transactionUuid: uuid,
  kind: kind,
  categoryId: categoryId,
  adjustmentReason: adjustmentReason,
  amountMinorUnits: amount,
  currencyCode: 'INR',
  occurredAt: at,
  status: status,
  reversesTransactionId: reversesTransactionId,
  postings: postings,
);

ReversalContext contextFor(ReportingEvent original) => ReversalContext(
  originalTransactionUuid: original.transactionUuid,
  originalKind: original.kind,
  originalAdjustmentReason: original.adjustmentReason,
  originalCategoryId: original.categoryId,
  originalOccurredAt: original.occurredAt,
  originalStatus: original.status,
  originalAmountMinorUnits: original.amountMinorUnits,
  originalCurrencyCode: original.currencyCode,
  originalPostings: original.postings,
);

ReportingSnapshot snapshot({
  required DateTime start,
  required DateTime end,
  required List<ReportingEvent> movements,
  required List<ReportingPosting> closing,
  required List<ReportingPosting> current,
  Map<String, ReversalContext> contexts = const {},
}) => ReportingSnapshot(
  periodStart: start,
  periodEndExclusive: end,
  movements: movements,
  closingPostings: closing,
  currentPostings: current,
  ledgerAccounts: ledgerMap(),
  reversalContexts: contexts,
);

DateTime jan(int day) => DateTime.utc(2026, 1, day, 10);
DateTime feb(int day) => DateTime.utc(2026, 2, day, 10);
DateTime mar(int day) => DateTime.utc(2026, 3, day, 10);

/// The approved January/February fixture (final corrected plan §6).
class Fixture {
  late final ReportingEvent opening;
  late final ReportingEvent janFoodExpense;
  late final ReportingEvent janCardPurchase;
  late final ReportingEvent janTransfer;
  late final ReportingEvent janCardPayment;
  late final ReportingEvent febRefund;
  late final ReportingEvent febReversal;
  late final ReportingEvent febCatAdjustment;
  late final ReportingEvent febUncatAdjustment;

  Fixture() {
    opening = ev('opening', 'opening_balance', 1000000, jan(1), [
      rp('opening', 'bank-ledger', LedgerDirection.debit, 1000000, jan(1)),
      rp(
        'opening',
        openingEquityLedgerId,
        LedgerDirection.credit,
        1000000,
        jan(1),
      ),
    ]);
    janFoodExpense = ev('exp-food-jan', 'expense', 50000, jan(10), [
      rp(
        'exp-food-jan',
        'expense:$food',
        LedgerDirection.debit,
        50000,
        jan(10),
      ),
      rp('exp-food-jan', 'bank-ledger', LedgerDirection.credit, 50000, jan(10)),
    ], categoryId: food);
    janCardPurchase = ev('exp-card-jan', 'expense', 200000, jan(12), [
      rp(
        'exp-card-jan',
        'expense:$shopping',
        LedgerDirection.debit,
        200000,
        jan(12),
      ),
      rp(
        'exp-card-jan',
        'card-ledger',
        LedgerDirection.credit,
        200000,
        jan(12),
      ),
    ], categoryId: shopping);
    janTransfer = ev('transfer-jan', 'transfer', 100000, jan(15), [
      rp('transfer-jan', 'cash-ledger', LedgerDirection.debit, 100000, jan(15)),
      rp(
        'transfer-jan',
        'bank-ledger',
        LedgerDirection.credit,
        100000,
        jan(15),
      ),
    ]);
    janCardPayment = ev('cardpay-jan', 'card_payment', 200000, jan(20), [
      rp('cardpay-jan', 'card-ledger', LedgerDirection.debit, 200000, jan(20)),
      rp('cardpay-jan', 'bank-ledger', LedgerDirection.credit, 200000, jan(20)),
    ]);
    febRefund = ev(
      'refund-feb',
      'refund',
      20000,
      feb(5),
      [
        rp('refund-feb', 'bank-ledger', LedgerDirection.debit, 20000, feb(5)),
        rp(
          'refund-feb',
          'expense:$food',
          LedgerDirection.credit,
          20000,
          feb(5),
        ),
      ],
      categoryId: food,
      reversesTransactionId: 'exp-food-jan',
    );
    febReversal = ev('reversal-feb', 'reversal', 200000, feb(10), [
      rp('reversal-feb', 'card-ledger', LedgerDirection.debit, 200000, feb(10)),
      rp(
        'reversal-feb',
        'expense:$shopping',
        LedgerDirection.credit,
        200000,
        feb(10),
      ),
    ], reversesTransactionId: 'exp-card-jan');
    febCatAdjustment = ev(
      'adj-cat-feb',
      'adjustment',
      10000,
      feb(15),
      [
        rp(
          'adj-cat-feb',
          'bank-ledger',
          LedgerDirection.credit,
          10000,
          feb(15),
        ),
        rp(
          'adj-cat-feb',
          'expense:$food',
          LedgerDirection.debit,
          10000,
          feb(15),
        ),
      ],
      categoryId: food,
      adjustmentReason: adjustmentReasonFeeCorrection,
    );
    febUncatAdjustment = ev('adj-uncat-feb', 'adjustment', 5000, feb(18), [
      rp('adj-uncat-feb', 'bank-ledger', LedgerDirection.debit, 5000, feb(18)),
      rp(
        'adj-uncat-feb',
        adjustmentsLedgerId,
        LedgerDirection.credit,
        5000,
        feb(18),
      ),
    ], adjustmentReason: adjustmentReasonBalanceCorrection);
  }

  List<ReportingEvent> get january => [
    opening,
    janFoodExpense,
    janCardPurchase,
    janTransfer,
    janCardPayment,
  ];

  List<ReportingEvent> get february => [
    febRefund,
    febReversal,
    febCatAdjustment,
    febUncatAdjustment,
  ];

  List<ReportingPosting> postingsOf(List<ReportingEvent> events) =>
      events.expand((e) => e.postings).toList();
}

void main() {
  group('approved fixture', () {
    test('January totals and closing balances', () {
      final f = Fixture();
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 2, 1),
          movements: f.january,
          closing: f.postingsOf(f.january),
          current: f.postingsOf(f.january),
        ),
      );
      expect(period.incomeTotal.amountMinorUnits, 0);
      expect(period.expenseTotal.amountMinorUnits, 250000);
      expect(period.expenseByCategory[food]!.amountMinorUnits, 50000);
      expect(period.expenseByCategory[shopping]!.amountMinorUnits, 200000);
      expect(period.transferTotal.amountMinorUnits, 100000);
      expect(period.cardPaymentTotal.amountMinorUnits, 200000);
      expect(period.openingBalanceTotal.amountMinorUnits, 1000000);
      expect(period.closingBalances['bank']!.amountMinorUnits, 650000);
      expect(period.closingBalances['cash']!.amountMinorUnits, 100000);
      expect(period.closingBalances['card']!.amountMinorUnits, 0);
      expect(period.currentBalances, period.closingBalances);
    });

    test('February totals and closing balances, card owed -200000 (C4)', () {
      final f = Fixture();
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 2, 1),
          end: DateTime.utc(2026, 3, 1),
          movements: f.february,
          closing: f.postingsOf([...f.january, ...f.february]),
          current: f.postingsOf([...f.january, ...f.february]),
          contexts: {'exp-card-jan': contextFor(f.janCardPurchase)},
        ),
      );
      expect(period.incomeTotal.amountMinorUnits, 0);
      expect(period.expenseTotal.amountMinorUnits, -210000);
      expect(period.expenseByCategory[food]!.amountMinorUnits, -10000);
      expect(period.expenseByCategory[shopping]!.amountMinorUnits, -200000);
      expect(period.balanceCorrectionEffect.amountMinorUnits, 5000);
      expect(period.openingCorrectionEffect.amountMinorUnits, 0);
      expect(period.feeCorrectionEffect.amountMinorUnits, 0);
      expect(period.otherAdjustmentEffect.amountMinorUnits, 0);
      expect(period.transferTotal.amountMinorUnits, 0);
      expect(period.cardPaymentTotal.amountMinorUnits, 0);
      expect(period.closingBalances['bank']!.amountMinorUnits, 665000);
      expect(period.closingBalances['cash']!.amountMinorUnits, 100000);
      // The card ledger's natural balance: purchase 200000 credit,
      // payment 200000 debit, reversal 200000 debit -> -200000 owed.
      expect(period.closingBalances['card']!.amountMinorUnits, -200000);
      expect(period.currentBalances, period.closingBalances);
      final details = {
        for (final d in period.adjustmentDetails)
          '${d.reason}|${d.categoryId}|${d.side}': d.amount.amountMinorUnits,
      };
      expect(details['fee_correction|$food|ReportingKind.expense'], 10000);
      expect(details['balance_correction|null|null'], 5000);
    });

    test(
      'current balances include March activity; closing balances do not',
      () {
        final f = Fixture();
        final marchExpense = ev('exp-food-mar', 'expense', 30000, mar(5), [
          rp(
            'exp-food-mar',
            'expense:$food',
            LedgerDirection.debit,
            30000,
            mar(5),
          ),
          rp(
            'exp-food-mar',
            'bank-ledger',
            LedgerDirection.credit,
            30000,
            mar(5),
          ),
        ], categoryId: food);
        final period = computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 3, 1),
            movements: f.february,
            closing: f.postingsOf([...f.january, ...f.february]),
            current: f.postingsOf([...f.january, ...f.february, marchExpense]),
            contexts: {'exp-card-jan': contextFor(f.janCardPurchase)},
          ),
        );
        expect(period.closingBalances['bank']!.amountMinorUnits, 665000);
        expect(period.currentBalances['bank']!.amountMinorUnits, 635000);
        expect(period.expenseTotal.amountMinorUnits, -210000);
      },
    );
  });

  group('reversals by original kind', () {
    ReportingEvent mirror(String uuid, ReportingEvent original, DateTime at) {
      return ev(
        uuid,
        'reversal',
        original.amountMinorUnits,
        at,
        original.postings
            .map(
              (p) => rp(
                uuid,
                p.ledgerAccountId,
                p.direction.opposite,
                p.amountMinorUnits,
                at,
              ),
            )
            .toList(),
        reversesTransactionId: original.transactionUuid,
      );
    }

    test('March reversal of a February uncategorised fee correction', () {
      final original = ev('fee-feb', 'adjustment', 7500, feb(10), [
        rp('fee-feb', 'bank-ledger', LedgerDirection.credit, 7500, feb(10)),
        rp(
          'fee-feb',
          adjustmentsLedgerId,
          LedgerDirection.debit,
          7500,
          feb(10),
        ),
      ], adjustmentReason: adjustmentReasonFeeCorrection);
      final reversal = mirror('fee-rev-mar', original, mar(5));
      final febPeriod = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 2, 1),
          end: DateTime.utc(2026, 3, 1),
          movements: [original],
          closing: original.postings,
          current: [...original.postings, ...reversal.postings],
        ),
      );
      expect(febPeriod.feeCorrectionEffect.amountMinorUnits, -7500);
      final marPeriod = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 3, 1),
          end: DateTime.utc(2026, 4, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'fee-feb': contextFor(original)},
        ),
      );
      expect(marPeriod.feeCorrectionEffect.amountMinorUnits, 7500);
    });

    test('March reversal of a February uncategorised other adjustment', () {
      final original = ev('other-feb', 'adjustment', 9000, feb(10), [
        rp('other-feb', 'bank-ledger', LedgerDirection.debit, 9000, feb(10)),
        rp(
          'other-feb',
          adjustmentsLedgerId,
          LedgerDirection.credit,
          9000,
          feb(10),
        ),
      ], adjustmentReason: adjustmentReasonOther);
      final reversal = mirror('other-rev-mar', original, mar(5));
      final marPeriod = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 3, 1),
          end: DateTime.utc(2026, 4, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'other-feb': contextFor(original)},
        ),
      );
      expect(marPeriod.otherAdjustmentEffect.amountMinorUnits, -9000);
    });

    test('reversal of a categorised adjustment outside the period', () {
      final original = ev(
        'adj-cat-feb',
        'adjustment',
        10000,
        feb(15),
        [
          rp(
            'adj-cat-feb',
            'bank-ledger',
            LedgerDirection.credit,
            10000,
            feb(15),
          ),
          rp(
            'adj-cat-feb',
            'expense:$food',
            LedgerDirection.debit,
            10000,
            feb(15),
          ),
        ],
        categoryId: food,
        adjustmentReason: adjustmentReasonFeeCorrection,
      );
      final reversal = mirror('adj-rev-mar', original, mar(5));
      final marPeriod = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 3, 1),
          end: DateTime.utc(2026, 4, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'adj-cat-feb': contextFor(original)},
        ),
      );
      expect(marPeriod.expenseByCategory[food]!.amountMinorUnits, -10000);
      expect(marPeriod.expenseTotal.amountMinorUnits, -10000);
    });

    test('reversal of an opening-balance correction', () {
      final original = ev('opencorr-feb', 'adjustment', 30000, feb(10), [
        rp(
          'opencorr-feb',
          'bank-ledger',
          LedgerDirection.debit,
          30000,
          feb(10),
        ),
        rp(
          'opencorr-feb',
          openingEquityLedgerId,
          LedgerDirection.credit,
          30000,
          feb(10),
        ),
      ], adjustmentReason: adjustmentReasonOpeningCorrection);
      final reversal = mirror('opencorr-rev-mar', original, mar(5));
      final marPeriod = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 3, 1),
          end: DateTime.utc(2026, 4, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'opencorr-feb': contextFor(original)},
        ),
      );
      expect(marPeriod.openingCorrectionEffect.amountMinorUnits, -30000);
      expect(marPeriod.incomeTotal.amountMinorUnits, 0);
      expect(marPeriod.expenseTotal.amountMinorUnits, 0);
    });

    test('reversal of a transfer stays excluded from totals', () {
      final original = ev('transfer-jan', 'transfer', 100000, jan(15), [
        rp(
          'transfer-jan',
          'cash-ledger',
          LedgerDirection.debit,
          100000,
          jan(15),
        ),
        rp(
          'transfer-jan',
          'bank-ledger',
          LedgerDirection.credit,
          100000,
          jan(15),
        ),
      ]);
      final reversal = mirror('transfer-rev-feb', original, feb(5));
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 2, 1),
          end: DateTime.utc(2026, 3, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'transfer-jan': contextFor(original)},
        ),
      );
      expect(period.transferTotal.amountMinorUnits, 0);
      expect(period.incomeTotal.amountMinorUnits, 0);
      expect(period.expenseTotal.amountMinorUnits, 0);
      expect(period.closingBalances['bank']!.amountMinorUnits, 0);
      expect(period.closingBalances['cash']!.amountMinorUnits, 0);
    });

    test('reversal of a card payment stays excluded from totals', () {
      final original = ev('cardpay-jan', 'card_payment', 200000, jan(20), [
        rp(
          'cardpay-jan',
          'card-ledger',
          LedgerDirection.debit,
          200000,
          jan(20),
        ),
        rp(
          'cardpay-jan',
          'bank-ledger',
          LedgerDirection.credit,
          200000,
          jan(20),
        ),
      ]);
      final reversal = mirror('cardpay-rev-feb', original, feb(5));
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 2, 1),
          end: DateTime.utc(2026, 3, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'cardpay-jan': contextFor(original)},
        ),
      );
      expect(period.cardPaymentTotal.amountMinorUnits, 0);
      expect(period.incomeTotal.amountMinorUnits, 0);
      expect(period.expenseTotal.amountMinorUnits, 0);
    });

    test('reversal of an opening balance contributes nothing to totals', () {
      final original = ev('opening', 'opening_balance', 1000000, jan(1), [
        rp('opening', 'bank-ledger', LedgerDirection.debit, 1000000, jan(1)),
        rp(
          'opening',
          openingEquityLedgerId,
          LedgerDirection.credit,
          1000000,
          jan(1),
        ),
      ]);
      final reversal = mirror('opening-rev-feb', original, feb(5));
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 2, 1),
          end: DateTime.utc(2026, 3, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'opening': contextFor(original)},
        ),
      );
      expect(period.openingBalanceTotal.amountMinorUnits, 0);
      expect(period.closingBalances['bank']!.amountMinorUnits, 0);
    });

    test('reversal of income negates income in the reversal period', () {
      final original = ev('income-feb', 'income', 150000, feb(10), [
        rp('income-feb', 'bank-ledger', LedgerDirection.debit, 150000, feb(10)),
        rp(
          'income-feb',
          'income:$salary',
          LedgerDirection.credit,
          150000,
          feb(10),
        ),
      ], categoryId: salary);
      final reversal = mirror('income-rev-mar', original, mar(5));
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 3, 1),
          end: DateTime.utc(2026, 4, 1),
          movements: [reversal],
          closing: [...original.postings, ...reversal.postings],
          current: [...original.postings, ...reversal.postings],
          contexts: {'income-feb': contextFor(original)},
        ),
      );
      expect(period.incomeTotal.amountMinorUnits, -150000);
      expect(period.incomeByCategory[salary]!.amountMinorUnits, -150000);
    });
  });

  group('refunds', () {
    test('refund nets against its category in the same period', () {
      final expense = ev('exp', 'expense', 50000, jan(10), [
        rp('exp', 'expense:$food', LedgerDirection.debit, 50000, jan(10)),
        rp('exp', 'bank-ledger', LedgerDirection.credit, 50000, jan(10)),
      ], categoryId: food);
      final refund = ev(
        'refund',
        'refund',
        20000,
        jan(20),
        [
          rp('refund', 'bank-ledger', LedgerDirection.debit, 20000, jan(20)),
          rp('refund', 'expense:$food', LedgerDirection.credit, 20000, jan(20)),
        ],
        categoryId: food,
        reversesTransactionId: 'exp',
      );
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 2, 1),
          movements: [expense, refund],
          closing: [...expense.postings, ...refund.postings],
          current: [...expense.postings, ...refund.postings],
        ),
      );
      expect(period.expenseTotal.amountMinorUnits, 30000);
      expect(period.closingBalances['bank']!.amountMinorUnits, -30000);
    });

    test('income refund reduces income', () {
      final income = ev('inc', 'income', 100000, jan(10), [
        rp('inc', 'bank-ledger', LedgerDirection.debit, 100000, jan(10)),
        rp('inc', 'income:$salary', LedgerDirection.credit, 100000, jan(10)),
      ], categoryId: salary);
      final refund = ev(
        'refund',
        'refund',
        30000,
        jan(20),
        [
          rp('refund', 'income:$salary', LedgerDirection.debit, 30000, jan(20)),
          rp('refund', 'bank-ledger', LedgerDirection.credit, 30000, jan(20)),
        ],
        categoryId: salary,
        reversesTransactionId: 'inc',
      );
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 2, 1),
          movements: [income, refund],
          closing: [...income.postings, ...refund.postings],
          current: [...income.postings, ...refund.postings],
        ),
      );
      expect(period.incomeTotal.amountMinorUnits, 70000);
    });
  });

  group('fail-closed validation', () {
    test('missing reversal context fails', () {
      final reversal = ev('rev', 'reversal', 50000, feb(10), [
        rp('rev', 'bank-ledger', LedgerDirection.debit, 50000, feb(10)),
        rp('rev', 'expense:$food', LedgerDirection.credit, 50000, feb(10)),
      ], reversesTransactionId: 'missing');
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 3, 1),
            movements: [reversal],
            closing: reversal.postings,
            current: reversal.postings,
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('inactive original fails', () {
      final original = ev(
        'orig',
        'expense',
        50000,
        jan(10),
        [
          rp('orig', 'expense:$food', LedgerDirection.debit, 50000, jan(10)),
          rp('orig', 'bank-ledger', LedgerDirection.credit, 50000, jan(10)),
        ],
        categoryId: food,
        status: 'deleted',
      );
      final reversal = ev('rev', 'reversal', 50000, feb(10), [
        rp('rev', 'bank-ledger', LedgerDirection.debit, 50000, feb(10)),
        rp('rev', 'expense:$food', LedgerDirection.credit, 50000, feb(10)),
      ], reversesTransactionId: 'orig');
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 3, 1),
            movements: [reversal],
            closing: reversal.postings,
            current: reversal.postings,
            contexts: {'orig': contextFor(original)},
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('non-mirror reversal postings fail', () {
      final original = ev('orig', 'expense', 50000, jan(10), [
        rp('orig', 'expense:$food', LedgerDirection.debit, 50000, jan(10)),
        rp('orig', 'bank-ledger', LedgerDirection.credit, 50000, jan(10)),
      ], categoryId: food);
      final badReversal = ev('rev', 'reversal', 50000, feb(10), [
        rp('rev', 'bank-ledger', LedgerDirection.debit, 40000, feb(10)),
        rp('rev', 'expense:$food', LedgerDirection.credit, 40000, feb(10)),
      ], reversesTransactionId: 'orig');
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 3, 1),
            movements: [badReversal],
            closing: badReversal.postings,
            current: badReversal.postings,
            contexts: {'orig': contextFor(original)},
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('reversal predating its original fails', () {
      final original = ev('orig', 'expense', 50000, feb(10), [
        rp('orig', 'expense:$food', LedgerDirection.debit, 50000, feb(10)),
        rp('orig', 'bank-ledger', LedgerDirection.credit, 50000, feb(10)),
      ], categoryId: food);
      final early = ev('rev', 'reversal', 50000, feb(5), [
        rp('rev', 'bank-ledger', LedgerDirection.debit, 50000, feb(5)),
        rp('rev', 'expense:$food', LedgerDirection.credit, 50000, feb(5)),
      ], reversesTransactionId: 'orig');
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 3, 1),
            movements: [early],
            closing: early.postings,
            current: early.postings,
            contexts: {'orig': contextFor(original)},
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('reversal of a refund fails', () {
      final refund = ev(
        'refund',
        'refund',
        20000,
        feb(5),
        [
          rp('refund', 'bank-ledger', LedgerDirection.debit, 20000, feb(5)),
          rp('refund', 'expense:$food', LedgerDirection.credit, 20000, feb(5)),
        ],
        categoryId: food,
        reversesTransactionId: 'orig',
      );
      final reversal = ev('rev', 'reversal', 20000, feb(10), [
        rp('rev', 'expense:$food', LedgerDirection.debit, 20000, feb(10)),
        rp('rev', 'bank-ledger', LedgerDirection.credit, 20000, feb(10)),
      ], reversesTransactionId: 'refund');
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 3, 1),
            movements: [reversal],
            closing: reversal.postings,
            current: reversal.postings,
            contexts: {'refund': contextFor(refund)},
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });

    test('invalid period interval fails with ArgumentError', () {
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 2, 1),
            end: DateTime.utc(2026, 2, 1),
            movements: [],
            closing: [],
            current: [],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 3, 1),
            end: DateTime.utc(2026, 2, 1),
            movements: [],
            closing: [],
            current: [],
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('deleted movement and unknown ledger fail', () {
      final deleted = ev(
        'exp',
        'expense',
        50000,
        jan(10),
        [
          rp('exp', 'expense:$food', LedgerDirection.debit, 50000, jan(10)),
          rp('exp', 'bank-ledger', LedgerDirection.credit, 50000, jan(10)),
        ],
        categoryId: food,
        status: 'deleted',
      );
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 1, 1),
            end: DateTime.utc(2026, 2, 1),
            movements: [deleted],
            closing: [],
            current: [],
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );

      final unknown = ev('exp', 'expense', 50000, jan(10), [
        rp('exp', 'expense:unknown', LedgerDirection.debit, 50000, jan(10)),
        rp('exp', 'bank-ledger', LedgerDirection.credit, 50000, jan(10)),
      ], categoryId: food);
      expect(
        () => computeReporting(
          snapshot(
            start: DateTime.utc(2026, 1, 1),
            end: DateTime.utc(2026, 2, 1),
            movements: [unknown],
            closing: [],
            current: [],
          ),
        ),
        throwsA(isA<PostingValidationException>()),
      );
    });
  });

  group('no double counting', () {
    test('original context postings are never counted a second time', () {
      final f = Fixture();
      final snap = snapshot(
        start: DateTime.utc(2026, 2, 1),
        end: DateTime.utc(2026, 3, 1),
        movements: f.february,
        closing: f.postingsOf([...f.january, ...f.february]),
        current: f.postingsOf([...f.january, ...f.february]),
        contexts: {'exp-card-jan': contextFor(f.janCardPurchase)},
      );
      final period = computeReporting(snap);
      // Independent recomputation from the closing posting set alone.
      const calculator = BalanceCalculator();
      final bankPostings = snap.closingPostings
          .where((p) => p.ledgerAccountId == 'bank-ledger')
          .map(
            (p) => BalancePosting(
              ledgerAccountId: p.ledgerAccountId,
              direction: p.direction,
              amountMinorUnits: p.amountMinorUnits,
              currencyCode: p.currencyCode,
              normalBalance: LedgerDirection.debit,
            ),
          );
      final direct = calculator.balanceForLedger(
        bankPostings,
        ledgerAccountId: 'bank-ledger',
        normalBalance: LedgerDirection.debit,
        currencyCode: 'INR',
      );
      expect(period.closingBalances['bank'], direct);
      expect(
        snap.movements.map((e) => e.transactionUuid),
        isNot(contains('exp-card-jan')),
      );
    });

    test('accounts with no postings appear with zero balances', () {
      final period = computeReporting(
        snapshot(
          start: DateTime.utc(2026, 1, 1),
          end: DateTime.utc(2026, 2, 1),
          movements: [],
          closing: [],
          current: [],
        ),
      );
      expect(period.closingBalances['bank'], Money.zero('INR'));
      expect(period.closingBalances['cash'], Money.zero('INR'));
      expect(period.closingBalances['card'], Money.zero('INR'));
      expect(period.incomeTotal, Money.zero('INR'));
    });
  });
}
