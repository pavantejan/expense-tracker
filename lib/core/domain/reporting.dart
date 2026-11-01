// Canonical reporting layer (blueprint sections 6.3-6.6; corrected
// Stage 2 design, C2/C4, D1/D2, and the final reporting refinements).
//
// This is the ONE reporting implementation. Dashboards, monthly/yearly
// summaries, and analytics all consume its output; no ad-hoc folds
// may be introduced elsewhere (verified by grep in Stage 6).
//
// Three outputs, kept separate by construction:
// * period movements (income, expense, category, and adjustment
//   effects) come only from postings inside the reporting period;
// * closing account balances come from all active postings with
//   occurredAt before the period end;
// * current account balances come from all active postings.
// All three are derived from one [ReportingSnapshot] whose loading
// strategy lives in the financial-transaction repository. This layer
// is period-agnostic except for period validation: it sums exactly
// the postings it is given, through [BalanceCalculator], and never
// re-derives a period filter itself.
//
// Reversals are classified only through [ReversalContext]: the
// reversal row carries no adjustment reason or original metadata, so
// the snapshot must resolve the original transaction (batched, any
// period) and this layer validates the mirror before negating the
// original's contribution in the reversal's own period. Original
// context postings are metadata only and are never counted again.

import 'ledger/balance_calculator.dart';
import 'ledger/posting_rules.dart';
import 'money.dart';

/// One posting as seen by reporting: direction and amount plus the
/// transaction date it inherits (used for audit, never for filtering
/// inside this layer).
class ReportingPosting {
  const ReportingPosting({
    required this.transactionUuid,
    required this.ledgerAccountId,
    required this.direction,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredAt,
  });

  final String transactionUuid;
  final String ledgerAccountId;
  final LedgerDirection direction;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime occurredAt;
}

/// One business event with its complete postings, as loaded for the
/// reporting period. Only events with `status == 'active'` may
/// appear here; snapshot construction enforces that boundary.
class ReportingEvent {
  const ReportingEvent({
    required this.transactionUuid,
    required this.kind,
    required this.categoryId,
    required this.adjustmentReason,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.occurredAt,
    required this.status,
    required this.reversesTransactionId,
    required this.postings,
  });

  final String transactionUuid;
  final String kind;
  final String? categoryId;
  final String? adjustmentReason;
  final int amountMinorUnits;
  final String currencyCode;
  final DateTime occurredAt;
  final String status;
  final String? reversesTransactionId;
  final List<ReportingPosting> postings;
}

/// The original transaction behind a reversal, resolved from
/// `reversesTransactionId` regardless of whether the original lies
/// inside or outside the reporting period.
///
/// Used ONLY to classify the reversal and to validate its mirror.
/// Its postings must never be added to any movement or balance set a
/// second time: balances already include the original's postings
/// exactly once through the normal closing/current loads.
class ReversalContext {
  const ReversalContext({
    required this.originalTransactionUuid,
    required this.originalKind,
    required this.originalAdjustmentReason,
    required this.originalCategoryId,
    required this.originalOccurredAt,
    required this.originalStatus,
    required this.originalAmountMinorUnits,
    required this.originalCurrencyCode,
    required this.originalPostings,
  });

  final String originalTransactionUuid;
  final String originalKind;
  final String? originalAdjustmentReason;
  final String? originalCategoryId;
  final DateTime originalOccurredAt;
  final String originalStatus;
  final int originalAmountMinorUnits;
  final String originalCurrencyCode;
  final List<ReportingPosting> originalPostings;
}

/// Everything reporting needs, loaded once by the repository inside
/// one read transaction: period movements, closing and current
/// posting sets, the ledger map, and reversal contexts. Snapshot
/// types carry no `status` field for balance sets (active-only is
/// enforced by the loader predicates) and no period logic beyond
/// the interval itself.
class ReportingSnapshot {
  const ReportingSnapshot({
    required this.periodStart,
    required this.periodEndExclusive,
    required this.movements,
    required this.closingPostings,
    required this.currentPostings,
    required this.ledgerAccounts,
    required this.reversalContexts,
  });

