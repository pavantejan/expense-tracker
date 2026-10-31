import 'package:drift/drift.dart';

import '../database/app_database.dart';

class TransactionRepository {
  TransactionRepository(this._database);

  final AppDatabase _database;

  Stream<List<Transaction>> watchAllTransactions() {
    return (_database.select(_database.transactions)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsForMonth(DateTime month) {
    final start = DateTime(month.year, month.month);

    final end = DateTime(month.year, month.month + 1);

    return (_database.select(_database.transactions)
          ..where(
            (t) =>
                t.deleted.equals(false) &
                t.transactionDate.isBiggerOrEqualValue(start) &
                t.transactionDate.isSmallerThanValue(end),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Stream<List<Transaction>> watchTransactionsForYear(int year) {
    final start = DateTime(year);
    final end = DateTime(year + 1);

    return (_database.select(_database.transactions)
          ..where(
            (t) =>
                t.deleted.equals(false) &
                t.transactionDate.isBiggerOrEqualValue(start) &
                t.transactionDate.isSmallerThanValue(end),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  Future<double> getBalanceBeforeMonth(
    DateTime month,
    DateTime? openingBalanceDate,
  ) async {
    if (openingBalanceDate == null) {
      return 0;
    }

    final startOfMonth = DateTime(month.year, month.month);

    final startOfOpeningMonth = DateTime(
      openingBalanceDate.year,
      openingBalanceDate.month,
    );

    if (startOfMonth.isBefore(startOfOpeningMonth)) {
      return 0;
    }

    final transactions =
        await (_database.select(_database.transactions)..where(
              (t) =>
                  t.deleted.equals(false) &
                  t.transactionDate.isBiggerOrEqualValue(startOfOpeningMonth) &
                  t.transactionDate.isSmallerThanValue(startOfMonth),
            ))
            .get();

    return transactions.fold<double>(0, (balance, transaction) {
      if (transaction.type == 'Income') {
        return balance + transaction.amount;
      }

      return balance - transaction.amount;
    });
  }

  Stream<List<Transaction>> searchTransactions(String query) {
    final searchQuery = '%${query.trim()}%';

    return (_database.select(_database.transactions)
          ..where(
            (t) =>
                t.deleted.equals(false) &
                (t.description.like(searchQuery) |
                    t.category.like(searchQuery) |
                    t.paymentMethod.like(searchQuery) |
                    t.notes.like(searchQuery)),
          )
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.transactionDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch();
  }

  /// Applies [write] to the row with [id] inside one database
  /// transaction, advancing its [Transaction.syncRevision] by one
  /// and refreshing [Transaction.updatedAt] atomically with the
  /// mutation.
  ///
  /// `updatedAt` is timestamp metadata only: Drift stores
  /// DateTime values with second precision, so same-second
  /// mutations can share an `updatedAt` value. The integer
  /// `syncRevision` is the only concurrency token used by
  /// conditional sync acknowledgement
  /// ([markTransactionSyncedIfUnchanged]); it must advance on
  /// every local mutation, including soft-delete and restore.
  /// New rows start at revision 0 (the column default); the
  /// first mutation advances the revision to 1.
  Future<bool> _mutateWithNewRevision(
    int id,
    TransactionsCompanion Function(Transaction existing) write,
  ) async {
    return _database.transaction(() async {
      final existing = await getTransactionById(id);
      if (existing == null) {
        return false;
      }
      final count =
          await (_database.update(
            _database.transactions,
          )..where((t) => t.id.equals(id))).write(
            write(existing).copyWith(
              updatedAt: Value(DateTime.now()),
              syncRevision: Value(existing.syncRevision + 1),
              syncStatus: const Value('pending'),
            ),
          );
      return count > 0;
    });
  }

  Future<int> addTransaction(TransactionsCompanion transaction) {
    return _database.into(_database.transactions).insert(transaction);
  }

  Future<bool> updateTransaction(int id, TransactionsCompanion transaction) {
    return _mutateWithNewRevision(id, (_) => transaction);
  }

  Future<bool> deleteTransaction(int id) {
    return _mutateWithNewRevision(
      id,
      (_) => const TransactionsCompanion(deleted: Value(true)),
    );
  }

  Future<bool> restoreTransaction(int id) {
    return _mutateWithNewRevision(
      id,
      (_) => const TransactionsCompanion(deleted: Value(false)),
    );
  }

  Future<Transaction?> getTransactionById(int id) {
    return (_database.select(
      _database.transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// All rows awaiting Sheets synchronization, including soft-deleted
  /// rows (a deletion is itself a change to sync) and rows deleted
  /// before they were ever synced. Oldest update first, so retries
  /// process work in a stable order.
  Future<List<Transaction>> getPendingTransactions() {
    return (_database.select(_database.transactions)
          ..where((t) => t.syncStatus.equals('pending'))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt)]))
        .get();
  }

  /// Conditional acknowledgement: marks one row synced only if it
  /// is still the exact revision that was uploaded — same
  /// [syncRevision], same [deleted] state, and still `pending`.
  /// Returns `true` only when exactly that row was updated. If a
  /// newer local edit, delete, restore, or category rename
  /// happened while the remote write was running, this affects
  /// zero rows and the newer revision correctly remains pending.
  /// Only `syncStatus` changes: `updatedAt` and `syncRevision`
  /// are left untouched. An acknowledgement carrying an older
  /// revision must return `false`.
  Future<bool> markTransactionSyncedIfUnchanged({
    required int id,
    required int syncRevision,
    required bool deleted,
  }) {
    return (_database.update(_database.transactions)..where(
          (t) =>
              t.id.equals(id) &
              t.syncRevision.equals(syncRevision) &
              t.deleted.equals(deleted) &
              t.syncStatus.equals('pending'),
        ))
        .write(const TransactionsCompanion(syncStatus: Value('synced')))
        .then((count) => count > 0);
  }
}
