import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'accounts.dart';
import 'app_settings.dart';
import 'categories.dart';
import 'financial_transactions.dart';
import 'ledger_accounts.dart';
import 'notifications.dart';
import 'postings.dart';
import 'transaction_history.dart';

part 'app_database_v2.g.dart';

/// File-backed database identity for the V2 database.
///
/// Single source of truth for the production database name. The factory
/// requests exactly this name through the default opener; tests
/// substitute a fake opener and assert the requested name, so the
/// identity is verified by an automated test without Flutter platform
/// channels. The old `expense_tracker` identity is never requested by
/// V2 code.
const String expenseTrackerV2DatabaseName = 'expense_tracker_v2';

/// Opens the file-backed V2 database for [name].
///
/// The production implementation uses drift_flutter. Tests substitute
/// a fake implementation that records [name] and returns an in-memory
/// executor, which is the seam the factory-identity test uses.
typedef V2DatabaseOpener = QueryExecutor Function(String name);

/// The separate V2 database for the Module 1 financial model
/// (blueprint sections 5 and 7, ADR-005, ADR-014).
///
/// This class is deliberately separate from the existing [AppDatabase]:
/// different database identity ([expenseTrackerV2DatabaseName]),
/// different schema (version 8, created with `onCreate`), and no
/// migration from the v7 database. The old database file is never
/// opened by this code.
///
/// Production construction must go through the V2 database factory
/// (`lib/core/database/database_factory.dart`), which runs the
/// idempotent baseline seeding before returning the database. The
/// optional [executor] parameter is test-only: tests pass an
/// in-memory or file-backed executor. The optional [opener] parameter
/// is also test-only: tests substitute a fake opener to verify the
/// requested database name without platform channels. Constructing
/// this class directly without the factory does not seed the baseline.
///
/// Foreign keys are enforced: [MigrationStrategy.beforeOpen] enables
/// `PRAGMA foreign_keys = ON`, as required by Drift for SQLite.
/// Stage 1 tests verify enforcement by attempting an orphan insert
/// and by reading the pragma back; enforcement is never assumed.
@DriftDatabase(
  tables: [
    Accounts,
    LedgerAccounts,
    Categories,
    FinancialTransactions,
    Postings,
    TransactionHistory,
    AppSettings,
    Notifications,
  ],
)
class AppDatabaseV2 extends _$AppDatabaseV2 {
  AppDatabaseV2([QueryExecutor? executor, V2DatabaseOpener? opener])
    : super(
        executor ?? (opener ?? _defaultOpener)(expenseTrackerV2DatabaseName),
      );

  static QueryExecutor _defaultOpener(String name) {
    return driftDatabase(name: name);
  }

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
