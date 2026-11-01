// V2 account repository (blueprint sections 5.2, 6.3, 6.4).
//
// V2-only: this repository touches only the V2 tables. Production
// startup still uses the old database in Stage 2; the coordinated
// Stage 5 cutover switches it. No V1 table, repository, or provider
// is imported or modified here.
//
// Account creation follows the blueprint insertion order inside one
// database transaction: Account row, LedgerAccount row, optional
// opening-balance transaction, its postings, history row. A zero
// opening balance creates no event and no postings. Classification
// changes and archival mirror onto the ledger row in the same
// transaction. Balances are never stored: they derive from postings
// through the reporting layer.

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/ledger/posting_rules.dart';
import '../../core/domain/money.dart';
import '../database/v2/app_database_v2.dart';
import '../database/v2/ledger_descriptors.dart';

/// Account kinds, as stored on `Accounts.kind`.
const Set<String> accountKinds = <String>{
  'bank',
  'cash',
  'wallet',
  'other_asset',
  'credit_card_liability',
};

/// The payment-channel label stored on opening-balance events. The
/// column is required on every transaction row and has no
/// opening-specific value; the bank label is the neutral placeholder.
/// Sheets mapping (Stage 3) treats opening rows by kind, never by
/// this label.
const String openingBalancePaymentChannel = 'Bank Transfer';

