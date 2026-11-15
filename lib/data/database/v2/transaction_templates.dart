import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import 'merchants_tags.dart';

/// A saved, reusable transaction (Module 2 templates and favourites).
///
/// A template never posts anything by itself: applying it pre-fills the
/// add form, and saving that form creates a normal transaction with
/// `source = template`. References are nullable and validated when the
/// form is saved, so an archived account or category in a template just
/// needs re-picking. [amountMinorUnits] may be null for "ask every time".
class TransactionTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  TextColumn get name => text()();

  /// `expense`, `income`, or `transfer`.
  TextColumn get kind => text()();

  IntColumn get amountMinorUnits => integer().nullable()();

  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  @ReferenceName('templateAccounts')
  TextColumn get accountId => text().nullable().references(Accounts, #uuid)();

  @ReferenceName('templateSources')
  TextColumn get sourceAccountId =>
      text().nullable().references(Accounts, #uuid)();

  @ReferenceName('templateDestinations')
  TextColumn get destinationAccountId =>
      text().nullable().references(Accounts, #uuid)();

  TextColumn get categoryId =>
      text().nullable().references(Categories, #categoryId)();

  TextColumn get merchantId => text().nullable().references(Merchants, #uuid)();

  /// Comma-separated tag uuids.
  TextColumn get tagIds => text().withDefault(const Constant(''))();

  TextColumn get paymentChannel => text().withDefault(const Constant('UPI'))();

  TextColumn get description => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// Pinned as a one-tap chip on the add screen.
  BoolColumn get isFavourite => boolean().withDefault(const Constant(true))();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  List<String> get customConstraints => const [
    'CHECK (amount_minor_units IS NULL OR amount_minor_units > 0)',
  ];
}
