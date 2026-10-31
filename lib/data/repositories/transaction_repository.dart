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
  Stream<List<Transaction>> watchTransactionsForMonth(
    DateTime month,
  ) {
    final start = DateTime(
      month.year,
      month.month,
    );

    final end = DateTime(
      month.year,
      month.month + 1,
    );

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

  Stream<List<Transaction>> watchTransactionsForYear(
    int year,
  ) {
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

    final startOfMonth = DateTime(
      month.year,
      month.month,
    );

    final startOfOpeningMonth = DateTime(
      openingBalanceDate.year,
      openingBalanceDate.month,
    );

    if (startOfMonth.isBefore(startOfOpeningMonth)) {
      return 0;
    }

    final transactions = await (_database.select(_database.transactions)
          ..where(
            (t) =>
                t.deleted.equals(false) &
                t.transactionDate.isBiggerOrEqualValue(
                  startOfOpeningMonth,
                ) &
                t.transactionDate.isSmallerThanValue(startOfMonth),
          ))
        .get();

    return transactions.fold<double>(
      0,
      (balance, transaction) {
        if (transaction.type == 'Income') {
          return balance + transaction.amount;
        }

        return balance - transaction.amount;
      },
    );
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

  /// Revision timestamp for the next local mutation of [previous].
  ///
  /// The revision used for conditional sync acknowledgement is the
  /// millisecond-precision [Transaction.updatedAt] value as stored
  /// by Drift (SQLite stores DateTime at millisecond precision).
  /// Every local mutation — edit, delete, and restore — advances
  /// this value strictly, by at least 1ms beyond the previous
  /// stored value, so two distinct local writes can never share a
  /// revision even if they happen inside the same millisecond.
  /// A dedicated integer revision column would be stronger if
  /// storage ever truncated below milliseconds; that requires
  /// regenerating `app_database.g.dart` with build_runner (see
  /// docs/sheets-sync.md) and is deliberately not hand-edited here.
  DateTime _nextUpdatedAt(DateTime previous) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final previousMs = previous.millisecondsSinceEpoch;
    final nextMs = nowMs > previousMs ? nowMs : previousMs + 1;
    return DateTime.fromMillisecondsSinceEpoch(nextMs);
  }

  Future<int> addTransaction(TransactionsCompanion transaction) {
    return _database.into(_database.transactions).insert(transaction);
  }

  Future<bool> updateTransaction(
    int id,
    TransactionsCompanion transaction,
  ) async {
    final existing = await getTransactionById(id);
    if (existing == null) {
      return false;
    }

    final updatedTransaction = transaction.copyWith(
      updatedAt: Value(_nextUpdatedAt(existing.updatedAt)),
      syncStatus: const Value('pending'),
    );

    final count = await (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(updatedTransaction);
    return count > 0;
  }

  Future<bool> deleteTransaction(int id) async {
    final existing = await getTransactionById(id);
    if (existing == null) {
      return false;
    }

    final count = await (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(
          TransactionsCompanion(
            deleted: const Value(true),
            updatedAt: Value(_nextUpdatedAt(existing.updatedAt)),
            syncStatus: const Value('pending'),
          ),
        );
    return count > 0;
  }

  Future<bool> restoreTransaction(int id) async {
    final existing = await getTransactionById(id);
    if (existing == null) {
      return false;
    }

    final count = await (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(
          TransactionsCompanion(
            deleted: const Value(false),
            updatedAt: Value(_nextUpdatedAt(existing.updatedAt)),
            syncStatus: const Value('pending'),
          ),
        );
    return count > 0;
  }

  Future<Transaction?> getTransactionById(int id) {
    return (_database.select(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// All rows awaiting Sheets synchronization, including soft-deleted
  /// rows (a deletion is itself a change to sync) and rows deleted
  /// before they were ever synced. Oldest update first, so retries
  /// process work in a stable order.
  Future<List<Transaction>> getPendingTransactions() {
    return (_database.select(_database.transactions)
          ..where((t) => t.syncStatus.equals('pending'))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.updatedAt,
                ),
          ]))
        .get();
  }

  /// Conditional acknowledgement: marks one row synced only if it
  /// is still the exact revision that was uploaded — same
  /// [updatedAt] revision, same [deleted] state, and still
  /// `pending`. Returns `true` only when exactly that row was
  /// updated. If a newer local edit, delete, or restore happened
  /// while the remote write was running, this affects zero rows
  /// and the newer revision correctly remains pending.
  /// Only `syncStatus` changes: `updatedAt` is left untouched.
  Future<bool> markTransactionSyncedIfUnchanged({
    required int id,
    required DateTime updatedAt,
    required bool deleted,
  }) {
    return (_database.update(_database.transactions)
          ..where(
            (t) =>
                t.id.equals(id) &
                t.updatedAt.equals(updatedAt) &
                t.deleted.equals(deleted) &
                t.syncStatus.equals('pending'),
          ))
        .write(
          const TransactionsCompanion(
            syncStatus: Value('synced'),
          ),
        )
        .then((count) => count > 0);
  }
}