  final DateTime periodStart;
  final DateTime periodEndExclusive;
  final List<ReportingEvent> movements;
  final List<ReportingPosting> closingPostings;
  final List<ReportingPosting> currentPostings;

  /// All ledger accounts, keyed by ledger account id. Archival is
  /// not filtered here: archived ledgers keep their history.
  final Map<String, LedgerDescriptor> ledgerAccounts;

  /// Reversal contexts keyed by original transaction uuid.
  final Map<String, ReversalContext> reversalContexts;
}

/// One adjustment effect, aggregated by reason (and category when
/// categorised). Scalar buckets on [ReportingPeriod] hold the totals;
/// this detail preserves the reason and category attribution (D2).
class AdjustmentEffectDetail {
  const AdjustmentEffectDetail({
    required this.reason,
    required this.categoryId,
    required this.side,
    required this.amount,
  });

  final String reason;
  final String? categoryId;

  /// `expense` or `income` for categorised effects, null for
  /// uncategorised effects against the system ledgers.
  final ReportingKind? side;
  final Money amount;
}

/// The computed reporting output for one period.
class ReportingPeriod {
  const ReportingPeriod({
    required this.periodStart,
    required this.periodEndExclusive,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.incomeByCategory,
    required this.expenseByCategory,
    required this.balanceCorrectionEffect,
    required this.openingCorrectionEffect,
    required this.feeCorrectionEffect,
    required this.otherAdjustmentEffect,
    required this.adjustmentDetails,
    required this.closingBalances,
    required this.currentBalances,
    required this.transferTotal,
    required this.cardPaymentTotal,
    required this.openingBalanceTotal,
  });

  final DateTime periodStart;
  final DateTime periodEndExclusive;

  /// Period movements only: never lifetime totals.
  final Money incomeTotal;
  final Money expenseTotal;
  final Map<String, Money> incomeByCategory;
  final Map<String, Money> expenseByCategory;

  /// Signed account-balance effects of uncategorised adjustments,
  /// by reason (D1). Categorised adjustments contribute to the
  /// category buckets instead and appear in [adjustmentDetails].
  final Money balanceCorrectionEffect;
  final Money openingCorrectionEffect;
  final Money feeCorrectionEffect;
  final Money otherAdjustmentEffect;
  final List<AdjustmentEffectDetail> adjustmentDetails;

  /// Account balances keyed by account uuid (resolved through
  /// `LedgerAccounts.userAccountId`). Closing balances cover history
  /// through the period end; current balances cover all active
  /// postings. Both include every known user account, with zero
  /// where the account has no postings in the set.
  final Map<String, Money> closingBalances;
  final Map<String, Money> currentBalances;

  /// Excluded-from-income/expense transparency totals for the
  /// period (absolute movement amounts). These never feed
  /// [incomeTotal] or [expenseTotal].
  final Money transferTotal;
  final Money cardPaymentTotal;
  final Money openingBalanceTotal;
}

