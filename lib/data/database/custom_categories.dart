import 'package:drift/drift.dart';

class CustomCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get name => text()();

  IntColumn get iconCodePoint => integer()();

  DateTimeColumn get createdAt => dateTime()();
}