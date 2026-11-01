import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/database_factory.dart';
import 'package:expense_tracker/core/domain/money.dart';
import 'package:expense_tracker/data/database/v2/app_database_v2.dart';
import 'package:expense_tracker/data/repositories/account_repository.dart';
import 'package:expense_tracker/data/repositories/category_repository.dart';
import 'package:expense_tracker/data/repositories/financial_transaction_repository.dart';

/// Fixed clock used by every Stage 2 repository test: 2026-03-15 12:00 UTC.
/// All ordinary test transactions are dated on or before this instant.
DateTime testNow() => DateTime.utc(2026, 3, 15, 12);

DateTime dt(int year, int month, int day, [int hour = 10]) =>
    DateTime.utc(year, month, day, hour);

Money inr(int minorUnits) => Money(minorUnits, 'INR');

/// Creates a seeded in-memory V2 database through the production factory.
Future<AppDatabaseV2> createTestDatabase() {
  return const AppDatabaseV2Factory().create(executor: NativeDatabase.memory());
}

class Stage2Fixture {
  Stage2Fixture._(this.db, this.accounts, this.categories, this.transactions);

  final AppDatabaseV2 db;
  final AccountRepository accounts;
  final CategoryRepository categories;
  final FinancialTransactionRepository transactions;

  static Future<Stage2Fixture> create({DateTime? now}) async {
    final clock = now ?? testNow();
    final db = await createTestDatabase();
    int counter = 0;
    String uuid() => 'test-${++counter}';
    return Stage2Fixture._(
      db,
      AccountRepository(db, clock: () => clock, uuidGenerator: uuid),
      CategoryRepository(db, uuidGenerator: uuid),
      FinancialTransactionRepository(
        db,
        clock: () => clock,
        uuidGenerator: uuid,
      ),
    );
  }

  Future<void> close() => db.close();

  /// Creates an asset account with no opening balance.
  Future<Account> bank({String name = 'Bank'}) {
    return accounts.createAccount(
      name: name,
      kind: 'bank',
      currencyCode: 'INR',
    );
  }

  Future<Account> cash() {
    return accounts.createAccount(
      name: 'Cash',
      kind: 'cash',
      currencyCode: 'INR',
    );
  }

  Future<Account> card() {
    return accounts.createAccount(
      name: 'Card',
      kind: 'credit_card_liability',
      currencyCode: 'INR',
    );
  }

  Future<Account> bankWithOpening(Money opening) {
    return accounts.createAccount(
      name: 'Bank',
      kind: 'bank',
      currencyCode: 'INR',
      openingBalance: opening,
      openingOccurredAt: dt(2026, 1, 1, 9),
    );
  }

  /// Asserts the postings of [tx] balance (debits == credits) and that every
  /// amount is positive.
  void assertBalanced(TransactionWithPostings tx) {
    var debits = 0;
    var credits = 0;
    for (final posting in tx.postings) {
      assert(posting.amountMinorUnits > 0, 'posting amount must be positive');
      if (posting.direction == 'debit') {
        debits += posting.amountMinorUnits;
      } else {
        credits += posting.amountMinorUnits;
      }
    }
    assert(debits == credits, 'postings must balance: $debits vs $credits');
    assert(debits > 0, 'a transaction must have postings');
  }
}

/// Loads the ledger row for a user account, through the C3 mapping rule.
Future<LedgerAccount> ledgerForAccount(
  AppDatabaseV2 db,
  Account account,
) async {
  final rows = await (db.select(
    db.ledgerAccounts,
  )..where((l) => l.userAccountId.equals(account.uuid))).get();
  assert(rows.length == 1, 'exactly one ledger row per user account');
  return rows.single;
}

/// Loads the ledger row for a category side.
Future<LedgerAccount> ledgerForCategorySide(
  AppDatabaseV2 db,
  String categoryId,
  String kind,
) async {
  final rows = await (db.select(
    db.ledgerAccounts,
  )..where((l) => l.categoryId.equals(categoryId) & l.kind.equals(kind))).get();
  assert(rows.length == 1, 'exactly one ledger row per category side');
  return rows.single;
}

/// Built-in category ids are the code ids from `expenseCategories`:
/// food, travel, shopping, bills, entertainment, health, education,
/// other. Ledger ids are `expense:<id>` / `income:<id>`.
String builtInId(String name) => name;