/// Validates every reversal in [snapshot] against its
/// [ReversalContext]: the context must exist, the original must be
/// active, the original kind must support reversal, the reversal
/// must not predate the original, and the reversal postings must be
/// the exact mirror of the original postings. Throws
/// [PostingValidationException] on any failure; reports fail closed
/// rather than classifying a reversal by guesswork.
void validateReversalContexts(ReportingSnapshot snapshot) {
  for (final event in snapshot.movements) {
    if (event.kind != 'reversal') {
      continue;
    }
    final originalUuid = event.reversesTransactionId;
    if (originalUuid == null || originalUuid.isEmpty) {
      throw const PostingValidationException(
        'A reversal transaction must set reversesTransactionId.',
      );
    }
    final context = snapshot.reversalContexts[originalUuid];
    if (context == null) {
      throw PostingValidationException(
        'Missing ReversalContext for original $originalUuid.',
      );
    }
    if (context.originalStatus != 'active') {
      throw PostingValidationException(
        'Reversal of $originalUuid references an original with '
        'status ${context.originalStatus}; the original must be active.',
      );
    }
    if (context.originalKind == 'refund' ||
        context.originalKind == 'reversal') {
      throw PostingValidationException(
        'A ${context.originalKind} transaction cannot be reversed.',
      );
    }
    if (event.occurredAt.isBefore(context.originalOccurredAt)) {
      throw const PostingValidationException(
        'A reversal must not predate its original transaction.',
      );
    }
    if (event.amountMinorUnits != context.originalAmountMinorUnits) {
      throw const PostingValidationException(
        'A reversal amount must equal the original amount exactly.',
      );
    }
    if (event.currencyCode != context.originalCurrencyCode) {
      throw const PostingValidationException(
        'A reversal currency must equal the original currency.',
      );
    }
    final expected =
        context.originalPostings
            .map(
              (posting) =>
                  '${posting.ledgerAccountId}|'
                  '${posting.direction.opposite.value}|'
                  '${posting.amountMinorUnits}',
            )
            .toList()
          ..sort();
    final actual =
        event.postings
            .map(
              (posting) =>
                  '${posting.ledgerAccountId}|'
                  '${posting.direction.value}|'
                  '${posting.amountMinorUnits}',
            )
            .toList()
          ..sort();
    if (expected.length != actual.length) {
      throw const PostingValidationException(
        'Reversal postings do not mirror the original postings.',
      );
    }
    for (var i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) {
        throw const PostingValidationException(
          'Reversal postings do not mirror the original postings.',
        );
      }
    }
  }
}

class _Contribution {
  _Contribution(this.currencyCode)
    : income = <String, Money>{},
      expense = <String, Money>{},
      adjustments = <String, Money>{},
      details = <_DetailKey, Money>{},
      transferTotal = Money.zero(currencyCode),
      cardPaymentTotal = Money.zero(currencyCode),
      openingBalanceTotal = Money.zero(currencyCode);

  final String currencyCode;
  final Map<String, Money> income;
  final Map<String, Money> expense;
  final Map<String, Money> adjustments;
  final Map<_DetailKey, Money> details;
  Money transferTotal;
  Money cardPaymentTotal;
  Money openingBalanceTotal;
}

class _DetailKey {
  const _DetailKey(this.reason, this.categoryId, this.side);

  final String reason;
  final String? categoryId;
  final ReportingKind? side;

  @override
  bool operator ==(Object other) {
    return other is _DetailKey &&
        other.reason == reason &&
        other.categoryId == categoryId &&
        other.side == side;
  }

  @override
  int get hashCode => Object.hash(reason, categoryId, side);
}

void _addMoney(Map<String, Money> map, String key, Money delta) {
  final existing = map[key];
  map[key] = existing == null ? delta : existing + delta;
}

void _addDetail(Map<_DetailKey, Money> map, _DetailKey key, Money delta) {
  final existing = map[key];
  map[key] = existing == null ? delta : existing + delta;
}

Money _signedEffect(
  ReportingPosting posting,
  LedgerDescriptor ledger,
  String currencyCode,
) {
  final amount = Money(posting.amountMinorUnits, currencyCode);
  return posting.direction == ledger.normalBalance ? amount : -amount;
}

