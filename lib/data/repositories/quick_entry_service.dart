// Fast entry orchestration (Module 2): one atomic save covering the
// financial transaction, its merchant and tags, the merchant's learned
// category, and template usage; plus smart defaults for the add form.
// Posting rules stay in FinancialTransactionRepository.

import 'package:drift/drift.dart';

import '../../core/domain/money.dart';
import '../database/v2/app_database_v2.dart';
import 'account_repository.dart';
import 'financial_transaction_repository.dart';
import 'merchant_tag_repository.dart';
import 'template_repository.dart';

enum EntryKind { expense, income, transfer }

/// Everything the add form collects.
class EntryDraft {
  const EntryDraft({
    required this.kind,
    required this.amount,
    required this.occurredAt,
    required this.paymentChannel,
    this.accountUuid,
    this.fromAccountUuid,
    this.toAccountUuid,
    this.categoryId,
    this.description,
    this.notes,
    this.merchantName,
    this.tagNames = const [],
    this.templateUuid,
  });

  final EntryKind kind;
  final Money amount;
  final DateTime occurredAt;
  final String paymentChannel;
  final String? accountUuid;
  final String? fromAccountUuid;
  final String? toAccountUuid;
  final String? categoryId;
  final String? description;
  final String? notes;
  final String? merchantName;
  final List<String> tagNames;

  /// Set when the form was filled from a template (`source = template`).
  final String? templateUuid;
}

/// Pre-filled values for a new entry, from the latest similar one.
class EntryDefaults {
  const EntryDefaults({
    this.accountUuid,
    this.fromAccountUuid,
    this.toAccountUuid,
    this.categoryId,
    this.paymentChannel,
  });

  final String? accountUuid;
  final String? fromAccountUuid;
  final String? toAccountUuid;
  final String? categoryId;
  final String? paymentChannel;
}

class QuickEntryService {
  QuickEntryService(
    this._database,
    this._transactions,
    this._accounts,
    this._merchantsTags,
    this._templates,
  );

  final AppDatabaseV2 _database;
  final FinancialTransactionRepository _transactions;
  final AccountRepository _accounts;
  final MerchantTagRepository _merchantsTags;
  final TemplateRepository _templates;

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Creates the transaction and everything attached to it, atomically.
  /// A transfer to a credit-card account is saved as a card payment.
  Future<FinancialTransaction> create(EntryDraft draft) {
    return _database.transaction(() async {
      final source = draft.templateUuid == null ? 'manual' : 'template';
      final description = _clean(draft.description);
      final notes = _clean(draft.notes);
      late FinancialTransaction created;
      switch (draft.kind) {
        case EntryKind.expense:
          created = await _transactions.createExpense(
            accountUuid: draft.accountUuid!,
            categoryId: draft.categoryId!,
            amount: draft.amount,
            occurredAt: draft.occurredAt,
            paymentChannel: draft.paymentChannel,
            description: description,
            notes: notes,
            source: source,
          );
        case EntryKind.income:
          created = await _transactions.createIncome(
            accountUuid: draft.accountUuid!,
            categoryId: draft.categoryId!,
            amount: draft.amount,
            occurredAt: draft.occurredAt,
            paymentChannel: draft.paymentChannel,
            description: description,
            notes: notes,
            source: source,
          );
        case EntryKind.transfer:
          final destination = await _accounts.getAccountByUuid(
            draft.toAccountUuid!,
          );
          if (destination?.kind == 'credit_card_liability') {
            created = await _transactions.createCardPayment(
              sourceAccountUuid: draft.fromAccountUuid!,
              cardAccountUuid: draft.toAccountUuid!,
              amount: draft.amount,
              occurredAt: draft.occurredAt,
              paymentChannel: draft.paymentChannel,
              description: description,
              notes: notes,
              source: source,
            );
          } else {
            created = await _transactions.createTransfer(
              sourceAccountUuid: draft.fromAccountUuid!,
              destinationAccountUuid: draft.toAccountUuid!,
              amount: draft.amount,
              occurredAt: draft.occurredAt,
              paymentChannel: draft.paymentChannel,
              description: description,
              notes: notes,
              source: source,
            );
          }
      }
      await _attach(
        created.uuid,
        merchantName: draft.merchantName,
        tagNames: draft.tagNames,
        categoryId: draft.categoryId,
        recordEdit: false,
      );
      final templateUuid = draft.templateUuid;
      if (templateUuid != null) {
        await _templates.markUsed(templateUuid);
      }
      return (await _transactions.getTransactionByUuid(created.uuid))!;
    });
  }

