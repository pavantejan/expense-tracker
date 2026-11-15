// Transaction -> V2 sheet row mapping (blueprint sections 8.2, 8.3).
//
// Pure Dart. The data layer resolves account/category names and the
// opening-balance direction into a [SheetV2Source]; this file only
// applies the per-kind column rules, including the reversal
// swap/invert table. One transaction always maps to exactly one row.

import 'sheets_v2_contract.dart';

/// An account identity as written to Sheets: stable id plus display
/// name. Names are for readability only; ids are the relationship.
class SheetV2AccountRef {
  const SheetV2AccountRef({required this.id, required this.name});

  final String id;
  final String name;
}

/// Everything the mapper needs about one local transaction.
///
/// [account] is the transaction's own account side: the account of an
/// expense/income/adjustment/opening balance (resolved from postings).
/// [sourceAccount]/[destinationAccount] are set for transfers and card
/// payments; [refundAccount] for refunds. [original] is required for a
/// reversal and describes the reversed transaction.
class SheetV2Source {
  const SheetV2Source({
    required this.uuid,
    required this.kind,
    required this.occurredAt,
    required this.amountMinorUnits,
    required this.currencyCode,
    required this.paymentChannel,
    required this.source,
    required this.updatedAt,
    required this.deleted,
    this.categoryId,
    this.categoryName,
    this.description,
    this.notes,
    this.account,
    this.sourceAccount,
    this.destinationAccount,
    this.refundAccount,
    this.balanceDirection,
    this.originalUuid,
    this.relatedUuid,
    this.original,
    this.cardId = '',
    this.merchant = '',
    this.tags = '',
  });

  final String uuid;
  final String kind;
  final DateTime occurredAt;
  final int amountMinorUnits;
  final String currencyCode;
  final String paymentChannel;
  final String source;
  final DateTime updatedAt;
  final bool deleted;
  final String? categoryId;
  final String? categoryName;
  final String? description;
  final String? notes;
  final SheetV2AccountRef? account;
  final SheetV2AccountRef? sourceAccount;
  final SheetV2AccountRef? destinationAccount;
  final SheetV2AccountRef? refundAccount;
  final SheetBalanceDirection? balanceDirection;
  final String? originalUuid;
  final String? relatedUuid;
  final SheetV2Source? original;
  final String cardId;
  final String merchant;
  final String tags;

  /// Year worksheet the row belongs to (device-local date).
  int get year => occurredAt.toLocal().year;
}

/// A transaction whose stored data cannot be expressed as a V2 row
/// (missing required account/original data). The row stays pending.
class SheetV2MappingException implements Exception {
  const SheetV2MappingException(this.message);

  final String message;

  @override
  String toString() => 'SheetV2MappingException: $message';
}