/// Computes the movement contribution of one non-reversal event from
/// its postings and the ledger map. Category effects come from the
/// signed normal-balance change of category-ledger postings;
/// uncategorised adjustments contribute the signed account-side
/// effect to their reason bucket; transfers, card payments, and
/// opening balances contribute nothing to income/expense.
_Contribution _contributionForEvent(
  ReportingEvent event,
  Map<String, LedgerDescriptor> ledgers,
  String currencyCode,
) {
  final contribution = _Contribution(currencyCode);
  contribution.transferTotal = Money.zero(currencyCode);
  contribution.cardPaymentTotal = Money.zero(currencyCode);
  contribution.openingBalanceTotal = Money.zero(currencyCode);
  switch (event.kind) {
    case 'transfer':
      contribution.transferTotal = Money(event.amountMinorUnits, currencyCode);
      return contribution;
    case 'card_payment':
      contribution.cardPaymentTotal = Money(
        event.amountMinorUnits,
        currencyCode,
      );
      return contribution;
    case 'opening_balance':
      contribution.openingBalanceTotal = Money(
        event.amountMinorUnits,
        currencyCode,
      );
      return contribution;
    case 'reversal':
      throw const PostingValidationException(
        'Reversal contributions must be computed from their '
        'ReversalContext, never directly.',
      );
  }
  if (event.kind == 'refund' && event.reversesTransactionId == null) {
    throw const PostingValidationException(
      'A refund transaction must set reversesTransactionId.',
    );
  }
  var hasCategoryPosting = false;
  for (final posting in event.postings) {
    final ledger = ledgers[posting.ledgerAccountId];
    if (ledger == null) {
      throw PostingValidationException(
        'Unknown ledger account: ${posting.ledgerAccountId}.',
      );
    }
    if (!ledger.isCategoryLedger) {
      continue;
    }
    hasCategoryPosting = true;
    if (event.categoryId != null && ledger.categoryId != event.categoryId) {
      throw const PostingValidationException(
        'A transaction categoryId must agree with its category '
        'ledger account.',
      );
    }
    final effect = _signedEffect(posting, ledger, currencyCode);
    if (ledger.kind == ledgerKindSystemExpense) {
      if (event.kind == 'income') {
        throw const PostingValidationException(
          'An income transaction must not post to an expense ledger.',
        );
      }
      _addMoney(contribution.expense, ledger.categoryId!, effect);
    } else {
      if (event.kind == 'expense') {
        throw const PostingValidationException(
          'An expense transaction must not post to an income ledger.',
        );
      }
      _addMoney(contribution.income, ledger.categoryId!, effect);
    }
    if (event.kind == 'adjustment') {
      final side = ledger.kind == ledgerKindSystemExpense
          ? ReportingKind.expense
          : ReportingKind.income;
      _addDetail(
        contribution.details,
        _DetailKey(event.adjustmentReason!, ledger.categoryId, side),
        effect,
      );
    }
  }
  if (event.kind == 'adjustment' && !hasCategoryPosting) {
    final reason = event.adjustmentReason;
    if (reason == null || !isAdjustmentReason(reason)) {
      throw PostingValidationException(
        'An adjustment transaction requires a recognised '
        'adjustmentReason.',
      );
    }
    // Uncategorised: the bucket value is the signed account-side
    // effect (the user ledger posting), never the counterpart side.
    var accountEffect = Money.zero(currencyCode);
    var foundAccountPosting = false;
    for (final posting in event.postings) {
      final ledger = ledgers[posting.ledgerAccountId]!;
      if (!ledger.isUserLedger) {
        continue;
      }
      foundAccountPosting = true;
      accountEffect =
          accountEffect + _signedEffect(posting, ledger, currencyCode);
    }
    if (!foundAccountPosting) {
      throw const PostingValidationException(
        'An uncategorised adjustment requires a user account posting.',
      );
    }
    _addMoney(contribution.adjustments, reason, accountEffect);
    _addDetail(
      contribution.details,
      _DetailKey(reason, null, null),
      accountEffect,
    );
  }
  if ((event.kind == 'expense' || event.kind == 'income') &&
      !hasCategoryPosting) {
    throw PostingValidationException(
      'An ${event.kind} transaction requires a category ledger posting.',
    );
  }
  return contribution;
}

_Contribution _negated(_Contribution contribution) {
  final negated = _Contribution(contribution.currencyCode);
  negated.transferTotal = Money.zero(contribution.currencyCode);
  negated.cardPaymentTotal = Money.zero(contribution.currencyCode);
  negated.openingBalanceTotal = Money.zero(contribution.currencyCode);
  for (final entry in contribution.income.entries) {
    negated.income[entry.key] = -entry.value;
  }
  for (final entry in contribution.expense.entries) {
    negated.expense[entry.key] = -entry.value;
  }
  for (final entry in contribution.adjustments.entries) {
    negated.adjustments[entry.key] = -entry.value;
  }
  for (final entry in contribution.details.entries) {
    negated.details[entry.key] = -entry.value;
  }
  return negated;
}

