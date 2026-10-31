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

  Future<int> addTransaction(TransactionsCompanion transaction) {
    return _database.into(_database.transactions).insert(transaction);
  }

  Future<bool> updateTransaction(
    int id,
    TransactionsCompanion transaction,
  ) {
    final updatedTransaction = transaction.copyWith(
      updatedAt: Value(DateTime.now()),
      syncStatus: const Value('pending'),
    );

    return (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(updatedTransaction)
        .then((count) => count > 0);
  }

  Future<bool> deleteTransaction(int id) {
    return (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(
          const TransactionsCompanion(
            deleted: Value(true),
            syncStatus: Value('pending'),
          ),
        )
        .then((count) => count > 0);
  }
  
  Future<bool> restoreTransaction(int id) {
    return (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(
          const TransactionsCompanion(
            deleted: Value(false),
            syncStatus: Value('pending'),
          ),
        )
        .then((count) => count > 0);
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

  /// Marks one row synced after its Sheets write succeeded. Only
  /// `syncStatus` changes: `updatedAt` is left untouched so the
  /// timestamp stored in Sheets keeps matching the last real edit.
  Future<bool> markTransactionSynced(int id) {
    return (_database.update(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .write(
          const TransactionsCompanion(
            syncStatus: Value('synced'),
          ),
        )
        .then((count) => count > 0);
  }
}