import 'package:drift/drift.dart';

/// Stable classification (blueprint section 5.2, V2 model).
///
/// Transactions reference [categoryId], never a display name, so a
/// rename is a Category-row update only and history stays valid. The
/// `parentCategoryId` column is included nullable and unused in
/// Module 1; subcategories are deferred (blueprint section 5.2).
@TableIndex(name: 'categories_kind', columns: {#kind})
class Categories extends Table {
  /// Stable string id. Built-ins keep their existing ids (`food`,
  /// `travel`, `shopping`, `bills`, `entertainment`, `health`,
  /// `education`, `other`). Custom categories use `custom_<uuid>`.
  TextColumn get categoryId => text()();

  TextColumn get name => text()();

  /// Material icon code point.
  IntColumn get iconCodePoint => integer()();

  /// ARGB colour value, nullable when no colour was chosen.
  IntColumn get colorValue => integer().nullable()();

  /// `expense`, `income`, or `both`. All eight built-in categories use
  /// `both`; custom categories support all three kinds.
  TextColumn get kind => text()();

  /// `builtin` or `custom`.
  TextColumn get origin => text()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Nullable self-reference for future subcategories. Unused in
  /// Module 1; no category in the baseline seed sets it.
  TextColumn get parentCategoryId =>
      text().nullable().references(Categories, #categoryId)();

  IntColumn get displayOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {categoryId};
}
