import 'package:drift/native.dart';
import 'package:expense_tracker/data/database/app_database.dart';
import 'package:expense_tracker/data/repositories/custom_category_repository.dart';
import 'package:expense_tracker/features/categories/categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CustomCategoryRepository repository;
  var databaseClosed = false;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = CustomCategoryRepository(database);
    databaseClosed = false;
  });

  tearDown(() async {
    if (!databaseClosed) {
      await database.close();
    }
  });

  /// Closes the in-memory database inside the test body, before
  /// teardown. An open Drift connection leaves a Timer pending
  /// in the widget-test binding (the same family as the known
  /// pre-existing widget_test Timer failure), which fails the
  /// binding invariant at teardown; closing in-body clears it.
  Future<void> closeDatabase(WidgetTester tester) async {
    databaseClosed = true;
    await database.close();
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester) async {
    // Tall viewport: the whole list (built-ins + custom tiles)
    // fits on screen, so no scrolling is needed to reach the
    // custom section and the floating action button cannot
    // cover a trailing action button.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(home: CategoriesPage(repository: repository)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add-category')));
    await tester.pumpAndSettle();
    expect(find.byType(CategoryFormDialog), findsOneWidget);
  }

  Future<void> enterName(WidgetTester tester, String name) async {
    await tester.enterText(find.byType(TextFormField), name);
    await tester.pump();
  }

  Future<void> saveDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  group('CategoryFormDialog validation', () {
    Future<void> pumpDialog(
      WidgetTester tester, {
      String? initialName,
      Iterable<String> existingNames = const [],
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await showDialog<CategoryFormResult>(
                    context: context,
                    builder: (_) => CategoryFormDialog(
                      initialName: initialName,
                      existingNames: existingNames,
                      isEditing: initialName != null,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets('empty name shows an error and stays open', (tester) async {
      await pumpDialog(tester);

      await enterName(tester, '   ');
      await saveDialog(tester);

      expect(find.text('Enter a category name.'), findsOneWidget);
      expect(find.byType(CategoryFormDialog), findsOneWidget);
    });

    testWidgets('duplicate name is rejected case-insensitively', (
      tester,
    ) async {
      await pumpDialog(tester, existingNames: ['Gym']);

      await enterName(tester, ' gym ');
      await saveDialog(tester);

      expect(
        find.text('A category with this name already exists.'),
        findsOneWidget,
      );
      expect(find.byType(CategoryFormDialog), findsOneWidget);
    });

    testWidgets('built-in name collision is rejected', (tester) async {
      await pumpDialog(tester);

      await enterName(tester, 'food');
      await saveDialog(tester);

      expect(
        find.text('"food" is already a built-in category.'),
        findsOneWidget,
      );
    });

    testWidgets('valid name with a picked icon returns the result', (
      tester,
    ) async {
      CategoryFormResult? captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  captured = await showDialog<CategoryFormResult>(
                    context: context,
                    builder: (_) => const CategoryFormDialog(
                      existingNames: [],
                      isEditing: false,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await enterName(tester, '  Yoga  ');
      await tester.tap(
        find.byKey(ValueKey('category-icon-${Icons.spa_rounded.codePoint}')),
      );
      await tester.pump();
      await saveDialog(tester);

      expect(captured, isNotNull);
      expect(captured!.name, 'Yoga');
      expect(captured!.iconCodePoint, Icons.spa_rounded.codePoint);
      expect(find.byType(CategoryFormDialog), findsNothing);
    });

    testWidgets('editing without renaming passes validation', (tester) async {
      await pumpDialog(tester, initialName: 'Gym', existingNames: []);

      await saveDialog(tester);

      expect(find.byType(CategoryFormDialog), findsNothing);
    });
  });

  group('CategoriesPage', () {
    testWidgets('adding a category shows it with its icon', (tester) async {
      await pumpPage(tester);
      expect(find.text('Food'), findsOneWidget);
      expect(find.textContaining('No custom categories yet'), findsOneWidget);

      await openAddDialog(tester);
      await enterName(tester, 'Gym');
      await saveDialog(tester);

      expect(find.text('Gym'), findsOneWidget);
      expect(find.textContaining('No custom categories yet'), findsNothing);
      final stored = await repository.getAllCategories();
      expect(stored.single.name, 'Gym');
      // Let the confirmation SnackBar's auto-dismiss timer fire
      // and its dismiss animation finish; a pending timer at
      // teardown fails the test binding.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await closeDatabase(tester);
    });

    testWidgets('deleting a category removes only that category', (
      tester,
    ) async {
      await repository.addCategory(
        uuid: 'cat-gym',
        name: 'Gym',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );
      await repository.addCategory(
        uuid: 'cat-yoga',
        name: 'Yoga',
        iconCodePoint: Icons.spa_rounded.codePoint,
      );
      await pumpPage(tester);
      expect(find.text('Gym'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete category').first);
      await tester.pumpAndSettle();
      expect(find.text('Delete category?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Gym'), findsNothing);
      expect(find.text('Yoga'), findsOneWidget);
      expect((await repository.getAllCategories()).map((c) => c.name), [
        'Yoga',
      ]);
      // Let the confirmation SnackBar's auto-dismiss timer fire.
      await tester.pump(const Duration(seconds: 6));
      await closeDatabase(tester);
    });

    testWidgets('icon-only edit updates the icon without renaming', (
      tester,
    ) async {
      await repository.addCategory(
        uuid: 'cat-gym',
        name: 'Gym',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
      );
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Edit category').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('category-icon-${Icons.spa_rounded.codePoint}')),
      );
      await tester.pump();
      await saveDialog(tester);

      final stored = await repository.getAllCategories();
      expect(stored.single.name, 'Gym');
      expect(stored.single.iconCodePoint, Icons.spa_rounded.codePoint);
      // Let the confirmation SnackBar's auto-dismiss timer fire.
      await tester.pump(const Duration(seconds: 6));
      await closeDatabase(tester);
    });
  });
}
