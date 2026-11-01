// V2 financial-transaction repository (blueprint sections 5.2,
// 6.3-6.6; corrected Stage 2 design, C1-C4, D1-D7, final reporting
// refinements).
//
// V2-only: touches only the V2 tables. Production startup still uses
// the old database in Stage 2; the coordinated Stage 5 cutover
// switches it. No V1 table, repository, or provider is imported or
// modified here.
//
// Every mutating method runs inside one database transaction: the
// transaction row, its postings, its history row, and the revision
// bump commit together or not at all. Postings are built only by
// the pure builders in `posting_rules.dart`; this repository
// resolves ledger rows, enforces lifecycle invariants by
// recomputing them from current active rows inside the transaction
// (never from cached totals), and owns the clock seam used for the
// future-date rule and for `updatedAt` metadata.
//
// Future-date rule (final refinement 2): an actual posted
// transaction must have `occurredAt` no later than the repository
// clock. Creation, edit, and restore reject future dates. Scheduled
// or recurring events create no postings until they become actual
// transactions (a later module); no scheduled state exists here.
//
// Reporting snapshots are loaded here and nowhere else: one read
// transaction, active-only SQL predicates, no SQL aggregation, and
// batched reversal-context loading. See [loadReportingSnapshot].

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/ledger/posting_rules.dart';
import '../../core/domain/money.dart';
import '../../core/domain/reporting.dart';
import '../database/v2/app_database_v2.dart';
import '../database/v2/ledger_descriptors.dart';

/// Payment-channel labels, as stored on `FinancialTransactions`.
/// These are the existing V1 display labels (approved plan decision
/// 5); canonicalisation to lowercase codes, if ever wanted, belongs
/// to a later stage and must not silently rewrite stored values.
const Set<String> paymentChannels = <String>{
  'UPI',
  'Cash',
  'Card',
  'Bank Transfer',
};

/// Editable fields for [FinancialTransactionRepository.editTransaction].
/// Every field is optional; a null field keeps the existing value,
/// except where a `clear...` flag is set. Amount, account, and
/// category changes rebuild postings through the builders;
/// description/notes/channel changes update the row only. For an
/// `opening_balance` edit, [amount] carries the SIGNED opening
/// amount. See the edit method for the lifecycle guards that apply.
class TransactionEdit {
  const TransactionEdit({
    this.amount,
    this.accountUuid,
    this.categoryId,
    this.clearCategoryId = false,
    this.sourceAccountUuid,
    this.destinationAccountUuid,
    this.occurredAt,
    this.description,
    this.notes,
    this.paymentChannel,
    this.adjustmentDirection,
    this.adjustmentReason,
    this.reportingKind,
    this.relatedTransactionUuid,
    this.clearRelatedTransactionUuid = false,
  });

  final Money? amount;
  final String? accountUuid;
  final String? categoryId;

  /// When true, an adjustment's category is cleared to null (an
  /// uncategorised adjustment). Without this flag a null
  /// [categoryId] keeps the existing value.
  final bool clearCategoryId;
  final String? sourceAccountUuid;
  final String? destinationAccountUuid;
  final DateTime? occurredAt;
  final String? description;
  final String? notes;
  final String? paymentChannel;
  final AdjustmentDirection? adjustmentDirection;
  final String? adjustmentReason;
  final ReportingKind? reportingKind;
  final String? relatedTransactionUuid;

  /// When true, an adjustment's related transaction is cleared.
  final bool clearRelatedTransactionUuid;
}

/// A transaction row with its complete postings.
class TransactionWithPostings {
  const TransactionWithPostings({
    required this.transaction,
    required this.postings,
  });

  final FinancialTransaction transaction;
  final List<Posting> postings;
}

