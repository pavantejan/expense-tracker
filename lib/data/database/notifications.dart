import 'package:drift/drift.dart';

class Notifications extends Table {
  TextColumn get id => text()();

  TextColumn get type => text()();

  TextColumn get title => text()();

  TextColumn get message => text()();

  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get isRead =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}