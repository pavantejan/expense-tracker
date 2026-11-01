// Posting construction and validation for the V2 double-entry ledger
// (blueprint sections 5.2, 6.3, 6.4, 6.6; ADR-005, ADR-014).
//
// This is the ONLY place that builds postings. Repositories resolve
// ledger rows and call these builders; they never construct posting
// lists by hand. Builders are pure: they take resolved ledger
// descriptors and amounts and return drafts. Database existence,
// archival state, and exactly-one-of shape are expressed through
// [LedgerDescriptor] values supplied by the caller, so the same
// validation runs identically for repository writes and for tests.
//
// Two reference modes, kept distinct on purpose (corrected design,
// C1): [ReferenceMode.newReferences] rejects archived ledger rows
// (the user selected them for a new event); [ReferenceMode.inherited]
// allows archived rows (the references were inherited from an
// existing transaction: reversal mirrors, a refund's category side,
// unchanged references on edit, restored postings). No builder ever
// creates a replacement ledger account to work around archival.

import '../money.dart';

/// Domain validation failure for posting construction.
///
/// Repositories surface this error unchanged; callers must not fall
/// back to a different classification, bucket, or posting set when it
/// is thrown.
class PostingValidationException implements Exception {
  const PostingValidationException(this.message);

  final String message;

  @override
  String toString() => 'PostingValidationException: $message';
}

/// A posting direction: `debit` or `credit`. Distinct values only;
/// sign is never carried by a negative amount.
enum LedgerDirection { debit, credit }

/// Stored string value for a [LedgerDirection].
extension LedgerDirectionValue on LedgerDirection {
  String get value => name;

  LedgerDirection get opposite => this == LedgerDirection.debit
      ? LedgerDirection.credit
      : LedgerDirection.debit;
}

/// Parses a stored direction string. Throws [PostingValidationException]
/// for any other value.
LedgerDirection ledgerDirectionFromValue(String value) {
  switch (value) {
    case 'debit':
      return LedgerDirection.debit;
    case 'credit':
      return LedgerDirection.credit;
    default:
      throw PostingValidationException('Invalid posting direction: $value.');
  }
}

/// Adjustment direction selected by the user (blueprint section 6.3).
///
/// `increase` moves the affected account's balance toward its normal
/// balance side; `decrease` moves it away from its normal balance
/// side. Amounts stay unsigned; direction lives in the postings.
enum AdjustmentDirection { increase, decrease }

/// Transient reporting side for a categorised adjustment on a `both`
/// category: which category ledger (expense or income) the adjustment
/// corrects. Never stored; reporting derives the side from the
/// counterpart ledger row afterwards.
enum ReportingKind { expense, income }

/// Whether referenced ledger rows were newly selected by the user or
/// inherited from an existing transaction (see file doc comment).
enum ReferenceMode { newReferences, inherited }

/// Ledger kinds, as stored on `LedgerAccounts.kind`.
const String ledgerKindUserAsset = 'user_asset';
const String ledgerKindUserLiability = 'user_liability';
const String ledgerKindSystemExpense = 'system_expense';
const String ledgerKindSystemIncome = 'system_income';
const String ledgerKindSystemOpeningEquity = 'system_opening_equity';
const String ledgerKindSystemAdjustment = 'system_adjustment';

/// Fixed system ledger ids (blueprint section 5.2).
const String openingEquityLedgerId = 'opening_equity';
const String adjustmentsLedgerId = 'adjustments';

/// Adjustment reasons, as stored on `FinancialTransactions.adjustmentReason`.
const String adjustmentReasonOpeningCorrection = 'opening_balance_correction';
const String adjustmentReasonBalanceCorrection = 'balance_correction';
const String adjustmentReasonFeeCorrection = 'fee_correction';
const String adjustmentReasonOther = 'other';

const Set<String> _adjustmentReasons = <String>{
  adjustmentReasonOpeningCorrection,
  adjustmentReasonBalanceCorrection,
  adjustmentReasonFeeCorrection,
  adjustmentReasonOther,
};