_Contribution _reversalContribution(
  ReportingEvent event,
  ReportingSnapshot snapshot,
  String currencyCode,
) {
  final context = snapshot.reversalContexts[event.reversesTransactionId]!;
  if (context.originalKind == 'transfer' ||
      context.originalKind == 'card_payment' ||
      context.originalKind == 'opening_balance') {
    // Excluded kinds stay excluded when reversed: no income/expense
    // effect in either period.
    final empty = _Contribution(currencyCode);
    empty.transferTotal = Money.zero(currencyCode);
    empty.cardPaymentTotal = Money.zero(currencyCode);
    empty.openingBalanceTotal = Money.zero(currencyCode);
    return empty;
  }
  final originalEvent = ReportingEvent(
    transactionUuid: context.originalTransactionUuid,
    kind: context.originalKind,
    categoryId: context.originalCategoryId,
    adjustmentReason: context.originalAdjustmentReason,
    amountMinorUnits: context.originalAmountMinorUnits,
    currencyCode: context.originalCurrencyCode,
    occurredAt: context.originalOccurredAt,
    status: context.originalStatus,
    reversesTransactionId: null,
    postings: context.originalPostings,
  );
  final originalContribution = _contributionForEvent(
    originalEvent,
    snapshot.ledgerAccounts,
    currencyCode,
  );
  return _negated(originalContribution);
}

