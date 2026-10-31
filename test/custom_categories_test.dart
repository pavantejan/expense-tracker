import 'package:drift/native.dart';
import 'package:expense_tracker/data/database/app_database.dart';
import 'package:expense_tracker/data/repositories/custom_category_repository.dart';
import 'package:expense_tracker/data/repositories/transaction_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppDatabase> openTestDatabase() async {
  return AppDatabase(NativeDatabase.memory());
}

int _testTransactionCounter = 0;

TransactionsCompanion testTransaction({
  required String category,
  String syncStatus = 'synced',
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime(2026, 1, 1);
  _testTransactionCounter++;
  return TransactionsCompanion.insert(
    uuid: 'test-txn-$_testTransactionCounter',
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
  late CustomCategoryRepository categories;
  late TransactionRepository transactions;

  setUp(() async {
    database = await openTestDatabase();
    categories = CustomCategoryRepository(database);
    transactions = TransactionRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> addCategoryNamed(String name) {
    return categories.addCategory(
      uuid: 'cat-$name',
      name: name,
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
    );
  }

  group('CustomCategoryRepository', () {
    test('adding a custom category stores it with its icon', () async {
      final id = await addCategoryNamed('Gym');

      final stored = await categories.getCategoryById(id);

      expect(stored, isNotNull);
      expect(stored!.name, 'Gym');
      expect(stored.iconCodePoint, Icons.fitness_center_rounded.codePoint);
      expect((await categories.getAllCategories()).length, 1);
    });

    test('adding trims the stored name', () async {
      await addCategoryNamed('  Yoga  ');

      final stored = await categories.getAllCategories();

      expect(stored.single.name, 'Yoga');
    });

    test('updating one category leaves another unchanged', () async {
      final firstId = await addCategoryNamed('Gym');
      final secondId = await categories.addCategory(
        uuid: 'cat-travel',
        name: 'Travel',
        iconCodePoint: Icons.flight_rounded.codePoint,
      );

      final updated = await categories.updateCategory(
        id: firstId,
        name: 'Gym Club',
        iconCodePoint: Icons.spa_rounded.codePoint,
      );

      expect(updated, isTrue);
      final first = await categories.getCategoryById(firstId);
      final second = await categories.getCategoryById(secondId);
      expect(first!.name, 'Gym Club');
      expect(first.iconCodePoint, Icons.spa_rounded.codePoint);
      expect(second!.name, 'Travel');
      expect(second.iconCodePoint, Icons.flight_rounded.codePoint);
    });

    test('updating a non-existent category returns false', () async {
      await addCategoryNamed('Gym');

      final updated = await categories.updateCategory(
        id: 999,
        name: 'Nope',
        iconCodePoint: Icons.pets_rounded.codePoint,
      );

      expect(updated, isFalse);
      expect((await categories.getAllCategories()).single.name, 'Gym');
    });

    test('deleting one category leaves the others', () async {
      final firstId = await addCategoryNamed('Gym');
      await addCategoryNamed('Yoga');

      final deleted = await categories.deleteCategory(firstId);

      expect(deleted, isTrue);
      final remaining = await categories.getAllCategories();
      expect(remaining.map((c) => c.name), ['Yoga']);
    });

    test('deleting a non-existent category returns false', () async {
      expect(await categories.deleteCategory(999), isFalse);
    });

    test('duplicate names are rejected case-insensitively', () async {
      await addCategoryNamed('Gym');

      expect(() => addCategoryNamed('gym'), throwsArgumentError);
      expect(() => addCategoryNamed('  GYM  '), throwsArgumentError);
      expect(await categories.categoryNameExists('gym'), isTrue);
      expect(await categories.categoryNameExists('Yoga'), isFalse);
    });

    test('updating to another category name is rejected', () async {
      final firstId = await addCategoryNamed('Gym');
      await addCategoryNamed('Yoga');

      expect(
        () => categories.updateCategory(
          id: firstId,
          name: 'yoga',
          iconCodePoint: Icons.pets_rounded.codePoint,
        ),
        throwsArgumentError,
      );
      expect((await categories.getCategoryById(firstId))!.name, 'Gym');
    });

    test('renaming without changing the name is not a duplicate', () async {
      final id = await addCategoryNamed('Gym');

      final updated = await categories.updateCategory(
        id: id,
        name: 'gym',
        iconCodePoint: Icons.pets_rounded.codePoint,
      );

      expect(updated, isTrue);
      expect((await categories.getCategoryById(id))!.name, 'gym');
    });

    test('renaming a category updates matching transactions', () async {
      final id = await addCategoryNamed('Gym');
      await transactions.addTransaction(testTransaction(category: 'Gym'));
      await transactions.addTransaction(testTransaction(category: 'Gym'));
      await transactions.addTransaction(testTransaction(category: 'Food'));

      final renamed = await categories.renameCategory(
        id: id,
        oldName: 'Gym',
        name: 'Gym Club',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );

      expect(renamed, isTrue);
      final all = await transactions.watchAllTransactions().first;
      expect(all.where((t) => t.category == 'Gym Club').length, 2);
      expect(all.where((t) => t.category == 'Food').length, 1);
      expect(all.where((t) => t.category == 'Gym'), isEmpty);
    });

    test('renamed transactions become pending with a newer revision', () async {
      final id = await addCategoryNamed('Gym');
      final originalUpdatedAt = DateTime(2026, 1, 1);
      await transactions.addTransaction(
        testTransaction(
          category: 'Gym',
          syncStatus: 'synced',
          updatedAt: originalUpdatedAt,
        ),
      );

      await categories.renameCategory(
        id: id,
        oldName: 'Gym',
        name: 'Gym Club',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );

      final pending = await transactions.getPendingTransactions();
      expect(pending.length, 1);
      expect(pending.single.category, 'Gym Club');
      expect(pending.single.syncStatus, 'pending');
      expect(pending.single.updatedAt.isAfter(originalUpdatedAt), isTrue);
    });

    test('icon-only rename touches no transaction row', () async {
      final id = await addCategoryNamed('Gym');
      final originalUpdatedAt = DateTime(2026, 1, 1);
      await transactions.addTransaction(
        testTransaction(
          category: 'Gym',
          syncStatus: 'synced',
          updatedAt: originalUpdatedAt,
        ),
      );

      final renamed = await categories.renameCategory(
        id: id,
        oldName: 'Gym',
        name: 'Gym',
        iconCodePoint: Icons.spa_rounded.codePoint,
      );

      expect(renamed, isTrue);
      expect(await transactions.getPendingTransactions(), isEmpty);
      final row = (await transactions.watchAllTransactions().first).single;
      expect(row.updatedAt, originalUpdatedAt);
    });

    test('renaming a non-existent category changes nothing', () async {
      await addCategoryNamed('Gym');
      await transactions.addTransaction(testTransaction(category: 'Gym'));

      final renamed = await categories.renameCategory(
        id: 999,
        oldName: 'Gym',
        name: 'Gym Club',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );

      expect(renamed, isFalse);
      final rows = await transactions.watchAllTransactions().first;
      expect(rows.single.category, 'Gym');
      expect(await transactions.getPendingTransactions(), isEmpty);
    });

    test('deleting a category leaves historical transactions intact', () async {
      final id = await addCategoryNamed('Gym');
      await transactions.addTransaction(testTransaction(category: 'Gym'));

      expect(await categories.deleteCategory(id), isTrue);

      final rows = await transactions.watchAllTransactions().first;
      expect(rows.length, 1);
      expect(rows.single.category, 'Gym');
    });
  });
}