/// Whether [reason] is a recognised adjustment reason.
bool isAdjustmentReason(String reason) => _adjustmentReasons.contains(reason);

/// The counterpart ledger id for an adjustment, determined by its
/// reason (blueprint section 6.3, normative counterpart rules).
///
/// `opening_balance_correction` always uses `opening_equity`;
/// `balance_correction` always uses `adjustments`; `fee_correction`
/// and `other` use the category ledger when [categoryId] is given
/// (which requires [reportingKind]) and `adjustments` otherwise.
/// Throws [PostingValidationException] for an unknown reason, for a
/// categorised reason without [reportingKind], or for a reason that
/// must not carry a category.
String counterpartLedgerIdForAdjustment({
  required String adjustmentReason,
  String? categoryId,
  ReportingKind? reportingKind,
}) {
  switch (adjustmentReason) {
    case adjustmentReasonOpeningCorrection:
      if (categoryId != null) {
        throw const PostingValidationException(
          'opening_balance_correction must not carry a categoryId.',
        );
      }
      return openingEquityLedgerId;
    case adjustmentReasonBalanceCorrection:
      if (categoryId != null) {
        throw const PostingValidationException(
          'balance_correction must not carry a categoryId.',
        );
      }
      return adjustmentsLedgerId;
    case adjustmentReasonFeeCorrection:
    case adjustmentReasonOther:
      if (categoryId == null) {
        return adjustmentsLedgerId;
      }
      if (reportingKind == null) {
        throw const PostingValidationException(
          'A categorised fee_correction or other adjustment must '
          'specify which category ledger side it corrects.',
        );
      }
      final side = reportingKind == ReportingKind.expense
          ? 'expense'
          : 'income';
      return '$side:$categoryId';
    default:
      throw PostingValidationException(
        'Unknown adjustment reason: $adjustmentReason.',
      );
  }
}

/// A resolved ledger account, as seen by the posting builders.
///
/// Repositories load the row from the database and pass it here; the
/// builders validate shape, kind, and archival state from these
/// fields and never query the database themselves.
class LedgerDescriptor {
  const LedgerDescriptor({
    required this.ledgerAccountId,
    required this.kind,
    required this.normalBalance,
    this.userAccountId,
    this.categoryId,
    this.isSystem = false,
    this.isArchived = false,
  });

  final String ledgerAccountId;
  final String kind;
  final LedgerDirection normalBalance;
  final String? userAccountId;
  final String? categoryId;
  final bool isSystem;
  final bool isArchived;

  /// Whether this ledger is a user account ledger.
  bool get isUserLedger =>
      kind == ledgerKindUserAsset || kind == ledgerKindUserLiability;

  /// Whether this ledger is a per-category system ledger.
  bool get isCategoryLedger =>
      kind == ledgerKindSystemExpense || kind == ledgerKindSystemIncome;

  /// Validates the exactly-one-of mapping rule (blueprint section 5.2):
  /// user ledgers carry exactly `userAccountId`; category ledgers
  /// carry exactly `categoryId`; system equity/adjustment ledgers
  /// carry neither. Also validates the normal-balance side for the
  /// kind. Throws [PostingValidationException] on any violation.
  void validateShape() {
    switch (kind) {
      case ledgerKindUserAsset:
      case ledgerKindUserLiability:
        if (userAccountId == null || categoryId != null) {
          throw PostingValidationException(
            'User ledger $ledgerAccountId must carry exactly '
            'userAccountId.',
          );
        }
        break;
      case ledgerKindSystemExpense:
      case ledgerKindSystemIncome:
        if (categoryId == null || userAccountId != null) {
          throw PostingValidationException(
            'Category ledger $ledgerAccountId must carry exactly '
            'categoryId.',
          );
        }
        break;
      case ledgerKindSystemOpeningEquity:
      case ledgerKindSystemAdjustment:
        if (userAccountId != null || categoryId != null) {
          throw PostingValidationException(
            'System ledger $ledgerAccountId must carry neither '
            'userAccountId nor categoryId.',
          );
        }
        break;
      default:
        throw PostingValidationException('Unknown ledger kind: $kind.');
    }
    final expectedNormal =
        (kind == ledgerKindUserAsset || kind == ledgerKindSystemExpense)
        ? LedgerDirection.debit
        : LedgerDirection.credit;
    if (normalBalance != expectedNormal) {
      throw PostingValidationException(
        'Ledger $ledgerAccountId of kind $kind must have normal '
        'balance ${expectedNormal.value}.',
      );
    }
  }
}

