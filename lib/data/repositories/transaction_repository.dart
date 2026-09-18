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

  Future<Transaction?> getTransactionById(int id) {
    return (_database.select(_database.transactions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
}