import 'package:expense_tracker/app/app_services.dart';
import 'package:expense_tracker/features/categories/categories_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test_helpers.dart';

void main() {
  group('validateCategoryName', () {
    test('rejects empty and duplicate names, case-insensitively', () {
      expect(validateCategoryName('  ', const []), isNotNull);
      expect(validateCategoryName(' food ', const ['Food']), isNotNull);
      expect(validateCategoryName('Gym', const ['Food']), isNull);
    });
  });

  group('CategoriesPage', () {
    late AppServices services;

    Future<void> openAdd(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('add-category')));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryFormDialog), findsOneWidget);
    }

    testWidgets('adds an income category with its icon', (tester) async {
      services = (await tester.runAsync(createTestServices))!;
      await pumpWithServices(tester, services, const CategoriesPage());

      await openAdd(tester);
      await tester.enterText(find.byType(TextFormField), 'Salary');
      await tester.tap(find.text('Income').last);
      await tester.tap(
        find.byKey(ValueKey('category-icon-${Icons.work_rounded.codePoint}')),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Salary'), findsOneWidget);
      expect(find.byIcon(Icons.work_rounded), findsOneWidget);
      final saved = (await tester.runAsync(
        () => services.categories.listCategories(),
      ))!.singleWhere((c) => c.name == 'Salary');
      expect(saved.kind, 'income');
      expect(saved.origin, 'custom');
      await closeServices(tester, services);
    });

    testWidgets('a duplicate of a built-in name is rejected in the form', (
      tester,
    ) async {
      services = (await tester.runAsync(createTestServices))!;
      await pumpWithServices(tester, services, const CategoriesPage());

      await openAdd(tester);
      await tester.enterText(find.byType(TextFormField), 'food');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('A category with this name already exists.'),
        findsOneWidget,
      );
      await closeServices(tester, services);
    });

    testWidgets('a built-in category can be renamed', (tester) async {
      services = (await tester.runAsync(createTestServices))!;
      await pumpWithServices(tester, services, const CategoriesPage());

      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Meals');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Meals'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      final food = (await tester.runAsync(
        () => services.categories.getCategoryById('food'),
      ))!;
      expect(food.name, 'Meals');
      await closeServices(tester, services);
    });

    testWidgets('archiving hides a category from new transactions', (
      tester,
    ) async {
      services = (await tester.runAsync(createTestServices))!;
      await pumpWithServices(tester, services, const CategoriesPage());

      await tester.tap(find.byKey(const ValueKey('archive-travel')));
      await tester.pumpAndSettle();

      final travel = (await tester.runAsync(
        () => services.categories.getCategoryById('travel'),
      ))!;
      expect(travel.isArchived, isTrue);
      expect(find.textContaining('Archived'), findsOneWidget);
      await closeServices(tester, services);
    });
  });
}
