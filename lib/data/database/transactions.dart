import 'package:drift/drift.dart';

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get type => text()();

  RealColumn get amount => real()();

  TextColumn get category => text()();

  TextColumn get description => text().nullable()();

  TextColumn get paymentMethod => text()();

  DateTimeColumn get transactionDate => dateTime()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  TextColumn get syncStatus => text()();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
}