// Ledger balance calculation (blueprint sections 6.3 and 6.4).
//
// Pure: no Drift, no Flutter, no Sheets imports. The balance of a
// ledger account is the signed sum of its postings on its normal
// balance side minus the opposite side. This is the ONE balance
// implementation used by reporting for closing balances, current
// balances, and (through reporting) every future consumer. No second
// balance fold may be introduced elsewhere.
//
// Accumulation reuses [Money] arithmetic, which uses BigInt
// intermediates and throws [StateError] when a result cannot be
// represented as a signed 64-bit integer (design decision D5), instead
// of silently wrapping. Currency mismatches throw [ArgumentError]
// through [Money]; inconsistent normal-balance or currency metadata
// within one ledger group fails closed with
// [PostingValidationException].

import '../money.dart';
import 'posting_rules.dart';

/// One posting as seen by the balance calculator: the fields needed
/// to sign its amount. Callers (reporting snapshot construction)
/// supply the ledger's normal balance; this calculator never looks
/// it up itself.
class BalancePosting {
  const BalancePosting({
    required this.ledgerAccountId,
    required this.direction,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.normalBalance,
  });

  final String ledgerAccountId;
  final LedgerDirection direction;
  final int amountMinorUnits;
  final String currencyCode;
  final LedgerDirection normalBalance;
}

/// The canonical balance calculator for the V2 ledger.
class BalanceCalculator {
  const BalanceCalculator();

  /// Returns the natural ledger balance for one ledger account:
  /// postings on the normal side count positive, opposite-side
  /// postings count negative. For a liability ledger this is the
  /// amount owed (positive means owed, negative means a credit
  /// balance); for an asset ledger it is the funds held. No sign
  /// transformation is applied here or anywhere else: the natural
  /// balance IS the user-facing account balance (corrected design,
  /// C4).
  ///
  /// [postings] must all belong to [ledgerAccountId], share
  /// [currencyCode], and agree on [normalBalance]. An empty input
  /// returns zero. Throws [StateError] on signed 64-bit overflow.
  Money balanceForLedger(
    Iterable<BalancePosting> postings, {
    required String ledgerAccountId,
    required LedgerDirection normalBalance,
    required String currencyCode,
  }) {
    var total = Money.zero(currencyCode);
    for (final posting in postings) {
      if (posting.ledgerAccountId != ledgerAccountId) {
        throw PostingValidationException(
          'Posting for ${posting.ledgerAccountId} cannot contribute '
          'to the balance of $ledgerAccountId.',
        );
      }
      if (posting.currencyCode != currencyCode) {
        throw PostingValidationException(
          'Posting currency ${posting.currencyCode} does not match '
          'the balance currency $currencyCode for $ledgerAccountId.',
        );
      }
      if (posting.normalBalance != normalBalance) {
        throw const PostingValidationException(
          'Inconsistent normal-balance metadata within one ledger.',
        );
      }
      if (posting.amountMinorUnits <= 0) {
        throw const PostingValidationException(
          'Balance postings must carry strictly positive amounts.',
        );
      }
      final signed = posting.direction == normalBalance
          ? Money(posting.amountMinorUnits, currencyCode)
          : -Money(posting.amountMinorUnits, currencyCode);
      total = total + signed;
    }
    return total;
  }

  /// Returns natural balances for every ledger account represented
  /// in [postings], keyed by ledger account id. Groups must be
  /// internally consistent (one currency and one normal balance per
  /// ledger); inconsistency fails closed. Ledgers with no postings
  /// do not appear in the result: callers that need explicit zeroes
  /// (reporting) add them from the known ledger set.
  Map<String, Money> balancesByLedger(Iterable<BalancePosting> postings) {
    final grouped = <String, List<BalancePosting>>{};
    for (final posting in postings) {
      (grouped[posting.ledgerAccountId] ??= <BalancePosting>[]).add(posting);
    }
    final result = <String, Money>{};
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      result[entry.key] = balanceForLedger(
        entry.value,
        ledgerAccountId: entry.key,
        normalBalance: first.normalBalance,
        currencyCode: first.currencyCode,
      );
    }
    return result;
  }
}
