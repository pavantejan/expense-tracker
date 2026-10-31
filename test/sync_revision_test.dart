import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/data/database/app_database.dart';
import 'package:expense_tracker/data/repositories/custom_category_repository.dart';
import 'package:expense_tracker/data/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _revisionTestCounter = 0;

TransactionsCompanion _revisionTransaction({
  String category = 'Food',
  String syncStatus = 'pending',
}) {
  _revisionTestCounter++;
  final now = DateTime(2026, 1, 1);
  return TransactionsCompanion.insert(
    uuid: 'rev-txn-$_revisionTestCounter',
    type: 'Expense',
    amount: 100,
    category: category,
    paymentMethod: 'UPI',
    transactionDate: DateTime(2026, 1, 15),
    createdAt: now,
    updatedAt: now,
    syncStatus: syncStatus,
  );
}

void main() {
  late AppDatabase database;
  late TransactionRepository transactions;
  late CustomCategoryRepository categories;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    transactions = TransactionRepository(database);
    categories = CustomCategoryRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<Transaction> rowOf(int id) async {
    return (await transactions.getTransactionById(id))!;
  }

  TransactionsCompanion editWith(double amount) {
    return TransactionsCompanion(amount: Value(amount));
  }

  group('syncRevision', () {
    test('new transaction starts at revision 0', () async {
      final id = await transactions.addTransaction(_revisionTransaction());
      expect((await rowOf(id)).syncRevision, 0);
    });

    test('two updates with the same updatedAt timestamp produce distinct increasing persisted revisions', () async {
      // Fixed clock: both mutations deterministically receive
      // the exact same `updatedAt`. The integer revision, not
      // the timestamp, is what distinguishes the two writes.
      // This holds even though DateTime storage has only
      // second precision: the stored timestamps are equal.
      final fixedNow = DateTime(2026, 1, 1, 12, 0, 0);
      final clocked = TransactionRepository(database, clock: () => fixedNow);
      final id = await clocked.addTransaction(_revisionTransaction());
      await clocked.updateTransaction(id, editWith(101));
      final afterFirst = await rowOf(id);
      await clocked.updateTransaction(id, editWith(102));
      final afterSecond = await rowOf(id);

      expect(afterFirst.updatedAt, fixedNow);
      expect(afterSecond.updatedAt, fixedNow);
      expect(afterFirst.updatedAt, afterSecond.updatedAt);
      expect(afterFirst.syncRevision, 1);
      expect(afterSecond.syncRevision, 2);
      expect(afterSecond.amount, 102);
    });

    test(
      'stale acknowledgement fails and the newer row remains pending',
      () async {
        final id = await transactions.addTransaction(_revisionTransaction());
        await transactions.updateTransaction(id, editWith(101));
        final snapshot = await rowOf(id);
        await transactions.updateTransaction(id, editWith(102));

        final staleAck = await transactions.markTransactionSyncedIfUnchanged(
          id: id,
          syncRevision: snapshot.syncRevision,
          deleted: snapshot.deleted,
        );
        expect(staleAck, isFalse);

        final newer = await rowOf(id);
        expect(newer.syncRevision, 2);
        expect(newer.syncStatus, 'pending');

        final currentAck = await transactions.markTransactionSyncedIfUnchanged(
          id: id,
          syncRevision: newer.syncRevision,
          deleted: newer.deleted,
        );
        expect(currentAck, isTrue);
        expect((await rowOf(id)).syncStatus, 'synced');
      },
    );

    test('acknowledgement with the wrong deleted state fails', () async {
      final id = await transactions.addTransaction(_revisionTransaction());
      final snapshot = await rowOf(id);
      await transactions.deleteTransaction(id);

      final ack = await transactions.markTransactionSyncedIfUnchanged(
        id: id,
        syncRevision: snapshot.syncRevision,
        deleted: snapshot.deleted,
      );
      expect(ack, isFalse);
      final row = await rowOf(id);
      expect(row.deleted, isTrue);
      expect(row.syncStatus, 'pending');
      expect(row.syncRevision, 1);
    });

    test('delete then restore advances the revision each time', () async {
      final id = await transactions.addTransaction(_revisionTransaction());
      await transactions.deleteTransaction(id);
      expect((await rowOf(id)).syncRevision, 1);
      await transactions.restoreTransaction(id);
      final restored = await rowOf(id);
      expect(restored.syncRevision, 2);
      expect(restored.deleted, isFalse);
      expect(restored.syncStatus, 'pending');
    });

    test('delete followed by category rename preserves deleted state, advances revision, remains pending', () async {
      final categoryId = await categories.addCategory(
        uuid: 'cat-gym',
        name: 'Gym',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );
      final id = await transactions.addTransaction(
        _revisionTransaction(category: 'Gym'),
      );
      await transactions.deleteTransaction(id);
      final deleted = await rowOf(id);
      expect(deleted.syncRevision, 1);

      await categories.renameCategory(
        id: categoryId,
        name: 'Gym Club',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );

      final renamed = await rowOf(id);
      expect(renamed.deleted, isTrue);
      expect(renamed.category, 'Gym Club');
      expect(renamed.syncRevision, 2);
      expect(renamed.syncStatus, 'pending');
    });

    test('category rename advances the revision of every matching active and soft-deleted transaction', () async {
      final categoryId = await categories.addCategory(
        uuid: 'cat-gym-2',
        name: 'Gym',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );
      final active1 = await transactions.addTransaction(
        _revisionTransaction(category: 'Gym'),
      );
      final active2 = await transactions.addTransaction(
        _revisionTransaction(category: 'Gym'),
      );
      final deletedId = await transactions.addTransaction(
        _revisionTransaction(category: 'Gym'),
      );
      final unrelated = await transactions.addTransaction(
        _revisionTransaction(category: 'Food'),
      );
      await transactions.deleteTransaction(deletedId);

      await categories.renameCategory(
        id: categoryId,
        name: 'Gym Club',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );

      expect((await rowOf(active1)).syncRevision, 1);
      expect((await rowOf(active2)).syncRevision, 1);
      final renamedDeleted = await rowOf(deletedId);
      expect(renamedDeleted.syncRevision, 2);
      expect(renamedDeleted.deleted, isTrue);
      final untouched = await rowOf(unrelated);
      expect(untouched.syncRevision, 0);
      expect(untouched.category, 'Food');
    });

    test(
      'old acknowledgement does not mark a renamed transaction as synced',
      () async {
        final categoryId = await categories.addCategory(
          uuid: 'cat-gym-3',
          name: 'Gym',
          iconCodePoint: Icons.fitness_center_rounded.codePoint,
        );
        final id = await transactions.addTransaction(
          _revisionTransaction(category: 'Gym'),
        );
        final beforeRename = await rowOf(id);

        await categories.renameCategory(
          id: categoryId,
          name: 'Gym Club',
          iconCodePoint: Icons.fitness_center_rounded.codePoint,
        );

        final staleAck = await transactions.markTransactionSyncedIfUnchanged(
          id: id,
          syncRevision: beforeRename.syncRevision,
          deleted: beforeRename.deleted,
        );
        expect(staleAck, isFalse);
        expect((await rowOf(id)).syncStatus, 'pending');

        final afterRename = await rowOf(id);
        final currentAck = await transactions.markTransactionSyncedIfUnchanged(
          id: id,
          syncRevision: afterRename.syncRevision,
          deleted: afterRename.deleted,
        );
        expect(currentAck, isTrue);
      },
    );

    test('update of a non-existent id changes no revision', () async {
      expect(
        await transactions.updateTransaction(999999, editWith(101)),
        isFalse,
      );
      expect(
        await transactions.markTransactionSyncedIfUnchanged(
          id: 999999,
          syncRevision: 0,
          deleted: false,
        ),
        isFalse,
      );
    });
  });
}
