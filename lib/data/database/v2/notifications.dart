import 'package:drift/drift.dart';

/// In-app notification records (V2 model).
///
/// Same shape as the existing notifications table, carried over into
/// the separate V2 database starting empty. Existing rows do not
/// migrate. Notifications remain in-app only in Module 1; there is no
/// OS scheduling capability yet (Module 5).
class Notifications extends Table {
  TextColumn get id => text()();

  TextColumn get type => text()();

  TextColumn get title => text()();

  TextColumn get message => text()();

  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get isRead => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
