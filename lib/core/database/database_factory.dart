import 'package:drift/drift.dart';
import 'package:expense_tracker/core/categories/category.dart';
import 'package:expense_tracker/data/database/v2/app_database_v2.dart';

/// Factory for the separate V2 database (ADR-014).
///
/// Stage 1 only: construction plus idempotent baseline seeding. This
/// factory is used by tests in Stage 1. Production startup is not
/// switched to V2 in Stage 1: `main.dart`, the production providers,
/// and notification initialisation keep using the existing database,
/// untouched. The switch happens in the coordinated Stage 5 cutover.
///
/// The factory opens only the `expense_tracker_v2` database identity,
/// requested through the default opener as
/// [expenseTrackerV2DatabaseName]. The old `expense_tracker` file is
/// never opened, modified, or deleted by this code, and the requested
/// name is verified by an automated test using a fake opener, without
/// Flutter platform channels.
///
/// The seeded `sheetsBackupEnabled` default is a preference only.
/// Sheets sync remains gated by explicit Google sign-in and
/// authorisation; the flag never bypasses consent and no sync runs
/// from seeding. No reminder scheduling or app-lock functionality is
/// added here.
///
/// Baseline seeding completes before the database is returned, so no
/// caller can observe an unseeded V2 database. Seeding is idempotent:
/// every seed row is inserted only when its primary key is absent, all
/// inside one database transaction, so opening an existing database
/// again never duplicates rows and a partially seeded database is
/// completed rather than failing on a primary-key conflict.
class AppDatabaseV2Factory {
  const AppDatabaseV2Factory();

  /// Creates (or opens) the V2 database and seeds the baseline.
  ///
  /// [executor] is test-only: tests pass an in-memory or file-backed
  /// executor. [opener] is test-only: tests substitute a fake opener
  /// to verify the requested database name without platform channels.
  /// Production callers omit both, opening the file-backed
  /// `expense_tracker_v2` database through the default opener.
  Future<AppDatabaseV2> create({
    QueryExecutor? executor,
    V2DatabaseOpener? opener,
  }) async {
    final database = AppDatabaseV2(executor, opener);
    await _seedV2Baseline(database);
    return database;
  }
}

Future<void> _seedV2Baseline(AppDatabaseV2 database) async {
  await database.transaction(() async {
    // Single settings row (fixed id 1). The document-retention default
    // is unresolved (blueprint section 16.2) and stays null here.
    // Approved seed defaults (Stage 1 checkpoint corrections):
    // INR, no default account, system theme, app lock off, retention
    // null, one reminder day, Sheets backup preference on, setup
    // incomplete. The Sheets backup preference never bypasses the
    // explicit Google authentication/authorisation gate; no sync runs
    // from seeding.
    final settings = await (database.select(
      database.appSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (settings == null) {
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              id: const Value(1),
              currencyCode: const Value('INR'),
              themeMode: const Value('system'),
              appLockEnabled: const Value(false),
              defaultReminderDays: const Value(1),
              sheetsBackupEnabled: const Value(true),
              setupCompleted: const Value(false),
            ),
          );
    }

    // Built-in categories: the code definitions in
    // `core/categories/category.dart` are the seed source of truth for
    // name and icon. All eight use kind `both` (approved decision 1).
    // Custom categories are created by users in a later stage and are
    // never seeded here.
    for (var order = 0; order < expenseCategories.length; order++) {
      final category = expenseCategories[order];
      final existing = await (database.select(
        database.categories,
      )..where((t) => t.categoryId.equals(category.id))).getSingleOrNull();
      if (existing != null) {
        continue;
      }
      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              categoryId: category.id,
              name: category.name,
              iconCodePoint: category.icon.codePoint,
              kind: 'both',
              origin: 'builtin',
              displayOrder: Value(order),
            ),
          );
    }

    // System ledger accounts: one opening-equity row, one adjustments
    // row, and two rows per built-in category (expense and income).
    // Ledger ids are the fixed system ids from blueprint section 5.2.
    await _insertLedgerIfAbsent(
      database,
      LedgerAccountsCompanion.insert(
        ledgerAccountId: 'opening_equity',
        kind: 'system_opening_equity',
        isSystem: const Value(true),
        normalBalance: 'credit',
      ),
    );
    await _insertLedgerIfAbsent(
      database,
      LedgerAccountsCompanion.insert(
        ledgerAccountId: 'adjustments',
        kind: 'system_adjustment',
        isSystem: const Value(true),
        normalBalance: 'credit',
      ),
    );
    for (final category in expenseCategories) {
      await _insertLedgerIfAbsent(
        database,
        LedgerAccountsCompanion.insert(
          ledgerAccountId: 'expense:${category.id}',
          kind: 'system_expense',
          categoryId: Value(category.id),
          isSystem: const Value(true),
          normalBalance: 'debit',
        ),
      );
      await _insertLedgerIfAbsent(
        database,
        LedgerAccountsCompanion.insert(
          ledgerAccountId: 'income:${category.id}',
          kind: 'system_income',
          categoryId: Value(category.id),
          isSystem: const Value(true),
          normalBalance: 'credit',
        ),
      );
    }
  });
}

Future<void> _insertLedgerIfAbsent(
  AppDatabaseV2 database,
  LedgerAccountsCompanion row,
) async {
  final id = row.ledgerAccountId.value;
  final existing = await (database.select(
    database.ledgerAccounts,
  )..where((t) => t.ledgerAccountId.equals(id))).getSingleOrNull();
  if (existing == null) {
    await database.into(database.ledgerAccounts).insert(row);
  }
}
