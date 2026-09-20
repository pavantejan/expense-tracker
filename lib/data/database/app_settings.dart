import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}