class FinancialTransactionRepository {
  FinancialTransactionRepository(
    this._database, {
    DateTime Function()? clock,
    String Function()? uuidGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newUuid = uuidGenerator ?? (() => const Uuid().v4());

  final AppDatabaseV2 _database;
  final DateTime Function() _clock;
  final String Function() _newUuid;

  // -----------------------------------------------------------------
  // Reads.
  // -----------------------------------------------------------------

  Future<FinancialTransaction?> getTransactionByUuid(String uuid) async {
    return (_database.select(
      _database.financialTransactions,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<List<Posting>> getPostingsForTransaction(String uuid) async {
    final transaction = await getTransactionByUuid(uuid);
    if (transaction == null) {
      throw PostingValidationException('Unknown transaction: $uuid.');
    }
    return _postingsForTransactionId(transaction.id);
  }

  Future<TransactionWithPostings> getTransactionWithPostings(
    String uuid,
  ) async {
    final transaction = await getTransactionByUuid(uuid);
    if (transaction == null) {
      throw PostingValidationException('Unknown transaction: $uuid.');
    }
    final postings = await _postingsForTransactionId(transaction.id);
    return TransactionWithPostings(
      transaction: transaction,
      postings: postings,
    );
  }

  Future<List<FinancialTransaction>> listTransactions({String? status}) async {
    final query = _database.select(_database.financialTransactions)
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    return query.get();
  }

  /// Derived reversed status (blueprint section 6.6): true iff an
  /// active reversal references this transaction. Never stored.
  Future<bool> isReversed(String uuid) async {
    final reversal = await _activeReversalFor(uuid);
    return reversal != null;
  }

  /// Remaining refundable amount for an expense/income transaction:
  /// original amount minus active refund amounts, zero when an
  /// active reversal exists. Recomputed from current rows on every
  /// call; never cached.
  Future<int> refundableCapacity(String originalUuid) async {
    final original = await _requireTransaction(originalUuid);
    if (await _activeReversalFor(originalUuid) != null) {
      return 0;
    }
    final refunded = await _activeRefundTotal(originalUuid);
    final remaining = original.amountMinorUnits - refunded;
    return remaining < 0 ? 0 : remaining;
  }

  // -----------------------------------------------------------------
  // Expense and income.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> createExpense({
    required String accountUuid,
    required String categoryId,
    required Money amount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      final drafts = await _buildExpenseOrIncome(
        kind: 'expense',
        accountUuid: accountUuid,
        categoryId: categoryId,
        amount: amount,
        mode: ReferenceMode.newReferences,
      );
      return _insertTransactionLocked(
        kind: 'expense',
        categoryId: categoryId,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        drafts: drafts,
        now: now,
      );
    });
  }

  Future<FinancialTransaction> createIncome({
    required String accountUuid,
    required String categoryId,
    required Money amount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      final drafts = await _buildExpenseOrIncome(
        kind: 'income',
        accountUuid: accountUuid,
        categoryId: categoryId,
        amount: amount,
        mode: ReferenceMode.newReferences,
      );
      return _insertTransactionLocked(
        kind: 'income',
        categoryId: categoryId,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        drafts: drafts,
        now: now,
      );
    });
  }

  Future<List<PostingDraft>> _buildExpenseOrIncome({
    required String kind,
    required String accountUuid,
    required String categoryId,
    required Money amount,
    required ReferenceMode mode,
  }) async {
    _requirePositiveMoney(amount);
    final accountLedger = await _requireAccountLedger(accountUuid);
    final side = kind == 'expense'
        ? ReportingKind.expense
        : ReportingKind.income;
    final categoryLedger = await _requireCategoryLedger(categoryId, side);
    if (kind == 'expense') {
      return buildExpensePostings(
        accountLedger: accountLedger,
        categoryLedger: categoryLedger,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        mode: mode,
      );
    }
    return buildIncomePostings(
      accountLedger: accountLedger,
      categoryLedger: categoryLedger,
      amountMinorUnits: amount.amountMinorUnits,
      currencyCode: amount.currencyCode,
      mode: mode,
    );
  }

  // -----------------------------------------------------------------
  // Transfers and card payments.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> createTransfer({
    required String sourceAccountUuid,
    required String destinationAccountUuid,
    required Money amount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      final drafts = await _buildTwoAccount(
        sourceAccountUuid: sourceAccountUuid,
        destinationAccountUuid: destinationAccountUuid,
        amount: amount,
      );
      return _insertTransactionLocked(
        kind: 'transfer',
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        sourceAccountId: sourceAccountUuid,
        destinationAccountId: destinationAccountUuid,
        drafts: drafts,
        now: now,
      );
    });
  }

  Future<FinancialTransaction> createCardPayment({
    required String sourceAccountUuid,
    required String cardAccountUuid,
    required Money amount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      final sourceAccount = await _requireAccount(sourceAccountUuid);
      if (sourceAccount.kind == 'credit_card_liability') {
        throw const PostingValidationException(
          'A card payment must be funded from an asset account.',
        );
      }
      final cardAccount = await _requireAccount(cardAccountUuid);
      if (cardAccount.kind != 'credit_card_liability') {
        throw const PostingValidationException(
          'A card payment destination must be a credit-card liability '
          'account.',
        );
      }
      final drafts = await _buildTwoAccount(
        sourceAccountUuid: sourceAccountUuid,
        destinationAccountUuid: cardAccountUuid,
        amount: amount,
      );
      return _insertTransactionLocked(
        kind: 'card_payment',
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        sourceAccountId: sourceAccountUuid,
        destinationAccountId: cardAccountUuid,
        drafts: drafts,
        now: now,
      );
    });
  }

  Future<List<PostingDraft>> _buildTwoAccount({
    required String sourceAccountUuid,
    required String destinationAccountUuid,
    required Money amount,
  }) async {
    _requirePositiveMoney(amount);
    if (sourceAccountUuid == destinationAccountUuid) {
      throw const PostingValidationException(
        'A transfer or card payment cannot move money to the same account.',
      );
    }
    final sourceLedger = await _requireAccountLedger(sourceAccountUuid);
    final destinationLedger = await _requireAccountLedger(
      destinationAccountUuid,
    );
    return buildTwoAccountPostings(
      sourceLedger: sourceLedger,
      destinationLedger: destinationLedger,
      amountMinorUnits: amount.amountMinorUnits,
      currencyCode: amount.currencyCode,
    );
  }

  // -----------------------------------------------------------------
  // Refunds.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> createRefund({
    required String originalUuid,
    required String refundAccountUuid,
    required Money amount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    _requirePositiveMoney(amount);
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      final original = await _requireTransaction(originalUuid);
      if (original.status != 'active') {
        throw const PostingValidationException(
          'A refund requires an active original transaction.',
        );
      }
      if (original.kind != 'expense' && original.kind != 'income') {
        throw PostingValidationException(
          'Only expense and income transactions can be refunded, '
          'not ${original.kind}.',
        );
      }
      if (await _activeReversalFor(originalUuid) != null) {
        throw const PostingValidationException(
          'An original with an active reversal cannot be refunded.',
        );
      }
      final capacity = await _refundableCapacityLocked(original);
      if (amount.amountMinorUnits > capacity) {
        throw PostingValidationException(
          'Refund of ${amount.amountMinorUnits} exceeds the '
          'refundable capacity of $capacity.',
        );
      }
      // The category snapshot is the original's CURRENT categoryId
      // at refund creation; it becomes immutable on the refund row
      // (blueprint section 6.3). The category ledger is an inherited
      // reference (C1): it may be archived.
      final snapshotCategoryId = original.categoryId;
      if (snapshotCategoryId == null) {
        throw const PostingValidationException(
          'A refund requires an original with a category.',
        );
      }
      final side = original.kind == 'expense'
          ? ReportingKind.expense
          : ReportingKind.income;
      final categoryLedger = await _requireCategoryLedger(
        snapshotCategoryId,
        side,
      );
      final refundLedger = await _requireAccountLedger(refundAccountUuid);
      final drafts = buildRefundPostings(
        originalKind: original.kind,
        refundAccountLedger: refundLedger,
        categoryLedger: categoryLedger,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
      );
      return _insertTransactionLocked(
        kind: 'refund',
        categoryId: snapshotCategoryId,
        reversesTransactionId: originalUuid,
        refundAccountId: refundAccountUuid,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        drafts: drafts,
        now: now,
      );
    });
  }

  // -----------------------------------------------------------------
  // Adjustments.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> createAdjustment({
    required String accountUuid,
    required String adjustmentReason,
    required AdjustmentDirection direction,
    required Money amount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? categoryId,
    ReportingKind? reportingKind,
    String? relatedTransactionUuid,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    _requirePositiveMoney(amount);
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      if (relatedTransactionUuid != null) {
        final related = await _requireTransaction(relatedTransactionUuid);
        if (related.status != 'active') {
          throw const PostingValidationException(
            'An adjustment related transaction must be active.',
          );
        }
        if (adjustmentReason == adjustmentReasonOpeningCorrection &&
            related.kind != 'opening_balance') {
          throw const PostingValidationException(
            'An opening_balance_correction may only relate to an '
            'opening_balance transaction.',
          );
        }
      }
      final accountLedger = await _requireAccountLedger(accountUuid);
      final counterpartId = counterpartLedgerIdForAdjustment(
        adjustmentReason: adjustmentReason,
        categoryId: categoryId,
        reportingKind: reportingKind,
      );
      final counterpart = await _requireLedgerById(counterpartId);
      final drafts = buildAdjustmentPostings(
        accountLedger: accountLedger,
        counterpartLedger: counterpart,
        direction: direction,
        adjustmentReason: adjustmentReason,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        categoryId: categoryId,
        reportingKind: reportingKind,
      );
      return _insertTransactionLocked(
        kind: 'adjustment',
        categoryId: categoryId,
        relatedTransactionId: relatedTransactionUuid,
        amountMinorUnits: amount.amountMinorUnits,
        currencyCode: amount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        adjustmentReason: adjustmentReason,
        drafts: drafts,
        now: now,
      );
    });
  }

  // -----------------------------------------------------------------
  // Opening balances.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> createOpeningBalance({
    required String accountUuid,
    required Money signedAmount,
    required DateTime occurredAt,
    required String paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    if (signedAmount.currencyCode != 'INR') {
      throw const PostingValidationException(
        'V1 opening balances are INR only.',
      );
    }
    if (signedAmount.isZero) {
      throw const PostingValidationException(
        'A zero opening balance creates no event and no postings.',
      );
    }
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    _requirePaymentChannel(paymentChannel);
    return _database.transaction(() async {
      final accountLedger = await _requireAccountLedger(accountUuid);
      if (await _hasActiveOpeningEvent(accountLedger.ledgerAccountId)) {
        throw const PostingValidationException(
          'An account already has an active opening balance event.',
        );
      }
      if (await _hasActivePostings(accountLedger.ledgerAccountId)) {
        throw const PostingValidationException(
          'An opening_balance event cannot be created once the '
          'account has financial activity; use an '
          'opening_balance_correction adjustment instead.',
        );
      }
      final openingEquity = await _requireLedgerById(openingEquityLedgerId);
      final drafts = buildOpeningBalancePostings(
        accountLedger: accountLedger,
        openingEquityLedger: openingEquity,
        signedAmountMinorUnits: signedAmount.amountMinorUnits,
        currencyCode: signedAmount.currencyCode,
      );
      return _insertTransactionLocked(
        kind: 'opening_balance',
        amountMinorUnits: drafts.first.amountMinorUnits,
        currencyCode: signedAmount.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel,
        occurredAt: occurredAt,
        source: source,
        drafts: drafts,
        now: now,
      );
    });
  }

  /// Edits an opening balance before any other activity on the
  /// account (blueprint section 6.4): replaces the opening
  /// transaction's postings atomically, with a history row and a
  /// revision bump. Rejected once other active postings exist, once
  /// an active reversal references the opening event, or when the
  /// new amount is zero.
  Future<FinancialTransaction> editOpeningBalance({
    required String accountUuid,
    required Money signedAmount,
    DateTime? occurredAt,
    String? description,
    String? notes,
  }) async {
    if (signedAmount.currencyCode != 'INR') {
      throw const PostingValidationException(
        'V1 opening balances are INR only.',
      );
    }
    if (signedAmount.isZero) {
      throw const PostingValidationException(
        'An opening balance cannot be edited to zero; delete or '
        'reverse the opening event instead.',
      );
    }
    final now = _clock();
    if (occurredAt != null) {
      _requireNotFuture(occurredAt, now);
    }
    return _database.transaction(() async {
      final accountLedger = await _requireAccountLedger(accountUuid);
      final opening = await _activeOpeningEvent(accountLedger.ledgerAccountId);
      if (opening == null) {
        throw const PostingValidationException(
          'The account has no active opening balance event to edit.',
        );
      }
      if (await _activeReversalFor(opening.uuid) != null) {
        throw const PostingValidationException(
          'An opening balance with an active reversal cannot be edited.',
        );
      }
      return editOpeningBalanceLocked(
        accountUuid: accountUuid,
        existing: opening,
        signedAmount: signedAmount,
        occurredAt: occurredAt,
        description: description,
        notes: notes,
        now: now,
      );
    });
  }

  // -----------------------------------------------------------------
  // Reversals.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> createReversal({
    required String originalUuid,
    required DateTime occurredAt,
    String? paymentChannel,
    String? description,
    String? notes,
    String source = 'manual',
  }) async {
    final now = _clock();
    _requireNotFuture(occurredAt, now);
    return _database.transaction(() async {
      final original = await _requireTransaction(originalUuid);
      if (original.status != 'active') {
        throw const PostingValidationException(
          'A reversal requires an active original transaction.',
        );
      }
      if (original.kind == 'refund' || original.kind == 'reversal') {
        throw PostingValidationException(
          'A ${original.kind} transaction cannot be reversed.',
        );
      }
      if (occurredAt.isBefore(original.occurredAt)) {
        throw const PostingValidationException(
          'A reversal must not predate its original transaction.',
        );
      }
      if (await _activeReversalFor(originalUuid) != null) {
        throw const PostingValidationException(
          'An active reversal already references this transaction.',
        );
      }
      if (await _activeRefundTotal(originalUuid) > 0) {
        throw const PostingValidationException(
          'An original with active refunds cannot be reversed; '
          'delete the refunds first.',
        );
      }
      final originalPostings = await _postingsForTransactionId(original.id);
      final descriptors = await _descriptorsForPostings(originalPostings);
      final originalDrafts = originalPostings
          .map(
            (posting) => PostingDraft(
              ledgerAccountId: posting.ledgerAccountId,
              direction: ledgerDirectionFromValue(posting.direction),
              amountMinorUnits: posting.amountMinorUnits,
              currencyCode: posting.currencyCode,
            ),
          )
          .toList();
      final drafts = buildReversalPostings(
        originalDrafts: originalDrafts,
        originalDescriptors: descriptors,
      );
      // Transfer/card-payment reversals swap source and destination
      // (Sheets mapping rule, plan section 7); other kinds carry
      // the original's category and no account fields.
      String? sourceAccountId;
      String? destinationAccountId;
      if (original.kind == 'transfer' || original.kind == 'card_payment') {
        sourceAccountId = original.destinationAccountId;
        destinationAccountId = original.sourceAccountId;
      }
      return _insertTransactionLocked(
        kind: 'reversal',
        categoryId: original.categoryId,
        reversesTransactionId: originalUuid,
        sourceAccountId: sourceAccountId,
        destinationAccountId: destinationAccountId,
        amountMinorUnits: original.amountMinorUnits,
        currencyCode: original.currencyCode,
        description: description,
        notes: notes,
        paymentChannel: paymentChannel ?? original.paymentChannel,
        occurredAt: occurredAt,
        source: source,
        drafts: drafts,
        now: now,
      );
    });
  }

  // -----------------------------------------------------------------
  // Edit, delete, restore.
  // -----------------------------------------------------------------

  Future<FinancialTransaction> editTransaction(
    String uuid,
    TransactionEdit edit,
  ) async {
    final now = _clock();
    return _database.transaction(() async {
      final existing = await _requireTransaction(uuid);
      if (existing.status != 'active') {
        throw const PostingValidationException(
          'Only an active transaction can be edited.',
        );
      }
      if (await _activeReversalFor(uuid) != null) {
        throw const PostingValidationException(
          'A transaction with an active reversal cannot be edited; '
          'delete the reversal first.',
        );
      }
      if (existing.kind == 'reversal') {
        return _editMetadataOnly(existing, edit, now);
      }
      if (existing.kind == 'refund') {
        return _editRefund(existing, edit, now);
      }
      if (existing.kind == 'opening_balance') {
        return _editOpeningViaEdit(existing, edit, now);
      }
      return _editGeneral(existing, edit, now);
    });
  }

  Future<FinancialTransaction> _editMetadataOnly(
    FinancialTransaction existing,
    TransactionEdit edit,
    DateTime now,
  ) async {
    if (edit.amount != null ||
        edit.accountUuid != null ||
        edit.categoryId != null ||
        edit.sourceAccountUuid != null ||
        edit.destinationAccountUuid != null ||
        edit.occurredAt != null ||
        edit.adjustmentDirection != null ||
        edit.adjustmentReason != null ||
        edit.reportingKind != null ||
        edit.relatedTransactionUuid != null) {
      throw const PostingValidationException(
        'A reversal transaction cannot be edited except for '
        'description and notes.',
      );
    }
    if (edit.paymentChannel != null) {
      _requirePaymentChannel(edit.paymentChannel!);
    }
    return _updateRowOnly(existing, edit, now);
  }

  Future<FinancialTransaction> _editRefund(
    FinancialTransaction existing,
    TransactionEdit edit,
    DateTime now,
  ) async {
    if (edit.amount != null ||
        edit.accountUuid != null ||
        edit.categoryId != null ||
        edit.sourceAccountUuid != null ||
        edit.destinationAccountUuid != null ||
        edit.adjustmentDirection != null ||
        edit.adjustmentReason != null ||
        edit.reportingKind != null ||
        edit.relatedTransactionUuid != null) {
      throw const PostingValidationException(
        'A refund amount, account, and category snapshot are '
        'immutable; undo a refund by deleting it.',
      );
    }
    if (edit.occurredAt != null) {
      _requireNotFuture(edit.occurredAt!, now);
    }
    if (edit.paymentChannel != null) {
      _requirePaymentChannel(edit.paymentChannel!);
    }
    return _updateRowOnly(existing, edit, now);
  }

  Future<FinancialTransaction> _editOpeningViaEdit(
    FinancialTransaction existing,
    TransactionEdit edit,
    DateTime now,
  ) async {
    final touchesPostings = edit.amount != null || edit.occurredAt != null;
    if (!touchesPostings) {
      if (edit.accountUuid != null ||
          edit.categoryId != null ||
          edit.sourceAccountUuid != null ||
          edit.destinationAccountUuid != null ||
          edit.adjustmentDirection != null ||
          edit.adjustmentReason != null ||
          edit.reportingKind != null ||
          edit.relatedTransactionUuid != null) {
        throw const PostingValidationException(
          'An opening balance has no account, category, or '
          'adjustment fields to edit.',
        );
      }
      if (edit.paymentChannel != null) {
        _requirePaymentChannel(edit.paymentChannel!);
      }
      return _updateRowOnly(existing, edit, now);
    }
    // Amount/date edits go through the opening-edit rules.
    final accountUuid = await _accountUuidForOpening(existing);
    final signed = edit.amount == null
        ? await _signedOpeningAmount(existing)
        : edit.amount!;
    // `edit.amount` for an opening edit carries the SIGNED amount,
    // matching createOpeningBalance/editOpeningBalance.
    return editOpeningBalanceLocked(
      accountUuid: accountUuid,
      existing: existing,
      signedAmount: signed,
      occurredAt: edit.occurredAt,
      description: edit.description,
      notes: edit.notes,
      now: now,
    );
  }

  Future<String> _accountUuidForOpening(FinancialTransaction opening) async {
    final postings = await _postingsForTransactionId(opening.id);
    for (final posting in postings) {
      final ledger = await _requireLedgerById(posting.ledgerAccountId);
      if (ledger.userAccountId != null) {
        return ledger.userAccountId!;
      }
    }
    throw const PostingValidationException(
      'An opening balance transaction has no account posting.',
    );
  }

  /// The signed opening amount implied by the stored postings: the
  /// stored absolute amount, signed positive when the account
  /// posting is on the account ledger's normal side.
  Future<Money> _signedOpeningAmount(FinancialTransaction opening) async {
    final postings = await _postingsForTransactionId(opening.id);
    for (final posting in postings) {
      final ledger = await _requireLedgerById(posting.ledgerAccountId);
      if (ledger.userAccountId != null) {
        final direction = ledgerDirectionFromValue(posting.direction);
        final signed = direction == ledger.normalBalance
            ? posting.amountMinorUnits
            : -posting.amountMinorUnits;
        return Money(signed, posting.currencyCode);
      }
    }
    throw const PostingValidationException(
      'An opening balance transaction has no account posting.',
    );
  }

  Future<FinancialTransaction> editOpeningBalanceLocked({
    required String accountUuid,
    required FinancialTransaction existing,
    required Money signedAmount,
    DateTime? occurredAt,
    String? description,
    String? notes,
    required DateTime now,
  }) async {
    // Shared with editOpeningBalance's guard logic, operating inside
    // the caller's transaction. The public method re-enters through
    // the same code path via _editOpeningViaEdit's transaction.
    final accountLedger = await _requireAccountLedger(accountUuid);
    if (await _hasOtherActivePostings(
      accountLedger.ledgerAccountId,
      excludeTransactionId: existing.id,
    )) {
      throw const PostingValidationException(
        'An opening balance cannot be edited once the account has '
        'other financial activity.',
      );
    }
    final openingEquity = await _requireLedgerById(openingEquityLedgerId);
    final drafts = buildOpeningBalancePostings(
      accountLedger: accountLedger,
      openingEquityLedger: openingEquity,
      signedAmountMinorUnits: signedAmount.amountMinorUnits,
      currencyCode: signedAmount.currencyCode,
      mode: ReferenceMode.inherited,
    );
    final newOccurredAt = occurredAt ?? existing.occurredAt;
    final before = _snapshotJson(existing);
    await (_database.update(
      _database.financialTransactions,
    )..where((t) => t.uuid.equals(existing.uuid))).write(
      FinancialTransactionsCompanion(
        amountMinorUnits: Value(drafts.first.amountMinorUnits),
        occurredAt: Value(newOccurredAt),
        description: description == null
            ? const Value.absent()
            : Value(description),
        notes: notes == null ? const Value.absent() : Value(notes),
        updatedAt: Value(now),
        syncRevision: Value(existing.syncRevision + 1),
        syncStatus: const Value('pending'),
      ),
    );
    await _replacePostings(existing.id, drafts, newOccurredAt);
    final updated = (await _requireTransaction(existing.uuid));
    await _insertHistoryLocked(
      transactionId: updated.id,
      changeKind: 'edited',
      beforeSnapshot: before,
      afterSnapshot: _snapshotJson(updated),
      now: now,
    );
    return updated;
  }

  Future<FinancialTransaction> _editGeneral(
    FinancialTransaction existing,
    TransactionEdit edit,
    DateTime now,
  ) async {
    final newOccurredAt = edit.occurredAt ?? existing.occurredAt;
    _requireNotFuture(newOccurredAt, now);
    if (edit.paymentChannel != null) {
      _requirePaymentChannel(edit.paymentChannel!);
    }
    final newAmount =
        edit.amount ?? Money(existing.amountMinorUnits, existing.currencyCode);
    _requirePositiveMoney(newAmount);
    if (newAmount.currencyCode != existing.currencyCode) {
      throw const PostingValidationException(
        'A transaction currency cannot change.',
      );
    }

    final activeRefunds = await _activeRefundsFor(existing.uuid);
    final refundedTotal = activeRefunds.fold<int>(
      0,
      (sum, refund) => sum + refund.amountMinorUnits,
    );
    if (newAmount.amountMinorUnits < refundedTotal) {
      throw const PostingValidationException(
        'An edit cannot take the amount below the refunded total.',
      );
    }

    final oldPostings = await _postingsForTransactionId(existing.id);
    final oldLedgerIds = oldPostings.map((p) => p.ledgerAccountId).toSet();

    List<PostingDraft> drafts;
    String? newCategoryId;
    String? newSourceAccountId;
    String? newDestinationAccountId;
    String? newAdjustmentReason;
    String? newRelatedId;

    switch (existing.kind) {
      case 'expense':
      case 'income':
        final currentAccountUuid = await _accountUuidFromPostings(oldPostings);
        final accountUuid = edit.accountUuid ?? currentAccountUuid;
        if (activeRefunds.isNotEmpty &&
            edit.accountUuid != null &&
            edit.accountUuid != currentAccountUuid) {
          throw const PostingValidationException(
            'An account-side edit is rejected while active refunds '
            'exist; delete the refunds first.',
          );
        }
        newCategoryId = edit.categoryId ?? existing.categoryId;
        if (newCategoryId == null) {
          throw PostingValidationException(
            'An ${existing.kind} transaction requires a category.',
          );
        }
        final accountLedger = await _requireAccountLedger(accountUuid);
        final side = existing.kind == 'expense'
            ? ReportingKind.expense
            : ReportingKind.income;
        final categoryLedger = await _requireCategoryLedger(
          newCategoryId,
          side,
        );
        _requireUnchangedArchivedOk(<LedgerDescriptor>[
          accountLedger,
          categoryLedger,
        ], oldLedgerIds);
        drafts = existing.kind == 'expense'
            ? buildExpensePostings(
                accountLedger: accountLedger,
                categoryLedger: categoryLedger,
                amountMinorUnits: newAmount.amountMinorUnits,
                currencyCode: newAmount.currencyCode,
                mode: ReferenceMode.inherited,
              )
            : buildIncomePostings(
                accountLedger: accountLedger,
                categoryLedger: categoryLedger,
                amountMinorUnits: newAmount.amountMinorUnits,
                currencyCode: newAmount.currencyCode,
                mode: ReferenceMode.inherited,
              );
      case 'transfer':
      case 'card_payment':
        newSourceAccountId = edit.sourceAccountUuid ?? existing.sourceAccountId;
        newDestinationAccountId =
            edit.destinationAccountUuid ?? existing.destinationAccountId;
        if (newSourceAccountId == null || newDestinationAccountId == null) {
          throw PostingValidationException(
            'A ${existing.kind} transaction requires source and '
            'destination accounts.',
          );
        }
        if (activeRefunds.isNotEmpty &&
            (edit.sourceAccountUuid != null ||
                edit.destinationAccountUuid != null)) {
          throw const PostingValidationException(
            'An account-side edit is rejected while active refunds exist.',
          );
        }
        final sourceLedger = await _requireAccountLedger(newSourceAccountId);
        final destinationLedger = await _requireAccountLedger(
          newDestinationAccountId,
        );
        _requireUnchangedArchivedOk(<LedgerDescriptor>[
          sourceLedger,
          destinationLedger,
        ], oldLedgerIds);
        drafts = buildTwoAccountPostings(
          sourceLedger: sourceLedger,
          destinationLedger: destinationLedger,
          amountMinorUnits: newAmount.amountMinorUnits,
          currencyCode: newAmount.currencyCode,
          mode: ReferenceMode.inherited,
        );
      case 'adjustment':
        final currentAccountUuid = await _accountUuidFromPostings(oldPostings);
        final accountUuid = edit.accountUuid ?? currentAccountUuid;
        newAdjustmentReason =
            edit.adjustmentReason ?? existing.adjustmentReason;
        if (newAdjustmentReason == null) {
          throw const PostingValidationException(
            'An adjustment requires an adjustmentReason.',
          );
        }
        newCategoryId = edit.clearCategoryId
            ? null
            : (edit.categoryId ?? existing.categoryId);
        final reportingKind =
            edit.reportingKind ?? await _reportingKindFromPostings(oldPostings);
        newRelatedId = edit.clearRelatedTransactionUuid
            ? null
            : (edit.relatedTransactionUuid ?? existing.relatedTransactionId);
        if (newRelatedId != null) {
          final related = await _requireTransaction(newRelatedId);
          if (related.status != 'active') {
            throw const PostingValidationException(
              'An adjustment related transaction must be active.',
            );
          }
          if (newAdjustmentReason == adjustmentReasonOpeningCorrection &&
              related.kind != 'opening_balance') {
            throw const PostingValidationException(
              'An opening_balance_correction may only relate to an '
              'opening_balance transaction.',
            );
          }
        }
        final direction =
            edit.adjustmentDirection ??
            await _directionFromPostings(oldPostings);
        final accountLedger = await _requireAccountLedger(accountUuid);
        final counterpartId = counterpartLedgerIdForAdjustment(
          adjustmentReason: newAdjustmentReason,
          categoryId: newCategoryId,
          reportingKind: reportingKind,
        );
        final counterpart = await _requireLedgerById(counterpartId);
        _requireUnchangedArchivedOk(<LedgerDescriptor>[
          accountLedger,
          counterpart,
        ], oldLedgerIds);
        drafts = buildAdjustmentPostings(
          accountLedger: accountLedger,
          counterpartLedger: counterpart,
          direction: direction,
          adjustmentReason: newAdjustmentReason,
          amountMinorUnits: newAmount.amountMinorUnits,
          currencyCode: newAmount.currencyCode,
          categoryId: newCategoryId,
          reportingKind: reportingKind,
          mode: ReferenceMode.inherited,
        );
      default:
        throw PostingValidationException(
          'Unsupported transaction kind for edit: ${existing.kind}.',
        );
    }

    // Category/related clearing: Value(null) writes NULL, while
    // Value.absent() keeps the existing value. The `clear...` edit
    // flags are the only way to express clearing.
    final Value<String?> categoryIdValue =
        existing.kind == 'adjustment' && edit.clearCategoryId
        ? const Value<String?>(null)
        : (newCategoryId == null
              ? const Value<String?>.absent()
              : Value<String?>(newCategoryId));
    final Value<String?> relatedIdValue =
        existing.kind == 'adjustment' && edit.clearRelatedTransactionUuid
        ? const Value<String?>(null)
        : (newRelatedId == null
              ? const Value<String?>.absent()
              : Value<String?>(newRelatedId));
    final before = _snapshotJson(existing);
    await (_database.update(
      _database.financialTransactions,
    )..where((t) => t.uuid.equals(existing.uuid))).write(
      FinancialTransactionsCompanion(
        categoryId: categoryIdValue,
        sourceAccountId: newSourceAccountId == null
            ? const Value.absent()
            : Value(newSourceAccountId),
        destinationAccountId: newDestinationAccountId == null
            ? const Value.absent()
            : Value(newDestinationAccountId),
        amountMinorUnits: Value(newAmount.amountMinorUnits),
        description: edit.description == null
            ? const Value.absent()
            : Value(edit.description),
        notes: edit.notes == null ? const Value.absent() : Value(edit.notes),
        paymentChannel: edit.paymentChannel == null
            ? const Value.absent()
            : Value(edit.paymentChannel!),
        occurredAt: Value(newOccurredAt),
        adjustmentReason: newAdjustmentReason == null
            ? const Value.absent()
            : Value(newAdjustmentReason),
        relatedTransactionId: relatedIdValue,
        updatedAt: Value(now),
        syncRevision: Value(existing.syncRevision + 1),
        syncStatus: const Value('pending'),
      ),
    );
    await _replacePostings(existing.id, drafts, newOccurredAt);
    final updated = (await _requireTransaction(existing.uuid));
    await _insertHistoryLocked(
      transactionId: updated.id,
      changeKind: 'edited',
      beforeSnapshot: before,
      afterSnapshot: _snapshotJson(updated),
      now: now,
    );
    return updated;
  }

  /// On edit, ledger ids already present in the old posting set are
  /// inherited references (archived allowed); any NEW ledger id must
  /// not be archived (C1). Builders run in inherited mode after this
  /// explicit split check.
  void _requireUnchangedArchivedOk(
    List<LedgerDescriptor> descriptors,
    Set<String> oldLedgerIds,
  ) {
    for (final descriptor in descriptors) {
      if (!oldLedgerIds.contains(descriptor.ledgerAccountId) &&
          descriptor.isArchived) {
        throw PostingValidationException(
          'Ledger account ${descriptor.ledgerAccountId} is archived '
          'and cannot be selected for an edited transaction.',
        );
      }
    }
  }

  Future<FinancialTransaction> _updateRowOnly(
    FinancialTransaction existing,
    TransactionEdit edit,
    DateTime now,
  ) async {
    if (edit.occurredAt != null) {
      _requireNotFuture(edit.occurredAt!, now);
    }
    final before = _snapshotJson(existing);
    await (_database.update(
      _database.financialTransactions,
    )..where((t) => t.uuid.equals(existing.uuid))).write(
      FinancialTransactionsCompanion(
        description: edit.description == null
            ? const Value.absent()
            : Value(edit.description),
        notes: edit.notes == null ? const Value.absent() : Value(edit.notes),
        paymentChannel: edit.paymentChannel == null
            ? const Value.absent()
            : Value(edit.paymentChannel!),
        occurredAt: edit.occurredAt == null
            ? const Value.absent()
            : Value(edit.occurredAt!),
        updatedAt: Value(now),
        syncRevision: Value(existing.syncRevision + 1),
        syncStatus: const Value('pending'),
      ),
    );
    final updated = (await _requireTransaction(existing.uuid));
    await _insertHistoryLocked(
      transactionId: updated.id,
      changeKind: 'edited',
      beforeSnapshot: before,
      afterSnapshot: _snapshotJson(updated),
      now: now,
    );
    return updated;
  }

  Future<FinancialTransaction> deleteTransaction(String uuid) async {
    final now = _clock();
    return _database.transaction(() async {
      final existing = await _requireTransaction(uuid);
      if (existing.status != 'active') {
        throw const PostingValidationException(
          'Only an active transaction can be deleted.',
        );
      }
      final activeRefunds = await _activeRefundsFor(uuid);
      if (activeRefunds.isNotEmpty) {
        throw const PostingValidationException(
          'An original with active refunds cannot be deleted; '
          'delete the refunds first.',
        );
      }
      if (await _activeReversalFor(uuid) != null) {
        throw const PostingValidationException(
          'An original with an active reversal cannot be deleted; '
          'delete the reversal first.',
        );
      }
      if (existing.kind == 'opening_balance') {
        final postings = await _postingsForTransactionId(existing.id);
        for (final posting in postings) {
          final ledger = await _requireLedgerById(posting.ledgerAccountId);
          if (ledger.userAccountId != null &&
              await _hasOtherActivePostings(
                ledger.ledgerAccountId,
                excludeTransactionId: existing.id,
              )) {
            throw const PostingValidationException(
              'An opening balance cannot be deleted once the account '
              'has other activity; reverse it instead.',
            );
          }
        }
      }
      return _setStatus(existing, 'deleted', 'deleted', now);
    });
  }

  Future<FinancialTransaction> restoreTransaction(String uuid) async {
    final now = _clock();
    return _database.transaction(() async {
      final existing = await _requireTransaction(uuid);
      if (existing.status != 'deleted') {
        throw const PostingValidationException(
          'Only a deleted transaction can be restored.',
        );
      }
      _requireNotFuture(existing.occurredAt, now);
      if (existing.kind == 'refund') {
        final originalUuid = existing.reversesTransactionId;
        if (originalUuid == null) {
          throw const PostingValidationException(
            'A refund requires an original transaction.',
          );
        }
        final original = await _requireTransaction(originalUuid);
        if (original.status != 'active') {
          throw const PostingValidationException(
            'A refund cannot be restored while its original is deleted.',
          );
        }
        if (await _activeReversalFor(originalUuid) != null) {
          throw const PostingValidationException(
            'A refund cannot be restored while an active reversal '
            'references its original.',
          );
        }
        final capacity = await _refundableCapacityLocked(original);
        if (existing.amountMinorUnits > capacity) {
          throw const PostingValidationException(
            'Restoring this refund would exceed the refundable capacity.',
          );
        }
      }
      if (existing.kind == 'reversal') {
        final originalUuid = existing.reversesTransactionId;
        if (originalUuid == null) {
          throw const PostingValidationException(
            'A reversal requires an original transaction.',
          );
        }
        final original = await _requireTransaction(originalUuid);
        if (original.status != 'active') {
          throw const PostingValidationException(
            'A reversal cannot be restored while its original is deleted.',
          );
        }
        if (await _activeReversalFor(originalUuid) != null) {
          throw const PostingValidationException(
            'Another active reversal already references the original.',
          );
        }
        if (await _activeRefundTotal(originalUuid) > 0) {
          throw const PostingValidationException(
            'A reversal cannot be restored while active refunds '
            'reference its original.',
          );
        }
      }
      if (existing.kind == 'opening_balance') {
        final postings = await _postingsForTransactionId(existing.id);
        for (final posting in postings) {
          final ledger = await _requireLedgerById(posting.ledgerAccountId);
          if (ledger.userAccountId != null) {
            final other = await _activeOpeningEventExcluding(
              ledger.ledgerAccountId,
              excludeTransactionId: existing.id,
            );
            if (other != null) {
              throw const PostingValidationException(
                'Another active opening balance event already exists '
                'for this account.',
              );
            }
          }
        }
      }
      return _setStatus(existing, 'active', 'restored', now);
    });
  }

  Future<FinancialTransaction> _setStatus(
    FinancialTransaction existing,
    String status,
    String changeKind,
    DateTime now,
  ) async {
    final before = _snapshotJson(existing);
    await (_database.update(
      _database.financialTransactions,
    )..where((t) => t.uuid.equals(existing.uuid))).write(
      FinancialTransactionsCompanion(
        status: Value(status),
        updatedAt: Value(now),
        syncRevision: Value(existing.syncRevision + 1),
        syncStatus: const Value('pending'),
      ),
    );
    final updated = (await _requireTransaction(existing.uuid));
    await _insertHistoryLocked(
      transactionId: updated.id,
      changeKind: changeKind,
      beforeSnapshot: before,
      afterSnapshot: _snapshotJson(updated),
      now: now,
    );
    return updated;
  }

  // -----------------------------------------------------------------
  // Reporting snapshots.
  // -----------------------------------------------------------------

  /// Loads a [ReportingSnapshot] for `[periodStart,
  /// periodEndExclusive)` inside one read transaction.
  ///
  /// Strategy (final design): ledger accounts load once, unfiltered.
  /// Three batched posting loads share one join shape and differ only
  /// in their date predicate, each with the active-status predicate:
  /// movements (`occurredAt` in the period), closing (`occurredAt`
  /// before the period end), current (no date predicate). Reversal
  /// contexts load in one batched `IN` query over the distinct
  /// `reversesTransactionId` values in the movements, with no period
  /// or status predicate on the originals. No SQL aggregation runs
  /// anywhere; pure code sums the loaded postings. The snapshot is
  /// validated (period, reversal contexts) before return.
  Future<ReportingSnapshot> loadReportingSnapshot({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) async {
    if (!periodStart.isBefore(periodEndExclusive)) {
      throw ArgumentError(
        'Reporting period requires periodStart < periodEndExclusive: '
        '$periodStart to $periodEndExclusive.',
      );
    }
    return _database.transaction(() async {
      final ledgerRows = await _database.select(_database.ledgerAccounts).get();
      final ledgers = <String, LedgerDescriptor>{
        for (final row in ledgerRows)
          row.ledgerAccountId: ledgerDescriptorOf(row),
      };

      final movements = await _loadMovements(periodStart, periodEndExclusive);
      final reversalContexts = await _loadReversalContexts(movements);
      final closingPostings = await _loadBalancePostings(
        beforeExclusive: periodEndExclusive,
      );
      final currentPostings = await _loadBalancePostings();

      final snapshot = ReportingSnapshot(
        periodStart: periodStart,
        periodEndExclusive: periodEndExclusive,
        movements: movements,
        closingPostings: closingPostings,
        currentPostings: currentPostings,
        ledgerAccounts: ledgers,
        reversalContexts: reversalContexts,
      );
      validateReversalContexts(snapshot);
      return snapshot;
    });
  }

  /// Streams reporting snapshots for a period, re-loading whenever
  /// the transactions table changes. All Stage 2 writes touch that
  /// table together with their postings, so it is the correct
  /// invalidation signal for this stage.
  Stream<ReportingSnapshot> watchReportingSnapshot({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) {
    if (!periodStart.isBefore(periodEndExclusive)) {
      throw ArgumentError(
        'Reporting period requires periodStart < periodEndExclusive: '
        '$periodStart to $periodEndExclusive.',
      );
    }
    return _database
        .select(_database.financialTransactions)
        .watch()
        .asyncMap(
          (_) => loadReportingSnapshot(
            periodStart: periodStart,
            periodEndExclusive: periodEndExclusive,
          ),
        );
  }

  Future<List<ReportingEvent>> _loadMovements(
    DateTime periodStart,
    DateTime periodEndExclusive,
  ) async {
    final transactions =
        await (_database.select(_database.financialTransactions)..where(
              (t) =>
                  t.status.equals('active') &
                  t.occurredAt.isBiggerOrEqualValue(periodStart) &
                  t.occurredAt.isSmallerThanValue(periodEndExclusive),
            ))
            .get();
    final postingsById = await _postingsByTransactionIds(
      transactions.map((t) => t.id).toList(),
    );
    return transactions
        .map((transaction) => _toReportingEvent(transaction, postingsById))
        .toList();
  }

  Future<Map<String, ReversalContext>> _loadReversalContexts(
    List<ReportingEvent> movements,
  ) async {
    final originalUuids = movements
        .where((event) => event.kind == 'reversal')
        .map((event) => event.reversesTransactionId)
        .whereType<String>()
        .toSet()
        .toList();
    if (originalUuids.isEmpty) {
      return const <String, ReversalContext>{};
    }
    final originals = await (_database.select(
      _database.financialTransactions,
    )..where((t) => t.uuid.isIn(originalUuids))).get();
    final postingsById = await _postingsByTransactionIds(
      originals.map((t) => t.id).toList(),
    );
    final contexts = <String, ReversalContext>{};
    for (final original in originals) {
      final postings = postingsById[original.id] ?? const <Posting>[];
      contexts[original.uuid] = ReversalContext(
        originalTransactionUuid: original.uuid,
        originalKind: original.kind,
        originalAdjustmentReason: original.adjustmentReason,
        originalCategoryId: original.categoryId,
        originalOccurredAt: original.occurredAt,
        originalStatus: original.status,
        originalAmountMinorUnits: original.amountMinorUnits,
        originalCurrencyCode: original.currencyCode,
        originalPostings: postings
            .map(
              (posting) => ReportingPosting(
                transactionUuid: original.uuid,
                ledgerAccountId: posting.ledgerAccountId,
                direction: ledgerDirectionFromValue(posting.direction),
                amountMinorUnits: posting.amountMinorUnits,
                currencyCode: posting.currencyCode,
                occurredAt: original.occurredAt,
              ),
            )
            .toList(),
      );
    }
    return contexts;
  }

  /// Loads balance postings for active transactions, optionally
  /// restricted to `occurredAt` before [beforeExclusive]. A null
  /// [beforeExclusive] loads every active posting (current balances).
  Future<List<ReportingPosting>> _loadBalancePostings({
    DateTime? beforeExclusive,
  }) async {
    final select = _database.select(_database.financialTransactions)
      ..where((t) => t.status.equals('active'));
    if (beforeExclusive != null) {
      select.where((t) => t.occurredAt.isSmallerThanValue(beforeExclusive));
    }
    final transactions = await select.get();
    final byUuid = <int, FinancialTransaction>{
      for (final transaction in transactions) transaction.id: transaction,
    };
    final postingsById = await _postingsByTransactionIds(byUuid.keys.toList());
    final result = <ReportingPosting>[];
    for (final entry in postingsById.entries) {
      final transaction = byUuid[entry.key]!;
      for (final posting in entry.value) {
        result.add(
          ReportingPosting(
            transactionUuid: transaction.uuid,
            ledgerAccountId: posting.ledgerAccountId,
            direction: ledgerDirectionFromValue(posting.direction),
            amountMinorUnits: posting.amountMinorUnits,
            currencyCode: posting.currencyCode,
            occurredAt: transaction.occurredAt,
          ),
        );
      }
    }
    return result;
  }

  ReportingEvent _toReportingEvent(
    FinancialTransaction transaction,
    Map<int, List<Posting>> postingsById,
  ) {
    final postings = postingsById[transaction.id] ?? const <Posting>[];
    return ReportingEvent(
      transactionUuid: transaction.uuid,
      kind: transaction.kind,
      categoryId: transaction.categoryId,
      adjustmentReason: transaction.adjustmentReason,
      amountMinorUnits: transaction.amountMinorUnits,
      currencyCode: transaction.currencyCode,
      occurredAt: transaction.occurredAt,
      status: transaction.status,
      reversesTransactionId: transaction.reversesTransactionId,
      postings: postings
          .map(
            (posting) => ReportingPosting(
              transactionUuid: transaction.uuid,
              ledgerAccountId: posting.ledgerAccountId,
              direction: ledgerDirectionFromValue(posting.direction),
              amountMinorUnits: posting.amountMinorUnits,
              currencyCode: posting.currencyCode,
              occurredAt: transaction.occurredAt,
            ),
          )
          .toList(),
    );
  }

  Future<Map<int, List<Posting>>> _postingsByTransactionIds(
    List<int> transactionIds,
  ) async {
    if (transactionIds.isEmpty) {
      return const <int, List<Posting>>{};
    }
    final postings =
        await (_database.select(_database.postings)
              ..where((t) => t.transactionId.isIn(transactionIds))
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();
    final grouped = <int, List<Posting>>{};
    for (final posting in postings) {
      (grouped[posting.transactionId] ??= <Posting>[]).add(posting);
    }
    return grouped;
  }

  // -----------------------------------------------------------------
  // Internal helpers. All assume they run inside a transaction when
  // called from a mutating method; read helpers are also safe alone.
  // -----------------------------------------------------------------

  void _requireNotFuture(DateTime occurredAt, DateTime now) {
    if (occurredAt.toUtc().isAfter(now.toUtc())) {
      throw const PostingValidationException(
        'A transaction must not be dated in the future.',
      );
    }
  }

  void _requirePaymentChannel(String paymentChannel) {
    if (!paymentChannels.contains(paymentChannel)) {
      throw PostingValidationException(
        'Unknown payment channel: $paymentChannel.',
      );
    }
  }

  void _requirePositiveMoney(Money amount) {
    if (amount.currencyCode != 'INR') {
      throw const PostingValidationException('V1 transactions are INR only.');
    }
    if (!amount.isPositive) {
      throw const PostingValidationException(
        'Transaction amounts must be strictly positive.',
      );
    }
  }

  Future<FinancialTransaction?> _transactionByUuid(String uuid) async {
    return (_database.select(
      _database.financialTransactions,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<FinancialTransaction> _requireTransaction(String uuid) async {
    final transaction = await _transactionByUuid(uuid);
    if (transaction == null) {
      throw PostingValidationException('Unknown transaction: $uuid.');
    }
    return transaction;
  }

  Future<List<Posting>> _postingsForTransactionId(int id) async {
    return (_database.select(_database.postings)
          ..where((t) => t.transactionId.equals(id))
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();
  }

  Future<Account> _requireAccount(String accountUuid) async {
    final account = await (_database.select(
      _database.accounts,
    )..where((t) => t.uuid.equals(accountUuid))).getSingleOrNull();
    if (account == null) {
      throw PostingValidationException('Unknown account: $accountUuid.');
    }
    return account;
  }

  Future<LedgerDescriptor> _requireAccountLedger(String accountUuid) async {
    await _requireAccount(accountUuid);
    final row = await (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.userAccountId.equals(accountUuid))).getSingleOrNull();
    if (row == null) {
      throw PostingValidationException(
        'Account $accountUuid has no ledger account.',
      );
    }
    return ledgerDescriptorOf(row);
  }

  Future<LedgerDescriptor> _requireCategoryLedger(
    String categoryId,
    ReportingKind side,
  ) async {
    final category = await (_database.select(
      _database.categories,
    )..where((t) => t.categoryId.equals(categoryId))).getSingleOrNull();
    if (category == null) {
      throw PostingValidationException('Unknown category: $categoryId.');
    }
    final ledgerId = side == ReportingKind.expense
        ? 'expense:$categoryId'
        : 'income:$categoryId';
    final row = await (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.ledgerAccountId.equals(ledgerId))).getSingleOrNull();
    if (row == null) {
      throw PostingValidationException(
        'Category $categoryId has no ${side.name} ledger account.',
      );
    }
    return ledgerDescriptorOf(row);
  }

  Future<LedgerDescriptor> _requireLedgerById(String ledgerAccountId) async {
    final row =
        await (_database.select(_database.ledgerAccounts)
              ..where((t) => t.ledgerAccountId.equals(ledgerAccountId)))
            .getSingleOrNull();
    if (row == null) {
      throw PostingValidationException(
        'Unknown ledger account: $ledgerAccountId.',
      );
    }
    return ledgerDescriptorOf(row);
  }

  Future<LedgerAccount> _requireLedgerRowById(String ledgerAccountId) async {
    final row =
        await (_database.select(_database.ledgerAccounts)
              ..where((t) => t.ledgerAccountId.equals(ledgerAccountId)))
            .getSingleOrNull();
    if (row == null) {
      throw PostingValidationException(
        'Unknown ledger account: $ledgerAccountId.',
      );
    }
    return row;
  }

  Future<Map<String, LedgerDescriptor>> _descriptorsForPostings(
    List<Posting> postings,
  ) async {
    final ids = postings.map((p) => p.ledgerAccountId).toSet().toList();
    final rows = await (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.ledgerAccountId.isIn(ids))).get();
    final descriptors = <String, LedgerDescriptor>{
      for (final row in rows) row.ledgerAccountId: ledgerDescriptorOf(row),
    };
    for (final id in ids) {
      if (!descriptors.containsKey(id)) {
        throw PostingValidationException('Unknown ledger account: $id.');
      }
    }
    return descriptors;
  }

  Future<List<FinancialTransaction>> _activeRefundsFor(
    String originalUuid,
  ) async {
    return (_database.select(_database.financialTransactions)..where(
          (t) =>
              t.kind.equals('refund') &
              t.reversesTransactionId.equals(originalUuid) &
              t.status.equals('active'),
        ))
        .get();
  }

  Future<int> _activeRefundTotal(String originalUuid) async {
    final refunds = await _activeRefundsFor(originalUuid);
    return refunds.fold<int>(0, (sum, refund) => sum + refund.amountMinorUnits);
  }

  Future<FinancialTransaction?> _activeReversalFor(String originalUuid) async {
    return (_database.select(_database.financialTransactions)..where(
          (t) =>
              t.kind.equals('reversal') &
              t.reversesTransactionId.equals(originalUuid) &
              t.status.equals('active'),
        ))
        .getSingleOrNull();
  }

  /// Refundable capacity for [original] recomputed from current
  /// active rows (callers hold the database transaction).
  Future<int> _refundableCapacityLocked(FinancialTransaction original) async {
    if (await _activeReversalFor(original.uuid) != null) {
      return 0;
    }
    final remaining =
        original.amountMinorUnits - await _activeRefundTotal(original.uuid);
    return remaining < 0 ? 0 : remaining;
  }

  Future<bool> _hasActivePostings(String ledgerAccountId) async {
    final postings = await (_database.select(
      _database.postings,
    )..where((t) => t.ledgerAccountId.equals(ledgerAccountId))).get();
    if (postings.isEmpty) {
      return false;
    }
    final transactionIds = postings
        .map((p) => p.transactionId)
        .toSet()
        .toList();
    final transactions =
        await (_database.select(_database.financialTransactions)..where(
              (t) => t.id.isIn(transactionIds) & t.status.equals('active'),
            ))
            .get();
    return transactions.isNotEmpty;
  }

  Future<bool> _hasOtherActivePostings(
    String ledgerAccountId, {
    required int excludeTransactionId,
  }) async {
    final postings = await (_database.select(
      _database.postings,
    )..where((t) => t.ledgerAccountId.equals(ledgerAccountId))).get();
    for (final posting in postings) {
      if (posting.transactionId == excludeTransactionId) {
        continue;
      }
      final transaction = await (_database.select(
        _database.financialTransactions,
      )..where((t) => t.id.equals(posting.transactionId))).getSingleOrNull();
      if (transaction?.status == 'active') {
        return true;
      }
    }
    return false;
  }

  Future<bool> _hasActiveOpeningEvent(String ledgerAccountId) async {
    return (await _activeOpeningEvent(ledgerAccountId)) != null;
  }

  Future<FinancialTransaction?> _activeOpeningEvent(
    String ledgerAccountId,
  ) async {
    return _activeOpeningEventExcluding(
      ledgerAccountId,
      excludeTransactionId: null,
    );
  }

  Future<FinancialTransaction?> _activeOpeningEventExcluding(
    String ledgerAccountId, {
    required int? excludeTransactionId,
  }) async {
    final openings =
        await (_database.select(_database.financialTransactions)..where(
              (t) =>
                  t.kind.equals('opening_balance') & t.status.equals('active'),
            ))
            .get();
    for (final opening in openings) {
      if (opening.id == excludeTransactionId) {
        continue;
      }
      final postings = await _postingsForTransactionId(opening.id);
      if (postings.any((p) => p.ledgerAccountId == ledgerAccountId)) {
        return opening;
      }
    }
    return null;
  }

  Future<String> _accountUuidFromPostings(List<Posting> postings) async {
    for (final posting in postings) {
      final ledger = await _requireLedgerRowById(posting.ledgerAccountId);
      if (ledger.userAccountId != null) {
        return ledger.userAccountId!;
      }
    }
    throw const PostingValidationException(
      'The transaction has no account posting.',
    );
  }

  /// Derives the reporting side of an existing categorised
  /// adjustment from its counterpart ledger row kind (resolved
  /// through the ledger table, never from the ledger id string).
  /// Returns null when the adjustment has no category ledger.
  Future<ReportingKind?> _reportingKindFromPostings(
    List<Posting> postings,
  ) async {
    for (final posting in postings) {
      final ledger = await _requireLedgerById(posting.ledgerAccountId);
      if (ledger.kind == ledgerKindSystemExpense) {
        return ReportingKind.expense;
      }
      if (ledger.kind == ledgerKindSystemIncome) {
        return ReportingKind.income;
      }
    }
    return null;
  }

  /// Rebuilds the stored adjustment direction from the current
  /// postings: the account posting sits on its ledger's normal side
  /// for an increase, on the opposite side for a decrease.
  Future<AdjustmentDirection> _directionFromPostings(
    List<Posting> postings,
  ) async {
    for (final posting in postings) {
      final ledger = await _requireLedgerById(posting.ledgerAccountId);
      if (!ledger.isUserLedger) {
        continue;
      }
      final direction = ledgerDirectionFromValue(posting.direction);
      return direction == ledger.normalBalance
          ? AdjustmentDirection.increase
          : AdjustmentDirection.decrease;
    }
    throw const PostingValidationException(
      'An adjustment has no account posting to derive its direction from.',
    );
  }

  Future<FinancialTransaction> _insertTransactionLocked({
    required String kind,
    String? categoryId,
    String? reversesTransactionId,
    String? relatedTransactionId,
    String? sourceAccountId,
    String? destinationAccountId,
    String? refundAccountId,
    required int amountMinorUnits,
    required String currencyCode,
    String? description,
    String? notes,
    required String paymentChannel,
    required DateTime occurredAt,
    String source = 'manual',
    String? adjustmentReason,
    required List<PostingDraft> drafts,
    required DateTime now,
  }) async {
    final transactionId = await _database
        .into(_database.financialTransactions)
        .insert(
          FinancialTransactionsCompanion.insert(
            uuid: _newUuid(),
            kind: kind,
            categoryId: categoryId == null
                ? const Value.absent()
                : Value(categoryId),
            reversesTransactionId: reversesTransactionId == null
                ? const Value.absent()
                : Value(reversesTransactionId),
            relatedTransactionId: relatedTransactionId == null
                ? const Value.absent()
                : Value(relatedTransactionId),
            sourceAccountId: sourceAccountId == null
                ? const Value.absent()
                : Value(sourceAccountId),
            destinationAccountId: destinationAccountId == null
                ? const Value.absent()
                : Value(destinationAccountId),
            refundAccountId: refundAccountId == null
                ? const Value.absent()
                : Value(refundAccountId),
            amountMinorUnits: amountMinorUnits,
            currencyCode: Value(currencyCode),
            description: description == null
                ? const Value.absent()
                : Value(description),
            notes: notes == null ? const Value.absent() : Value(notes),
            paymentChannel: paymentChannel,
            occurredAt: occurredAt,
            status: 'active',
            source: source,
            adjustmentReason: adjustmentReason == null
                ? const Value.absent()
                : Value(adjustmentReason),
            createdAt: now,
            updatedAt: now,
            syncStatus: 'pending',
          ),
        );
    for (final draft in drafts) {
      await _database
          .into(_database.postings)
          .insert(
            PostingsCompanion.insert(
              uuid: _newUuid(),
              transactionId: transactionId,
              ledgerAccountId: draft.ledgerAccountId,
              direction: draft.direction.value,
              amountMinorUnits: draft.amountMinorUnits,
              currencyCode: Value(draft.currencyCode),
              postingDate: occurredAt,
            ),
          );
    }
    final inserted = await (_database.select(
      _database.financialTransactions,
    )..where((t) => t.id.equals(transactionId))).getSingle();
    await _insertHistoryLocked(
      transactionId: transactionId,
      changeKind: 'created',
      afterSnapshot: _snapshotJson(inserted),
      now: now,
    );
    return inserted;
  }

  Future<void> _replacePostings(
    int transactionId,
    List<PostingDraft> drafts,
    DateTime postingDate,
  ) async {
    await (_database.delete(
      _database.postings,
    )..where((t) => t.transactionId.equals(transactionId))).go();
    for (final draft in drafts) {
      await _database
          .into(_database.postings)
          .insert(
            PostingsCompanion.insert(
              uuid: _newUuid(),
              transactionId: transactionId,
              ledgerAccountId: draft.ledgerAccountId,
              direction: draft.direction.value,
              amountMinorUnits: draft.amountMinorUnits,
              currencyCode: Value(draft.currencyCode),
              postingDate: postingDate,
            ),
          );
    }
  }

  Future<void> _insertHistoryLocked({
    required int transactionId,
    required String changeKind,
    String? beforeSnapshot,
    String? afterSnapshot,
    required DateTime now,
  }) async {
    await _database
        .into(_database.transactionHistory)
        .insert(
          TransactionHistoryCompanion.insert(
            uuid: _newUuid(),
            transactionId: transactionId,
            changedAt: now,
            changeKind: changeKind,
            beforeSnapshot: beforeSnapshot == null
                ? const Value.absent()
                : Value(beforeSnapshot),
            afterSnapshot: afterSnapshot == null
                ? const Value.absent()
                : Value(afterSnapshot),
          ),
        );
  }

  String _snapshotJson(FinancialTransaction row) {
    return jsonEncode(<String, Object?>{
      'uuid': row.uuid,
      'kind': row.kind,
      'categoryId': row.categoryId,
      'reversesTransactionId': row.reversesTransactionId,
      'relatedTransactionId': row.relatedTransactionId,
      'sourceAccountId': row.sourceAccountId,
      'destinationAccountId': row.destinationAccountId,
      'refundAccountId': row.refundAccountId,
      'amountMinorUnits': row.amountMinorUnits,
      'currencyCode': row.currencyCode,
      'description': row.description,
      'notes': row.notes,
      'paymentChannel': row.paymentChannel,
      'occurredAt': row.occurredAt.toUtc().toIso8601String(),
      'status': row.status,
      'source': row.source,
      'adjustmentReason': row.adjustmentReason,
      'syncRevision': row.syncRevision,
    });
  }
}
