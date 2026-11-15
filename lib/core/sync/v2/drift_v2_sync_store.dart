// Drift-backed pending-work store for V2 Sheets sync.
//
// The sync adapter boundary (blueprint section 4.2): resolves local V2
// rows (transaction, postings, ledger accounts, accounts, categories)
// into pure [SheetV2Source] values. It contains no posting or
// reporting rules.

import '../../../data/database/v2/app_database_v2.dart';
import '../../../data/repositories/financial_transaction_repository.dart';
import 'sheets_v2_contract.dart';
import 'sheets_v2_engine.dart';
import 'sheets_v2_mapper.dart';

/// Source of pending V2 work and the place acknowledgement is recorded.
abstract class V2SyncStore {
  Future<List<V2SyncItem>> getPending();

  /// Conditional: true only when the local row is still the uploaded
  /// revision.
  Future<bool> markSynced(V2SyncItem item);
}

class DriftV2SyncStore implements V2SyncStore {
  DriftV2SyncStore(this._database, this._transactions);

  final AppDatabaseV2 _database;
  final FinancialTransactionRepository _transactions;

  @override
  Future<List<V2SyncItem>> getPending() async {
    final rows = await _transactions.getPendingSyncTransactions();
    final lookup = _Lookup(_database);
    final items = <V2SyncItem>[];
    for (final row in rows) {
      items.add(
        V2SyncItem(
          localId: row.id,
          syncRevision: row.syncRevision,
          status: row.status,
          source: await _sourceFor(row, lookup, includeOriginal: true),
        ),
      );
    }
    return items;
  }

  @override
  Future<bool> markSynced(V2SyncItem item) {
    return _transactions.markSyncedIfUnchanged(
      id: item.localId,
      syncRevision: item.syncRevision,
      status: item.status,
    );
  }

  Future<SheetV2Source> _sourceFor(
    FinancialTransaction row,
    _Lookup lookup, {
    required bool includeOriginal,
  }) async {
    final postings = await (_database.select(
      _database.postings,
    )..where((t) => t.transactionId.equals(row.id))).get();

    SheetV2AccountRef? account;
    SheetBalanceDirection? balanceDirection;
    for (final posting in postings) {
      final ledger = await lookup.ledger(posting.ledgerAccountId);
      final accountUuid = ledger?.userAccountId;
      if (ledger == null || accountUuid == null) {
        continue;
      }
      account = await lookup.accountRef(accountUuid);
      balanceDirection = posting.direction == ledger.normalBalance
          ? SheetBalanceDirection.positive
          : SheetBalanceDirection.negative;
      break;
    }

    SheetV2Source? original;
    final originalUuid = row.reversesTransactionId;
    if (includeOriginal && row.kind == 'reversal' && originalUuid != null) {
      final originalRow = await _transactions.getTransactionByUuid(
        originalUuid,
      );
      if (originalRow != null) {
        original = await _sourceFor(
          originalRow,
          lookup,
          includeOriginal: false,
        );
      }
    }

    return SheetV2Source(
      uuid: row.uuid,
      kind: row.kind,
      occurredAt: row.occurredAt,
      amountMinorUnits: row.amountMinorUnits,
      currencyCode: row.currencyCode,
      paymentChannel: row.paymentChannel,
      source: row.source,
      updatedAt: row.updatedAt,
      deleted: row.status == 'deleted',
      categoryId: row.categoryId,
      categoryName: row.categoryId == null
          ? null
          : await lookup.categoryName(row.categoryId!),
      description: row.description,
      notes: row.notes,
      account: account,
      sourceAccount: await lookup.accountRefOrNull(row.sourceAccountId),
      destinationAccount: await lookup.accountRefOrNull(
        row.destinationAccountId,
      ),
      refundAccount: await lookup.accountRefOrNull(row.refundAccountId),
      balanceDirection: row.kind == 'opening_balance' ? balanceDirection : null,
      originalUuid: originalUuid,
      relatedUuid: row.relatedTransactionId,
      original: original,
    );
  }
}

/// Per-run caches so a batch does not re-query the same rows.
class _Lookup {
  _Lookup(this._database);

  final AppDatabaseV2 _database;
  final Map<String, LedgerAccount?> _ledgers = <String, LedgerAccount?>{};
  final Map<String, SheetV2AccountRef?> _accounts =
      <String, SheetV2AccountRef?>{};
  final Map<String, String?> _categories = <String, String?>{};

  Future<LedgerAccount?> ledger(String id) async {
    if (_ledgers.containsKey(id)) {
      return _ledgers[id];
    }
    final row = await (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.ledgerAccountId.equals(id))).getSingleOrNull();
    return _ledgers[id] = row;
  }

  Future<SheetV2AccountRef?> accountRefOrNull(String? uuid) async {
    return uuid == null ? null : accountRef(uuid);
  }

  Future<SheetV2AccountRef?> accountRef(String uuid) async {
    if (_accounts.containsKey(uuid)) {
      return _accounts[uuid];
    }
    final row = await (_database.select(
      _database.accounts,
    )..where((t) => t.uuid.equals(uuid))).getSingleOrNull();
    return _accounts[uuid] = row == null
        ? null
        : SheetV2AccountRef(id: row.uuid, name: row.name);
  }

  Future<String?> categoryName(String categoryId) async {
    if (_categories.containsKey(categoryId)) {
      return _categories[categoryId];
    }
    final row = await (_database.select(
      _database.categories,
    )..where((t) => t.categoryId.equals(categoryId))).getSingleOrNull();
    return _categories[categoryId] = row?.name;
  }
}
