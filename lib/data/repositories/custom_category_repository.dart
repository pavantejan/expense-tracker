import 'package:drift/drift.dart';

import '../../core/categories/category.dart';
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

  /// Whether [trimmedName] collides with a built-in category,
  /// case-insensitively. The built-in definitions in
  /// `expenseCategories` are the single source of truth; the
  /// names are never duplicated here.
  bool _isBuiltInName(String trimmedName) {
    final lowered = trimmedName.toLowerCase();
    return expenseCategories.any(
      (category) => category.name.toLowerCase() == lowered,
    );
  }

  /// Shared name validation for [addCategory], [updateCategory],
  /// and [renameCategory]. Throws [ArgumentError] when the name
  /// is empty, collides with a built-in category, or duplicates
  /// another custom category's name (trimmed, case-insensitive).
  /// Safe to call inside a database transaction: the duplicate
  /// check reads through the same database connection.
  Future<void> _ensureNameAvailable(String name, {int? excludeId}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (_isBuiltInName(trimmedName)) {
      throw ArgumentError('"$trimmedName" is already a built-in category.');
    }
    if (await categoryNameExists(trimmedName, excludeId: excludeId)) {
      throw ArgumentError(
        'A custom category named "$trimmedName" already exists.',
      );
    }
  }

  Future<int> addCategory({
    required String uuid,
    required String name,
    required int iconCodePoint,
  }) async {
    await _ensureNameAvailable(name);
    return _database
        .into(_database.customCategories)
        .insert(
          CustomCategoriesCompanion.insert(
            uuid: uuid,
            name: name.trim(),
            iconCodePoint: iconCodePoint,
            createdAt: DateTime.now(),
          ),
        );
  }

  /// Updates the category row with [id], safely.
  ///
  /// This delegates to [renameCategory], the single write path
  /// for custom categories: the category row and the matching
  /// local transactions are updated atomically, in one
  /// database transaction, using the row's actual stored name.
  /// There is no public rename operation that bypasses the
  /// historical transaction update.
  ///
  /// Returns `false` when no category with [id] exists and
  /// nothing is modified. Throws [ArgumentError] when [name]
  /// is empty, collides with a built-in category, or
  /// duplicates another custom category's name.
  Future<bool> updateCategory({
    required int id,
    required String name,
    required int iconCodePoint,
  }) {
    return renameCategory(id: id, name: name, iconCodePoint: iconCodePoint);
  }

  /// Renames a custom category and the local transactions that
  /// use its stored name, atomically, in one database
  /// transaction.
  ///
  /// - The current category row is read inside the same
  ///   transaction; the caller never supplies the old name, so
  ///   a stale or wrong old name cannot rename the wrong
  ///   transactions. Only transactions whose stored category
  ///   text equals the row's actual stored name are updated.
  /// - Returns `false` (and changes nothing) when [id] does
  ///   not exist.
  /// - Each renamed transaction gets a strictly increasing
  ///   revision timestamp and `syncStatus: 'pending'`,
  ///   following the same revision rule as
  ///   `TransactionRepository` local mutations, so the renamed
  ///   rows re-sync through the existing Sheets sync. Deleted
  ///   (soft-deleted) rows are included: their tombstones carry
  ///   the category text, and the sync engine keys tombstones
  ///   by UUID, so renaming them keeps tombstone revisions
  ///   consistent.
  /// - When only the icon changes ([name] equals the stored
  ///   name), no transaction row is touched.
  /// - Throws [ArgumentError] when [name] is empty, collides
  ///   with a built-in category, or duplicates another custom
  ///   category's name. A throw rolls the transaction back, so
  ///   a rejected rename changes nothing.
  /// - Deleting is separate: [deleteCategory] never touches
  ///   transactions, so historical rows keep their text.
  Future<bool> renameCategory({
    required int id,
    required String name,
    required int iconCodePoint,
  }) async {
    return _database.transaction(() async {
      final existing = await (_database.select(
        _database.customCategories,
      )..where((category) => category.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        return false;
      }
      await _ensureNameAvailable(name, excludeId: id);
      final trimmedName = name.trim();
      await (_database.update(
        _database.customCategories,
      )..where((category) => category.id.equals(id))).write(
        CustomCategoriesCompanion(
          name: Value(trimmedName),
          iconCodePoint: Value(iconCodePoint),
        ),
      );
      if (trimmedName != existing.name) {
        final matching = await (_database.select(
          _database.transactions,
        )..where((t) => t.category.equals(existing.name))).get();
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
