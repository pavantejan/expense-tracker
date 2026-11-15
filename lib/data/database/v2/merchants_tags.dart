import 'package:drift/drift.dart';

import 'categories.dart';

/// Named counterparty (blueprint section 5.2, Module 2). Purpose: fast
/// logging, analytics by payee, import matching.
///
/// [nameKey] is the trimmed, lower-cased name and is unique, so names
/// are unique case-insensitively. Deleting a merchant nulls the
/// reference on transactions; their description text is kept.
class Merchants extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get name => text()();

  TextColumn get nameKey => text().unique()();

  /// Learned or user-set category suggested when this merchant is picked.
  TextColumn get defaultCategoryId =>
      text().nullable().references(Categories, #categoryId)();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();
}

/// Free-form label such as `trip-goa` (blueprint section 5.2). Names are
/// unique case-insensitively through [nameKey].
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get name => text()();

  TextColumn get nameKey => text().unique()();

  IntColumn get colorValue => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