/// One side of a balanced financial event, before persistence.
///
/// Amounts are always strictly positive; direction carries the sign.
/// Repositories insert these drafts (with fresh uuids) in the same
/// database transaction as the transaction row.
class PostingDraft {
  const PostingDraft({
    required this.ledgerAccountId,
    required this.direction,
    required this.amountMinorUnits,
    required this.currencyCode,
  });

  final String ledgerAccountId;
  final LedgerDirection direction;
  final int amountMinorUnits;
  final String currencyCode;

  @override
  bool operator ==(Object other) {
    return other is PostingDraft &&
        other.ledgerAccountId == ledgerAccountId &&
        other.direction == direction &&
        other.amountMinorUnits == amountMinorUnits &&
        other.currencyCode == currencyCode;
  }

  @override
  int get hashCode =>
      Object.hash(ledgerAccountId, direction, amountMinorUnits, currencyCode);
}

/// Validates a complete posting set against its ledger descriptors.
///
/// Enforces: at least two postings; every amount strictly positive;
/// one supported currency shared by all postings; every ledger known
/// and shape-valid; archival rules per [modes] (a missing mode entry
/// defaults to [ReferenceMode.newReferences]); and the balancing
/// invariant (sum of debits equals sum of credits, blueprint
/// section 6.3 rule 1). Returns an unmodifiable copy of [drafts].
/// Throws [PostingValidationException] on any violation.
List<PostingDraft> validatePostingSet(
  List<PostingDraft> drafts,
  Map<String, LedgerDescriptor> descriptors, {
  Map<String, ReferenceMode> modes = const <String, ReferenceMode>{},
}) {
  if (drafts.length < 2) {
    throw const PostingValidationException(
      'A transaction requires at least two postings.',
    );
  }
  String? currencyCode;
  var debits = BigInt.zero;
  var credits = BigInt.zero;
  for (final draft in drafts) {
    if (draft.amountMinorUnits <= 0) {
      throw const PostingValidationException(
        'Posting amounts must be strictly positive.',
      );
    }
    if (!isSupportedCurrencyCode(draft.currencyCode)) {
      throw PostingValidationException(
        'Unsupported currency code: ${draft.currencyCode}.',
      );
    }
    currencyCode ??= draft.currencyCode;
    if (draft.currencyCode != currencyCode) {
      throw const PostingValidationException(
        'All postings of one transaction must share a currency.',
      );
    }
    final descriptor = descriptors[draft.ledgerAccountId];
    if (descriptor == null) {
      throw PostingValidationException(
        'Unknown ledger account: ${draft.ledgerAccountId}.',
      );
    }
    descriptor.validateShape();
    final mode = modes[draft.ledgerAccountId] ?? ReferenceMode.newReferences;
    if (mode == ReferenceMode.newReferences && descriptor.isArchived) {
      throw PostingValidationException(
        'Ledger account ${draft.ledgerAccountId} is archived and '
        'cannot be selected for a new transaction.',
      );
    }
    if (draft.direction == LedgerDirection.debit) {
      debits += BigInt.from(draft.amountMinorUnits);
    } else {
      credits += BigInt.from(draft.amountMinorUnits);
    }
  }
  if (debits != credits) {
    throw PostingValidationException(
      'Postings do not balance: debits $debits, credits $credits.',
    );
  }
  return List<PostingDraft>.unmodifiable(drafts);
}

