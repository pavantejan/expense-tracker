import 'package:drift/drift.dart';

import '../database/app_database.dart';

class CustomCategoryRepository {
  CustomCategoryRepository(this._database);

  final AppDatabase _database;

  Stream<List<CustomCategory>> watchAllCategories() {
    return (_database.select(_database.customCategories)
          ..orderBy([(category) => OrderingTerm(expression: category.name)]))
        .watch();
  }

  Future<List<CustomCategory>> getAllCategories() {
    return (_database.select(
      _database.customCategories,
    )..orderBy([(category) => OrderingTerm(expression: category.name)])).get();
  }

  Future<CustomCategory?> getCategoryById(int id) {
    return (_database.select(
      _database.customCategories,
    )..where((category) => category.id.equals(id))).getSingleOrNull();
  }

  Future<CustomCategory?> getCategoryByName(String name) {
    return (_database.select(
      _database.customCategories,
    )..where((category) => category.name.equals(name))).getSingleOrNull();
  }

  /// Whether a custom category with [name] already exists,
  /// comparing trimmed names case-insensitively. The category
  /// with [excludeId], when given, is ignored (editing a
  /// category without renaming it is not a duplicate).
  ///
  /// The comparison runs in Dart over the stored rows: the
  /// custom-category table is tiny, and SQLite `=` on text is
  /// case-sensitive, so a SQL equality check would miss
  /// case-only duplicates such as "gym" vs "Gym".
  Future<bool> categoryNameExists(String name, {int? excludeId}) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final categories = await getAllCategories();
    return categories.any(
      (category) =>
          category.id != excludeId &&
          category.name.trim().toLowerCase() == normalized,
    );
  }

  Future<int> addCategory({
    required String uuid,
    required String name,
    required int iconCodePoint,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (await categoryNameExists(trimmedName)) {
      throw ArgumentError(
        'A custom category named "$trimmedName" already exists.',
      );
    }
    return _database
        .into(_database.customCategories)
        .insert(
          CustomCategoriesCompanion.insert(
            uuid: uuid,
            name: trimmedName,
            iconCodePoint: iconCodePoint,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Updates only the row with [id] (Drift `where` clause).
  ///
  /// Returns `false` when no category with [id] exists and no
  /// row is modified. Throws [ArgumentError] when [name]
  /// (trimmed, case-insensitive) duplicates another custom
  /// category's name. Previously this method wrote without a
  /// `where` clause and would have updated every row.
  Future<bool> updateCategory({
    required int id,
    required String name,
    required int iconCodePoint,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (await categoryNameExists(trimmedName, excludeId: id)) {
      throw ArgumentError(
        'A custom category named "$trimmedName" already exists.',
      );
    }
    final updatedRows =
        await (_database.update(
          _database.customCategories,
        )..where((category) => category.id.equals(id))).write(
          CustomCategoriesCompanion(
            name: Value(trimmedName),
            iconCodePoint: Value(iconCodePoint),
          ),
        );
    return updatedRows > 0;
  }

  /// Renames a custom category and the local transactions that
  /// use its old name, atomically, in one database transaction.
  ///
  /// - The category row is updated only where `id` matches;
  ///   returns `false` (and changes nothing) when [id] does not
  ///   exist.
  /// - When [name] differs from [oldName], every transaction
  ///   whose stored category text equals [oldName] is updated
  ///   to [name], each with a strictly increasing revision
  ///   timestamp and `syncStatus: 'pending'`, following the
  ///   same revision rule as
  ///   `TransactionRepository` local mutations, so the renamed
  ///   rows re-sync through the existing Sheets sync. Deleted
  ///   (soft-deleted) rows are included: their tombstones carry
  ///   the category text, and the sync engine keys tombstones
  ///   by UUID, so renaming them is safe.
  /// - When only the icon changes ([name] equals [oldName]),
  ///   no transaction row is touched.
  /// - Throws [ArgumentError] when [name] duplicates another
  ///   custom category's name (trimmed, case-insensitive).
  /// - Deleting is separate: [deleteCategory] never touches
  ///   transactions, so historical rows keep their text.
  Future<bool> renameCategory({
    required int id,
    required String oldName,
    required String name,
    required int iconCodePoint,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (await categoryNameExists(trimmedName, excludeId: id)) {
      throw ArgumentError(
        'A custom category named "$trimmedName" already exists.',
      );
    }
    return _database.transaction(() async {
      final updatedRows =
          await (_database.update(
            _database.customCategories,
          )..where((category) => category.id.equals(id))).write(
            CustomCategoriesCompanion(
              name: Value(trimmedName),
              iconCodePoint: Value(iconCodePoint),
            ),
          );
      if (updatedRows == 0) {
        return false;
      }
      if (trimmedName != oldName) {
        final matching = await (_database.select(
          _database.transactions,
        )..where((t) => t.category.equals(oldName))).get();
        for (final row in matching) {
          await (_database.update(
            _database.transactions,
          )..where((t) => t.id.equals(row.id))).write(
            TransactionsCompanion(
              category: Value(trimmedName),
              updatedAt: Value(_nextRevisionAfter(row.updatedAt)),
              syncStatus: const Value('pending'),
            ),
          );
        }
      }
      return true;
    });
  }

  /// Revision timestamp for a renamed transaction row.
  ///
  /// Same rule as `TransactionRepository._nextUpdatedAt`:
  /// strictly increasing, at least 1ms beyond the previous
  /// stored value, so two distinct local writes never share a
  /// revision even inside the same millisecond. Kept in sync
  /// with that method by convention; both are covered by the
  /// conditional-ack tests through the sync behaviour.
  DateTime _nextRevisionAfter(DateTime previous) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final previousMs = previous.millisecondsSinceEpoch;
    final nextMs = nowMs > previousMs ? nowMs : previousMs + 1;
    return DateTime.fromMillisecondsSinceEpoch(nextMs);
  }

  Future<bool> deleteCategory(int id) async {
    final deletedRows = await (_database.delete(
      _database.customCategories,
    )..where((category) => category.id.equals(id))).go();

    return deletedRows > 0;
  }
}