class AccountRepository {
  AccountRepository(
    this._database, {
    DateTime Function()? clock,
    String Function()? uuidGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newUuid = uuidGenerator ?? (() => const Uuid().v4());

  final AppDatabaseV2 _database;
  final DateTime Function() _clock;
  final String Function() _newUuid;

  /// Creates an account with its 1:1 ledger account and, when
  /// [openingBalance] is non-zero, one `opening_balance` event.
  ///
  /// [openingBalance] is a signed amount: positive increases the
  /// account on its normal-balance side, negative decreases it (see
  /// [buildOpeningBalancePostings]). Zero or absent means no event.
  /// [openingOccurredAt] defaults to the repository clock; a future
  /// date is rejected. [currencyCode] must be `INR` in V1 (blueprint
  /// section 6.7). Throws [PostingValidationException] on any
  /// validation failure; nothing is written in that case.
  Future<Account> createAccount({
    required String name,
    required String kind,
    String currencyCode = 'INR',
    int? iconCodePoint,
    int? colorValue,
    int displayOrder = 0,
    Money? openingBalance,
    DateTime? openingOccurredAt,
  }) async {
    if (name.trim().isEmpty) {
      throw const PostingValidationException('Account name must not be empty.');
    }
    if (!accountKinds.contains(kind)) {
      throw PostingValidationException('Unknown account kind: $kind.');
    }
    if (currencyCode != 'INR') {
      throw const PostingValidationException('V1 accounts are INR only.');
    }
    final now = _clock();
    final occurredAt = openingOccurredAt ?? now;
    if (occurredAt.toUtc().isAfter(now.toUtc())) {
      throw const PostingValidationException(
        'An opening balance must not be dated in the future.',
      );
    }
    final signedOpening = openingBalance?.amountMinorUnits ?? 0;
    if (openingBalance != null && openingBalance.currencyCode != 'INR') {
      throw const PostingValidationException(
        'V1 opening balances are INR only.',
      );
    }

    return _database.transaction(() async {
      final uuid = _newUuid();
      final accountId = await _database
          .into(_database.accounts)
          .insert(
            AccountsCompanion.insert(
              uuid: uuid,
              name: name,
              kind: kind,
              currencyCode: Value(currencyCode),
              iconCodePoint: Value(iconCodePoint),
              colorValue: Value(colorValue),
              displayOrder: Value(displayOrder),
            ),
          );
      final ledgerKind = kind == 'credit_card_liability'
          ? ledgerKindUserLiability
          : ledgerKindUserAsset;
      final normalBalance = kind == 'credit_card_liability'
          ? LedgerDirection.credit
          : LedgerDirection.debit;
      await _database
          .into(_database.ledgerAccounts)
          .insert(
            LedgerAccountsCompanion.insert(
              ledgerAccountId: uuid,
              kind: ledgerKind,
              userAccountId: Value(uuid),
              normalBalance: normalBalance.value,
            ),
          );

      if (signedOpening != 0) {
        final accountLedger = LedgerDescriptor(
          ledgerAccountId: uuid,
          kind: ledgerKind,
          normalBalance: normalBalance,
          userAccountId: uuid,
        );
        final openingEquity = await _ledgerById(openingEquityLedgerId);
        if (openingEquity == null) {
          throw const PostingValidationException(
            'The opening_equity ledger account is missing.',
          );
        }
        final drafts = buildOpeningBalancePostings(
          accountLedger: accountLedger,
          openingEquityLedger: ledgerDescriptorOf(openingEquity),
          signedAmountMinorUnits: signedOpening,
          currencyCode: currencyCode,
        );
        final transactionId = await _database
            .into(_database.financialTransactions)
            .insert(
              FinancialTransactionsCompanion.insert(
                uuid: _newUuid(),
                kind: 'opening_balance',
                amountMinorUnits: signedOpening.abs(),
                currencyCode: Value(currencyCode),
                paymentChannel: openingBalancePaymentChannel,
                occurredAt: occurredAt,
                status: 'active',
                source: 'manual',
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
        await _database
            .into(_database.transactionHistory)
            .insert(
              TransactionHistoryCompanion.insert(
                uuid: _newUuid(),
                transactionId: transactionId,
                changedAt: now,
                changeKind: 'created',
                afterSnapshot: Value(
                  _openingSnapshot(
                    uuid: uuid,
                    signedAmountMinorUnits: signedOpening,
                    currencyCode: currencyCode,
                    occurredAt: occurredAt,
                  ),
                ),
              ),
            );
      }

      final account = await (_database.select(
        _database.accounts,
      )..where((t) => t.id.equals(accountId))).getSingle();
      return account;
    });
  }

  String _openingSnapshot({
    required String uuid,
    required int signedAmountMinorUnits,
    required String currencyCode,
    required DateTime occurredAt,
  }) {
    return jsonEncode(<String, Object?>{
      'uuid': uuid,
      'kind': 'opening_balance',
      'signedAmountMinorUnits': signedAmountMinorUnits,
      'currencyCode': currencyCode,
      'occurredAt': occurredAt.toUtc().toIso8601String(),
    });
  }

  Future<Account?> getAccountByUuid(String uuid) async {
    return (_database.select(
      _database.accounts,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
  }

  Future<List<Account>> listAccounts({bool includeArchived = true}) async {
    final query = _database.select(_database.accounts)
      ..orderBy([
        (t) => OrderingTerm(expression: t.displayOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.get();
  }

  /// Returns the ledger account for [accountUuid], resolved through
  /// `LedgerAccounts.userAccountId` (C3: never assume the ledger id
  /// equals the account uuid).
  Future<LedgerAccount?> ledgerForAccount(String accountUuid) async {
    return (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.userAccountId.equals(accountUuid))).getSingleOrNull();
  }

  Future<LedgerAccount?> _ledgerById(String ledgerAccountId) async {
    return (_database.select(_database.ledgerAccounts)
          ..where((t) => t.ledgerAccountId.equals(ledgerAccountId)))
        .getSingleOrNull();
  }

  /// Presentation-only edits: name, icon, colour, display order.
  /// Classification, currency, and archival are separate methods
  /// with their own guards.
  Future<Account> updateAccountPresentation(
    String uuid, {
    String? name,
    int? iconCodePoint,
    int? colorValue,
    int? displayOrder,
  }) async {
    final existing = await getAccountByUuid(uuid);
    if (existing == null) {
      throw PostingValidationException('Unknown account: $uuid.');
    }
    if (name != null && name.trim().isEmpty) {
      throw const PostingValidationException('Account name must not be empty.');
    }
    await (_database.update(
      _database.accounts,
    )..where((t) => t.uuid.equals(uuid))).write(
      AccountsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        iconCodePoint: iconCodePoint == null
            ? const Value.absent()
            : Value(iconCodePoint),
        colorValue: colorValue == null
            ? const Value.absent()
            : Value(colorValue),
        displayOrder: displayOrder == null
            ? const Value.absent()
            : Value(displayOrder),
      ),
    );
    return (await getAccountByUuid(uuid))!;
  }

  /// Changes an account's classification (asset kind or
  /// credit-card liability). Rejected once any posting references
  /// the account's ledger account, including postings belonging to
  /// soft-deleted transactions (corrected design, C2): reinterpreting
  /// the ledger would rewrite the meaning of history. Allowed only
  /// at zero postings, in which case the ledger kind and normal
  /// balance flip in the same transaction while the ledger id and
  /// mapping are preserved. `currencyCode` is immutable in Module 1.
  Future<Account> changeClassification(
    String uuid, {
    required String newKind,
  }) async {
    if (!accountKinds.contains(newKind)) {
      throw PostingValidationException('Unknown account kind: $newKind.');
    }
    return _database.transaction(() async {
      final existing = await getAccountByUuid(uuid);
      if (existing == null) {
        throw PostingValidationException('Unknown account: $uuid.');
      }
      if (existing.kind == newKind) {
        return existing;
      }
      final ledger = await ledgerForAccount(uuid);
      if (ledger == null) {
        throw PostingValidationException(
          'Account $uuid has no ledger account.',
        );
      }
      final postingCount = await _postingCountForLedger(ledger.ledgerAccountId);
      if (postingCount > 0) {
        throw const PostingValidationException(
          'An account classification cannot change once postings '
          'reference its ledger account, including postings of '
          'soft-deleted transactions.',
        );
      }
      final newLedgerKind = newKind == 'credit_card_liability'
          ? ledgerKindUserLiability
          : ledgerKindUserAsset;
      final newNormalBalance = newKind == 'credit_card_liability'
          ? LedgerDirection.credit
          : LedgerDirection.debit;
      await (_database.update(_database.accounts)
            ..where((t) => t.uuid.equals(uuid)))
          .write(AccountsCompanion(kind: Value(newKind)));
      await (_database.update(
        _database.ledgerAccounts,
      )..where((t) => t.ledgerAccountId.equals(ledger.ledgerAccountId))).write(
        LedgerAccountsCompanion(
          kind: Value(newLedgerKind),
          normalBalance: Value(newNormalBalance.value),
        ),
      );
      return (await getAccountByUuid(uuid))!;
    });
  }

  /// Archives an account and mirrors archival onto its ledger
  /// account in the same transaction. Archived accounts disappear
  /// from pickers but keep history and balances (C1).
  Future<Account> archiveAccount(String uuid) async {
    return _database.transaction(() async {
      final existing = await getAccountByUuid(uuid);
      if (existing == null) {
        throw PostingValidationException('Unknown account: $uuid.');
      }
      final now = _clock();
      await (_database.update(
        _database.accounts,
      )..where((t) => t.uuid.equals(uuid))).write(
        AccountsCompanion(
          isArchived: const Value(true),
          archivedAt: Value(now),
        ),
      );
      final ledger = await ledgerForAccount(uuid);
      if (ledger != null) {
        await (_database.update(_database.ledgerAccounts)
              ..where((t) => t.ledgerAccountId.equals(ledger.ledgerAccountId)))
            .write(const LedgerAccountsCompanion(isArchived: Value(true)));
      }
      return (await getAccountByUuid(uuid))!;
    });
  }

  /// Restores an archived account and clears archival on its ledger
  /// account in the same transaction.
  Future<Account> restoreAccount(String uuid) async {
    return _database.transaction(() async {
      final existing = await getAccountByUuid(uuid);
      if (existing == null) {
        throw PostingValidationException('Unknown account: $uuid.');
      }
      await (_database.update(
        _database.accounts,
      )..where((t) => t.uuid.equals(uuid))).write(
        const AccountsCompanion(
          isArchived: Value(false),
          archivedAt: Value(null),
        ),
      );
      final ledger = await ledgerForAccount(uuid);
      if (ledger != null) {
        await (_database.update(_database.ledgerAccounts)
              ..where((t) => t.ledgerAccountId.equals(ledger.ledgerAccountId)))
            .write(const LedgerAccountsCompanion(isArchived: Value(false)));
      }
      return (await getAccountByUuid(uuid))!;
    });
  }

  /// Counts postings referencing a ledger account, across
  /// transactions of ANY status (the immutability guard scope, C2).
  Future<int> _postingCountForLedger(String ledgerAccountId) async {
    final rows = await (_database.select(
      _database.postings,
    )..where((t) => t.ledgerAccountId.equals(ledgerAccountId))).get();
    return rows.length;
  }
}
