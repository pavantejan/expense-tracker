import 'package:drift/native.dart';
import 'package:expense_tracker/data/database/app_database.dart';
import 'package:expense_tracker/data/repositories/custom_category_repository.dart';
import 'package:expense_tracker/data/repositories/transaction_repository.dart';
import 'package:expense_tracker/features/transactions/add_transaction_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomCategoryRepository categoryRepository;
  late TransactionRepository transactionRepository;
  var databaseClosed = false;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    categoryRepository = CustomCategoryRepository(database);
    transactionRepository = TransactionRepository(database);
    databaseClosed = false;
  });

  tearDown(() async {
    if (!databaseClosed) {
      await database.close();
    }
  });

  /// Closes the in-memory database inside the test body, before
  /// teardown: an open Drift connection leaves a Timer pending
  /// in the widget-test binding and fails teardown (see
  /// docs/custom-categories.md).
  Future<void> closeDatabase(WidgetTester tester) async {
    databaseClosed = true;
    await database.close();
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester, {int? transactionId}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AddTransactionPage(
          transactionId: transactionId,
          transactionRepository: transactionRepository,
          customCategoryRepository: categoryRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('custom categories appear in the category selector', (
    tester,
  ) async {
    await categoryRepository.addCategory(
      uuid: 'cat-gym',
      name: 'Gym',
      iconCodePoint: Icons.fitness_center_rounded.codePoint,
    );
    await pumpPage(tester);

    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    expect(find.text('Gym'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);

    await tester.tap(find.text('Gym'));
    await tester.pumpAndSettle();

    expect(find.text('Gym'), findsOneWidget);
    await closeDatabase(tester);
  });

  testWidgets(
    'editing a transaction with a deleted custom category keeps its text',
    (tester) async {
      final transactionId = await transactionRepository.addTransaction(
        TransactionsCompanion.insert(
          uuid: 'test-txn-pilates',
          type: 'Expense',
          amount: 250,
          category: 'Pilates',
          paymentMethod: 'UPI',
          transactionDate: DateTime(2026, 1, 15),
          createdAt: DateTime(2026, 1, 15),
          updatedAt: DateTime(2026, 1, 15),
          syncStatus: 'synced',
        ),
      );
      await pumpPage(tester, transactionId: transactionId);

      // The stored text is shown as the selected category, not
      // replaced with a built-in default.
      expect(find.text('Pilates'), findsOneWidget);

      // Opening the selector keeps the stored text available.
      await tester.tap(find.text('Pilates'));
      await tester.pumpAndSettle();
      expect(find.text('Pilates'), findsWidgets);
      expect(find.text('Food'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Pilates'), findsOneWidget);

      // Saving preserves the original category text.
      await tester.enterText(find.byType(TextField).first, '250');
      // The save button sits below the fold in the default test
      // viewport; drag the list up until it is built and
      // visible. (scrollUntilVisible cannot disambiguate the
      // ListView from the TextFields' internal Scrollables.)
      for (
        var i = 0;
        i < 6 && find.text('Update Transaction').evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Update Transaction').first);
      await tester.pumpAndSettle();

      final saved = await transactionRepository.getTransactionById(
        transactionId,
      );
      expect(saved, isNotNull);
      expect(saved!.category, 'Pilates');

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await closeDatabase(tester);
    },
  );
}