String sheetDateText(DateTime occurredAt) {
  final local = occurredAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

SheetV2AccountRef _require(SheetV2AccountRef? ref, String what, String uuid) {
  if (ref == null) {
    throw SheetV2MappingException('$what is missing for transaction $uuid.');
  }
  return ref;
}

/// Maps [source] to its sheet row. Throws
/// [SheetAmountOutOfRangeException] for an amount above the Sheets
/// limit and [SheetV2MappingException] for incomplete data.
SheetV2Row mapToSheetV2Row(SheetV2Source source, {int? rowIndex}) {
  final label = sheetKindLabelFor(source.kind);
  final amount = sheetAmountFromMinorUnits(
    source.amountMinorUnits,
    currencyCode: source.currencyCode,
  );
  final fields = _AccountAndCategoryFields.forSource(source);
  return SheetV2Row(
    dateText: sheetDateText(source.occurredAt),
    type: label,
    category: fields.categoryName,
    description: source.description ?? '',
    amount: amount,
    uuid: source.uuid,
    paymentMethod: source.paymentChannel,
    notes: source.notes ?? '',
    updatedAt: source.updatedAt.toUtc().toIso8601String(),
    deleted: source.deleted,
    kind: label,
    categoryId: fields.categoryId,
    accountId: fields.accountId,
    account: fields.accountName,
    fromAccountId: fields.fromAccountId,
    fromAccount: fields.fromAccountName,
    toAccountId: fields.toAccountId,
    toAccount: fields.toAccountName,
    cardId: fields.cardId,
    merchant: fields.merchant,
    tags: fields.tags,
    originalUuid: source.kind == 'refund' || source.kind == 'reversal'
        ? (source.originalUuid ?? '')
        : '',
    relatedUuid: source.kind == 'adjustment' ? (source.relatedUuid ?? '') : '',
    source: source.source,
    balanceDirection: fields.balanceDirection,
    rowIndex: rowIndex,
  );
}

/// Columns C, L-U and Y, which depend on the kind (and, for a
/// reversal, on the original's kind).
class _AccountAndCategoryFields {
  const _AccountAndCategoryFields({
    this.categoryName = '',
    this.categoryId = '',
    this.accountId = '',
    this.accountName = '',
    this.fromAccountId = '',
    this.fromAccountName = '',
    this.toAccountId = '',
    this.toAccountName = '',
    this.cardId = '',
    this.merchant = '',
    this.tags = '',
    this.balanceDirection = '',
  });

  final String categoryName;
  final String categoryId;
  final String accountId;
  final String accountName;
  final String fromAccountId;
  final String fromAccountName;
  final String toAccountId;
  final String toAccountName;
  final String cardId;
  final String merchant;
  final String tags;
  final String balanceDirection;

  static _AccountAndCategoryFields forSource(SheetV2Source s) {
    switch (s.kind) {
      case 'expense':
      case 'income':
      case 'adjustment':
        final account = _require(s.account, 'Account', s.uuid);
        return _AccountAndCategoryFields(
          categoryName: s.categoryName ?? '',
          categoryId: s.categoryId ?? '',
          accountId: account.id,
          accountName: account.name,
          cardId: s.cardId,
          merchant: s.merchant,
          tags: s.tags,
        );
      case 'transfer':
      case 'card_payment':
        final from = _require(s.sourceAccount, 'Source account', s.uuid);
        final to = _require(
          s.destinationAccount,
          'Destination account',
          s.uuid,
        );
        return _AccountAndCategoryFields(
          accountId: to.id,
          accountName: to.name,
          fromAccountId: from.id,
          fromAccountName: from.name,
          toAccountId: to.id,
          toAccountName: to.name,
          cardId: s.kind == 'card_payment' ? s.cardId : '',
          merchant: s.merchant,
          tags: s.tags,
        );
      case 'refund':
        final refundAccount = _require(
          s.refundAccount,
          'Refund account',
          s.uuid,
        );
        return _AccountAndCategoryFields(
          categoryName: s.categoryName ?? '',
          categoryId: s.categoryId ?? '',
          accountId: refundAccount.id,
          accountName: refundAccount.name,
          cardId: s.cardId,
          merchant: s.merchant,
          tags: s.tags,
        );
      case 'opening_balance':
        final account = _require(s.account, 'Account', s.uuid);
        final direction = s.balanceDirection;
        if (direction == null) {
          throw SheetV2MappingException(
            'Balance direction is missing for opening balance ${s.uuid}.',
          );
        }
        return _AccountAndCategoryFields(
          accountId: account.id,
          accountName: account.name,
          merchant: s.merchant,
          tags: s.tags,
          balanceDirection: direction.value,
        );
      case 'reversal':
        return _forReversal(s);
    }
    throw ArgumentError('Unknown transaction kind: ${s.kind}');
  }

  /// Reversal mapping table (blueprint section 8.3): money-movement
  /// fields describe the reversed movement; Merchant/Tags come from
  /// the original row.
  static _AccountAndCategoryFields _forReversal(SheetV2Source s) {
    final original = s.original;
    if (original == null) {
      throw SheetV2MappingException(
        'Original transaction is missing for reversal ${s.uuid}.',
      );
    }
    if (original.kind == 'reversal') {
      throw SheetV2MappingException(
        'Reversal ${s.uuid} cannot reverse another reversal.',
      );
    }
    final o = forSource(original);
    switch (original.kind) {
      case 'transfer':
      case 'card_payment':
        return _AccountAndCategoryFields(
          accountId: o.fromAccountId,
          accountName: o.fromAccountName,
          fromAccountId: o.toAccountId,
          fromAccountName: o.toAccountName,
          toAccountId: o.fromAccountId,
          toAccountName: o.fromAccountName,
          cardId: o.cardId,
          merchant: o.merchant,
          tags: o.tags,
        );
      case 'opening_balance':
        return _AccountAndCategoryFields(
          accountId: o.accountId,
          accountName: o.accountName,
          merchant: o.merchant,
          tags: o.tags,
          balanceDirection: original.balanceDirection!.inverted.value,
        );
      default:
        // Expense, income, refund, adjustment: copied from the
        // original row; BalanceDirection stays empty.
        return _AccountAndCategoryFields(
          categoryName: o.categoryName,
          categoryId: o.categoryId,
          accountId: o.accountId,
          accountName: o.accountName,
          fromAccountId: o.fromAccountId,
          fromAccountName: o.fromAccountName,
          toAccountId: o.toAccountId,
          toAccountName: o.toAccountName,
          cardId: o.cardId,
          merchant: o.merchant,
          tags: o.tags,
        );
    }
  }
}