/// Computes [ReportingPeriod] output from [snapshot].
///
/// Validates the period interval ([ArgumentError] unless
/// `periodStart < periodEndExclusive`), the single-currency rule,
/// active-only movements, ledger existence, and every reversal
/// context (see [validateReversalContexts]) before summing anything.
/// Balance sets are summed only through [BalanceCalculator].
ReportingPeriod computeReporting(ReportingSnapshot snapshot) {
  if (!snapshot.periodStart.isBefore(snapshot.periodEndExclusive)) {
    throw ArgumentError(
      'Reporting period requires periodStart < periodEndExclusive: '
      '${snapshot.periodStart} to ${snapshot.periodEndExclusive}.',
    );
  }
  // Single currency across every posting the snapshot carries.
  final currencies = <String>{};
  void collectCurrency(ReportingPosting posting) {
    currencies.add(posting.currencyCode);
  }

  for (final event in snapshot.movements) {
    if (event.status != 'active') {
      throw const PostingValidationException(
        'Reporting movements must contain only active transactions.',
      );
    }
    for (final posting in event.postings) {
      collectCurrency(posting);
    }
  }
  for (final posting in snapshot.closingPostings) {
    collectCurrency(posting);
  }
  for (final posting in snapshot.currentPostings) {
    collectCurrency(posting);
  }
  for (final context in snapshot.reversalContexts.values) {
    for (final posting in context.originalPostings) {
      collectCurrency(posting);
    }
  }
  if (currencies.length > 1) {
    throw const PostingValidationException(
      'Reporting snapshots must carry a single currency.',
    );
  }
  final currencyCode = currencies.isEmpty ? 'INR' : currencies.single;

  for (final event in snapshot.movements) {
    for (final posting in event.postings) {
      if (posting.amountMinorUnits <= 0) {
        throw const PostingValidationException(
          'Reporting postings must carry strictly positive amounts.',
        );
      }
      if (!snapshot.ledgerAccounts.containsKey(posting.ledgerAccountId)) {
        throw PostingValidationException(
          'Unknown ledger account: ${posting.ledgerAccountId}.',
        );
      }
    }
  }
  validateReversalContexts(snapshot);

  final incomeByCategory = <String, Money>{};
  final expenseByCategory = <String, Money>{};
  final adjustments = <String, Money>{};
  final details = <_DetailKey, Money>{};
  var transferTotal = Money.zero(currencyCode);
  var cardPaymentTotal = Money.zero(currencyCode);
  var openingBalanceTotal = Money.zero(currencyCode);
  for (final event in snapshot.movements) {
    final contribution = event.kind == 'reversal'
        ? _reversalContribution(event, snapshot, currencyCode)
        : _contributionForEvent(event, snapshot.ledgerAccounts, currencyCode);
    for (final entry in contribution.income.entries) {
      _addMoney(incomeByCategory, entry.key, entry.value);
    }
    for (final entry in contribution.expense.entries) {
      _addMoney(expenseByCategory, entry.key, entry.value);
    }
    for (final entry in contribution.adjustments.entries) {
      _addMoney(adjustments, entry.key, entry.value);
    }
    for (final entry in contribution.details.entries) {
      _addDetail(details, entry.key, entry.value);
    }
    transferTotal = transferTotal + contribution.transferTotal;
    cardPaymentTotal = cardPaymentTotal + contribution.cardPaymentTotal;
    openingBalanceTotal =
        openingBalanceTotal + contribution.openingBalanceTotal;
  }
  Money incomeTotal = Money.zero(currencyCode);
  for (final value in incomeByCategory.values) {
    incomeTotal = incomeTotal + value;
  }
  Money expenseTotal = Money.zero(currencyCode);
  for (final value in expenseByCategory.values) {
    expenseTotal = expenseTotal + value;
  }

  const calculator = BalanceCalculator();
  Map<String, Money> accountBalances(List<ReportingPosting> postings) {
    final balancePostings = postings.map((posting) {
      final ledger = snapshot.ledgerAccounts[posting.ledgerAccountId];
      if (ledger == null) {
        throw PostingValidationException(
          'Unknown ledger account: ${posting.ledgerAccountId}.',
        );
      }
      return BalancePosting(
        ledgerAccountId: posting.ledgerAccountId,
        direction: posting.direction,
        amountMinorUnits: posting.amountMinorUnits,
        currencyCode: posting.currencyCode,
        normalBalance: ledger.normalBalance,
      );
    }).toList();
    final byLedger = calculator.balancesByLedger(balancePostings);
    final result = <String, Money>{};
    for (final ledger in snapshot.ledgerAccounts.values) {
      final accountUuid = ledger.userAccountId;
      if (accountUuid == null) {
        continue;
      }
      result[accountUuid] =
          byLedger[ledger.ledgerAccountId] ?? Money.zero(currencyCode);
    }
    return result;
  }

  final adjustmentDetails =
      details.entries
          .map(
            (entry) => AdjustmentEffectDetail(
              reason: entry.key.reason,
              categoryId: entry.key.categoryId,
              side: entry.key.side,
              amount: entry.value,
            ),
          )
          .toList()
        ..sort((a, b) {
          final byReason = a.reason.compareTo(b.reason);
          if (byReason != 0) {
            return byReason;
          }
          return (a.categoryId ?? '').compareTo(b.categoryId ?? '');
        });

  return ReportingPeriod(
    periodStart: snapshot.periodStart,
    periodEndExclusive: snapshot.periodEndExclusive,
    incomeTotal: incomeTotal,
    expenseTotal: expenseTotal,
    incomeByCategory: Map<String, Money>.unmodifiable(incomeByCategory),
    expenseByCategory: Map<String, Money>.unmodifiable(expenseByCategory),
    balanceCorrectionEffect:
        adjustments[adjustmentReasonBalanceCorrection] ??
        Money.zero(currencyCode),
    openingCorrectionEffect:
        adjustments[adjustmentReasonOpeningCorrection] ??
        Money.zero(currencyCode),
    feeCorrectionEffect:
        adjustments[adjustmentReasonFeeCorrection] ?? Money.zero(currencyCode),
    otherAdjustmentEffect:
        adjustments[adjustmentReasonOther] ?? Money.zero(currencyCode),
    adjustmentDetails: List<AdjustmentEffectDetail>.unmodifiable(
      adjustmentDetails,
    ),
    closingBalances: accountBalances(snapshot.closingPostings),
    currentBalances: accountBalances(snapshot.currentPostings),
    transferTotal: transferTotal,
    cardPaymentTotal: cardPaymentTotal,
    openingBalanceTotal: openingBalanceTotal,
  );
}
