import 'package:drift/drift.dart';

import '../database/app_database.dart';

class CustomCategoryRepository {
  CustomCategoryRepository(this._database);

  final AppDatabase _database;

  Stream<List<CustomCategory>> watchAllCategories() {
    return (_database.select(_database.customCategories)
          ..orderBy([
            (category) =>
                OrderingTerm(expression: category.name),
          ]))
        .watch();
  }

  Future<List<CustomCategory>> getAllCategories() {
    return (_database.select(_database.customCategories)
          ..orderBy([
            (category) =>
                OrderingTerm(expression: category.name),
          ]))
        .get();
  }

  Future<CustomCategory?> getCategoryById(int id) {
    return (_database.select(_database.customCategories)
          ..where((category) => category.id.equals(id)))
        .getSingleOrNull();
  }

  Future<CustomCategory?> getCategoryByName(String name) {
    return (_database.select(_database.customCategories)
          ..where((category) => category.name.equals(name)))
        .getSingleOrNull();
  }

  Future<int> addCategory({
    required String uuid,
    required String name,
    required int iconCodePoint,
  }) {
    return _database.into(_database.customCategories).insert(
          CustomCategoriesCompanion.insert(
            uuid: uuid,
            name: name,
            iconCodePoint: iconCodePoint,
            createdAt: DateTime.now(),
          ),
        );
  }

  Future<bool> updateCategory({
    required int id,
    required String name,
    required int iconCodePoint,
  }) async {
    return _database.update(_database.customCategories).write(
          CustomCategoriesCompanion(
            name: Value(name),
            iconCodePoint: Value(iconCodePoint),
          ),
        ).then((updatedRows) => updatedRows > 0);
  }

  Future<bool> deleteCategory(int id) async {
    final deletedRows = await (_database.delete(
      _database.customCategories,
    )..where((category) => category.id.equals(id)))
        .go();

    return deletedRows > 0;
  }
}