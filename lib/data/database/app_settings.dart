import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer()();

  RealColumn get openingBalance => real().withDefault(const Constant(0))();

  DateTimeColumn get openingBalanceDate => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}