  /// Applies a ledger edit and the merchant/tag change in one database
  /// transaction.
  Future<void> edit(
    String uuid,
    TransactionEdit edit, {
    required String? merchantName,
    required List<String> tagNames,
  }) {
    return _database.transaction(() async {
      final updated = await _transactions.editTransaction(uuid, edit);
      await _attach(
        uuid,
        merchantName: merchantName,
        tagNames: tagNames,
        categoryId: updated.categoryId,
        recordEdit: true,
      );
    });
  }

  Future<void> _attach(
    String uuid, {
    required String? merchantName,
    required List<String> tagNames,
    required String? categoryId,
    required bool recordEdit,
  }) async {
    String? merchantUuid;
    final name = _clean(merchantName);
    if (name != null) {
      final merchant = await _merchantsTags.findOrCreateMerchant(name);
      merchantUuid = merchant.uuid;
    }
    final tagIds = <int>{};
    for (final tagName in tagNames) {
      if (_clean(tagName) != null) {
        tagIds.add((await _merchantsTags.findOrCreateTag(tagName)).id);
      }
    }
    final before = await _transactions.getTransactionByUuid(uuid);
    await _transactions.setMerchantAndTags(
      uuid,
      merchantUuid: merchantUuid,
      tagIds: tagIds,
      recordEdit: recordEdit,
    );
    if (merchantUuid != null &&
        (!recordEdit || before?.merchantId != merchantUuid)) {
      await _merchantsTags.recordMerchantUse(
        merchantUuid,
        categoryId: categoryId,
      );
    } else if (merchantUuid != null && categoryId != null) {
      await _merchantsTags.setMerchantDefaultCategory(merchantUuid, categoryId);
    }
  }

  /// Smart defaults: the latest active transaction of the same kind
  /// supplies account(s), category and payment method.
  Future<EntryDefaults> defaultsFor(EntryKind kind) async {
    final kinds = switch (kind) {
      EntryKind.expense => const ['expense'],
      EntryKind.income => const ['income'],
      EntryKind.transfer => const ['transfer', 'card_payment'],
    };
    final latest =
        await (_database.select(_database.financialTransactions)
              ..where((t) => t.kind.isIn(kinds) & t.status.equals('active'))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (latest == null) {
      return const EntryDefaults();
    }
    String? accountUuid;
    if (kind != EntryKind.transfer) {
      final postings = await _transactions.getPostingsForTransaction(
        latest.uuid,
      );
      for (final posting in postings) {
        final ledger =
            await (_database.select(_database.ledgerAccounts)..where(
                  (t) => t.ledgerAccountId.equals(posting.ledgerAccountId),
                ))
                .getSingleOrNull();
        if (ledger?.userAccountId != null) {
          accountUuid = ledger!.userAccountId;
          break;
        }
      }
    }
    return EntryDefaults(
      accountUuid: accountUuid,
      fromAccountUuid: latest.sourceAccountId,
      toAccountUuid: latest.destinationAccountId,
      categoryId: latest.categoryId,
      paymentChannel: latest.paymentChannel,
    );
  }

  /// The category a merchant was last used with, if any.
  Future<String?> suggestCategoryForMerchant(String name) async {
    final trimmed = _clean(name);
    if (trimmed == null) {
      return null;
    }
    return (await _merchantsTags.merchantByName(trimmed))?.defaultCategoryId;
  }
}