void _requirePositiveAmount(int amountMinorUnits) {
  if (amountMinorUnits <= 0) {
    throw const PostingValidationException(
      'Transaction amounts must be strictly positive.',
    );
  }
}

void _requireCurrency(String currencyCode) {
  if (!isSupportedCurrencyCode(currencyCode)) {
    throw PostingValidationException(
      'Unsupported currency code: $currencyCode.',
    );
  }
}

/// Builds postings for an expense (blueprint section 6.3 case A/E):
/// debit the category expense ledger, credit the account ledger.
List<PostingDraft> buildExpensePostings({
  required LedgerDescriptor accountLedger,
  required LedgerDescriptor categoryLedger,
  required int amountMinorUnits,
  required String currencyCode,
  ReferenceMode mode = ReferenceMode.newReferences,
}) {
  _requirePositiveAmount(amountMinorUnits);
  _requireCurrency(currencyCode);
  if (!accountLedger.isUserLedger) {
    throw const PostingValidationException(
      'An expense must move a user account ledger.',
    );
  }
  if (categoryLedger.kind != ledgerKindSystemExpense) {
    throw const PostingValidationException(
      'An expense must use a system expense ledger as counterpart.',
    );
  }
  final descriptors = <String, LedgerDescriptor>{
    accountLedger.ledgerAccountId: accountLedger,
    categoryLedger.ledgerAccountId: categoryLedger,
  };
  return validatePostingSet(
    <PostingDraft>[
      PostingDraft(
        ledgerAccountId: categoryLedger.ledgerAccountId,
        direction: LedgerDirection.debit,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
      PostingDraft(
        ledgerAccountId: accountLedger.ledgerAccountId,
        direction: LedgerDirection.credit,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
    ],
    descriptors,
    modes: <String, ReferenceMode>{
      accountLedger.ledgerAccountId: mode,
      categoryLedger.ledgerAccountId: mode,
    },
  );
}

/// Builds postings for income (blueprint section 6.3 case C):
/// debit the account ledger, credit the category income ledger.
List<PostingDraft> buildIncomePostings({
  required LedgerDescriptor accountLedger,
  required LedgerDescriptor categoryLedger,
  required int amountMinorUnits,
  required String currencyCode,
  ReferenceMode mode = ReferenceMode.newReferences,
}) {
  _requirePositiveAmount(amountMinorUnits);
  _requireCurrency(currencyCode);
  if (!accountLedger.isUserLedger) {
    throw const PostingValidationException(
      'Income must move a user account ledger.',
    );
  }
  if (categoryLedger.kind != ledgerKindSystemIncome) {
    throw const PostingValidationException(
      'Income must use a system income ledger as counterpart.',
    );
  }
  final descriptors = <String, LedgerDescriptor>{
    accountLedger.ledgerAccountId: accountLedger,
    categoryLedger.ledgerAccountId: categoryLedger,
  };
  return validatePostingSet(
    <PostingDraft>[
      PostingDraft(
        ledgerAccountId: accountLedger.ledgerAccountId,
        direction: LedgerDirection.debit,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
      PostingDraft(
        ledgerAccountId: categoryLedger.ledgerAccountId,
        direction: LedgerDirection.credit,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
    ],
    descriptors,
    modes: <String, ReferenceMode>{
      accountLedger.ledgerAccountId: mode,
      categoryLedger.ledgerAccountId: mode,
    },
  );
}

/// Builds postings for a two-account movement (blueprint section 6.3
/// cases D and F): debit the destination ledger, credit the source
/// ledger. Used for both transfers and card payments, which share
/// this shape; the transaction kind distinguishes them.
List<PostingDraft> buildTwoAccountPostings({
  required LedgerDescriptor sourceLedger,
  required LedgerDescriptor destinationLedger,
  required int amountMinorUnits,
  required String currencyCode,
  ReferenceMode mode = ReferenceMode.newReferences,
}) {
  _requirePositiveAmount(amountMinorUnits);
  _requireCurrency(currencyCode);
  if (!sourceLedger.isUserLedger || !destinationLedger.isUserLedger) {
    throw const PostingValidationException(
      'A transfer or card payment must move between two user '
      'account ledgers.',
    );
  }
  if (sourceLedger.ledgerAccountId == destinationLedger.ledgerAccountId) {
    throw const PostingValidationException(
      'A transfer or card payment cannot move money to the same account.',
    );
  }
  final descriptors = <String, LedgerDescriptor>{
    sourceLedger.ledgerAccountId: sourceLedger,
    destinationLedger.ledgerAccountId: destinationLedger,
  };
  return validatePostingSet(
    <PostingDraft>[
      PostingDraft(
        ledgerAccountId: destinationLedger.ledgerAccountId,
        direction: LedgerDirection.debit,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
      PostingDraft(
        ledgerAccountId: sourceLedger.ledgerAccountId,
        direction: LedgerDirection.credit,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
    ],
    descriptors,
    modes: <String, ReferenceMode>{
      sourceLedger.ledgerAccountId: mode,
      destinationLedger.ledgerAccountId: mode,
    },
  );
}

/// Builds postings for a refund (blueprint section 6.3 case G).
///
/// Postings mirror the original event's postings with directions
/// reversed, for the refund amount: an expense refund debits the
/// refund account ledger and credits the category expense ledger; an
/// income refund debits the category income ledger and credits the
/// refund account ledger. The account side is a new user selection
/// ([accountMode], archived rejected); the category side is inherited
/// from the original ([categoryMode], archived allowed).
List<PostingDraft> buildRefundPostings({
  required String originalKind,
  required LedgerDescriptor refundAccountLedger,
  required LedgerDescriptor categoryLedger,
  required int amountMinorUnits,
  required String currencyCode,
  ReferenceMode accountMode = ReferenceMode.newReferences,
  ReferenceMode categoryMode = ReferenceMode.inherited,
}) {
  _requirePositiveAmount(amountMinorUnits);
  _requireCurrency(currencyCode);
  if (originalKind != 'expense' && originalKind != 'income') {
    throw PostingValidationException(
      'Only expense and income transactions can be refunded, '
      'not $originalKind.',
    );
  }
  if (!refundAccountLedger.isUserLedger) {
    throw const PostingValidationException(
      'A refund must move a user account ledger.',
    );
  }
  final expectedCategoryKind = originalKind == 'expense'
      ? ledgerKindSystemExpense
      : ledgerKindSystemIncome;
  if (categoryLedger.kind != expectedCategoryKind) {
    throw PostingValidationException(
      'A $originalKind refund must use a $expectedCategoryKind '
      'ledger as its category side.',
    );
  }
  final descriptors = <String, LedgerDescriptor>{
    refundAccountLedger.ledgerAccountId: refundAccountLedger,
    categoryLedger.ledgerAccountId: categoryLedger,
  };
  final drafts = originalKind == 'expense'
      ? <PostingDraft>[
          PostingDraft(
            ledgerAccountId: refundAccountLedger.ledgerAccountId,
            direction: LedgerDirection.debit,
            amountMinorUnits: amountMinorUnits,
            currencyCode: currencyCode,
          ),
          PostingDraft(
            ledgerAccountId: categoryLedger.ledgerAccountId,
            direction: LedgerDirection.credit,
            amountMinorUnits: amountMinorUnits,
            currencyCode: currencyCode,
          ),
        ]
      : <PostingDraft>[
          PostingDraft(
            ledgerAccountId: categoryLedger.ledgerAccountId,
            direction: LedgerDirection.debit,
            amountMinorUnits: amountMinorUnits,
            currencyCode: currencyCode,
          ),
          PostingDraft(
            ledgerAccountId: refundAccountLedger.ledgerAccountId,
            direction: LedgerDirection.credit,
            amountMinorUnits: amountMinorUnits,
            currencyCode: currencyCode,
          ),
        ];
  return validatePostingSet(
    drafts,
    descriptors,
    modes: <String, ReferenceMode>{
      refundAccountLedger.ledgerAccountId: accountMode,
      categoryLedger.ledgerAccountId: categoryMode,
    },
  );
}

/// Builds postings for an adjustment (blueprint section 6.3).
///
/// Exactly two postings: the affected account's ledger and the
/// counterpart ledger determined by [adjustmentReason] (see
/// [counterpartLedgerIdForAdjustment]). [direction] is relative to
/// the account's normal balance: `increase` posts the account ledger
/// on its normal side, `decrease` on the opposite side; the
/// counterpart takes the opposite direction. [counterpartLedger]
/// must be the ledger id the reason requires; a categorised
/// `fee_correction`/`other` adjustment additionally requires
/// [reportingKind] matching the counterpart ledger kind and
/// [categoryId] matching the counterpart's category.
List<PostingDraft> buildAdjustmentPostings({
  required LedgerDescriptor accountLedger,
  required LedgerDescriptor counterpartLedger,
  required AdjustmentDirection direction,
  required String adjustmentReason,
  required int amountMinorUnits,
  required String currencyCode,
  String? categoryId,
  ReportingKind? reportingKind,
  ReferenceMode mode = ReferenceMode.newReferences,
}) {
  _requirePositiveAmount(amountMinorUnits);
  _requireCurrency(currencyCode);
  if (!isAdjustmentReason(adjustmentReason)) {
    throw PostingValidationException(
      'Unknown adjustment reason: $adjustmentReason.',
    );
  }
  if (!accountLedger.isUserLedger) {
    throw const PostingValidationException(
      'An adjustment must affect a user account ledger.',
    );
  }
  final expectedCounterpartId = counterpartLedgerIdForAdjustment(
    adjustmentReason: adjustmentReason,
    categoryId: categoryId,
    reportingKind: reportingKind,
  );
  if (counterpartLedger.ledgerAccountId != expectedCounterpartId) {
    throw PostingValidationException(
      'Adjustment reason $adjustmentReason requires counterpart '
      '$expectedCounterpartId, not '
      '${counterpartLedger.ledgerAccountId}.',
    );
  }
  if (counterpartLedger.isCategoryLedger) {
    if (counterpartLedger.categoryId != categoryId) {
      throw const PostingValidationException(
        'A categorised adjustment counterpart must carry the '
        'adjustment categoryId.',
      );
    }
    final expectedKind = reportingKind == ReportingKind.expense
        ? ledgerKindSystemExpense
        : ledgerKindSystemIncome;
    if (counterpartLedger.kind != expectedKind) {
      throw const PostingValidationException(
        'A categorised adjustment counterpart kind does not match '
        'its reporting side.',
      );
    }
  }
  final accountDirection = direction == AdjustmentDirection.increase
      ? accountLedger.normalBalance
      : accountLedger.normalBalance.opposite;
  final descriptors = <String, LedgerDescriptor>{
    accountLedger.ledgerAccountId: accountLedger,
    counterpartLedger.ledgerAccountId: counterpartLedger,
  };
  return validatePostingSet(
    <PostingDraft>[
      PostingDraft(
        ledgerAccountId: accountLedger.ledgerAccountId,
        direction: accountDirection,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
      PostingDraft(
        ledgerAccountId: counterpartLedger.ledgerAccountId,
        direction: accountDirection.opposite,
        amountMinorUnits: amountMinorUnits,
        currencyCode: currencyCode,
      ),
    ],
    descriptors,
    modes: <String, ReferenceMode>{
      accountLedger.ledgerAccountId: mode,
      counterpartLedger.ledgerAccountId: mode,
    },
  );
}

/// Builds postings for an opening balance (blueprint section 6.4).
///
/// [signedAmountMinorUnits] is the signed opening amount: positive
/// means the balance increases on the account's normal side, negative
/// means it decreases it. The persisted amount is always the absolute
/// value; sign lives entirely in the posting directions. Zero is
/// rejected: a zero opening balance creates no event and no postings.
/// The counterpart is always the `opening_equity` ledger.
List<PostingDraft> buildOpeningBalancePostings({
  required LedgerDescriptor accountLedger,
  required LedgerDescriptor openingEquityLedger,
  required int signedAmountMinorUnits,
  required String currencyCode,
  ReferenceMode mode = ReferenceMode.newReferences,
}) {
  _requireCurrency(currencyCode);
  if (signedAmountMinorUnits == 0) {
    throw const PostingValidationException(
      'A zero opening balance creates no event and no postings.',
    );
  }
  if (!accountLedger.isUserLedger) {
    throw const PostingValidationException(
      'An opening balance must belong to a user account ledger.',
    );
  }
  if (openingEquityLedger.ledgerAccountId != openingEquityLedgerId ||
      openingEquityLedger.kind != ledgerKindSystemOpeningEquity) {
    throw const PostingValidationException(
      'An opening balance counterpart must be the opening_equity '
      'ledger account.',
    );
  }
  // The magnitude may be 2^63 only for the minimum signed value;
  // checked conversion rejects it as an unrepresentable positive
  // amount instead of silently wrapping.
  final magnitude = BigInt.from(signedAmountMinorUnits).abs();
  const maxInt64 = 9223372036854775807;
  if (magnitude > BigInt.from(maxInt64)) {
    throw StateError(
      'Opening balance magnitude $magnitude cannot be represented '
      'as a signed 64-bit integer.',
    );
  }
  final amount = magnitude.toInt();
  final increasesNormal = signedAmountMinorUnits > 0;
  final accountDirection = increasesNormal
      ? accountLedger.normalBalance
      : accountLedger.normalBalance.opposite;
  final descriptors = <String, LedgerDescriptor>{
    accountLedger.ledgerAccountId: accountLedger,
    openingEquityLedger.ledgerAccountId: openingEquityLedger,
  };
  return validatePostingSet(
    <PostingDraft>[
      PostingDraft(
        ledgerAccountId: accountLedger.ledgerAccountId,
        direction: accountDirection,
        amountMinorUnits: amount,
        currencyCode: currencyCode,
      ),
      PostingDraft(
        ledgerAccountId: openingEquityLedger.ledgerAccountId,
        direction: accountDirection.opposite,
        amountMinorUnits: amount,
        currencyCode: currencyCode,
      ),
    ],
    descriptors,
    modes: <String, ReferenceMode>{
      accountLedger.ledgerAccountId: mode,
      openingEquityLedger.ledgerAccountId: mode,
    },
  );
}

/// Builds reversal postings by mirroring [originalDrafts] exactly:
/// same ledger accounts, same amounts, opposite directions
/// (blueprint sections 6.3 and 6.6). All references are inherited,
/// so archived ledger rows are allowed. The original set is
/// validated first; the mirrored set is validated again before
/// return.
List<PostingDraft> buildReversalPostings({
  required List<PostingDraft> originalDrafts,
  required Map<String, LedgerDescriptor> originalDescriptors,
}) {
  final validatedOriginals = validatePostingSet(
    originalDrafts,
    originalDescriptors,
    modes: <String, ReferenceMode>{
      for (final id in originalDescriptors.keys) id: ReferenceMode.inherited,
    },
  );
  final mirrored = validatedOriginals
      .map(
        (draft) => PostingDraft(
          ledgerAccountId: draft.ledgerAccountId,
          direction: draft.direction.opposite,
          amountMinorUnits: draft.amountMinorUnits,
          currencyCode: draft.currencyCode,
        ),
      )
      .toList();
  return validatePostingSet(
    mirrored,
    originalDescriptors,
    modes: <String, ReferenceMode>{
      for (final id in originalDescriptors.keys) id: ReferenceMode.inherited,
    },
  );
}
