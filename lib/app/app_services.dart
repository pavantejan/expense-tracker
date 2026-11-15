import 'package:flutter/widgets.dart';

import '../core/backup/backup_codec.dart';
import '../core/backup/file_gateway.dart';
import '../core/database/database_factory.dart';
import '../core/sync/sync_coordinator.dart';
import '../core/sync/v2/drift_v2_sync_store.dart';
import '../core/sync/v2/google_sheets_v2_backend.dart';
import '../core/sync/v2/sheets_v2_engine.dart';
import '../data/database/v2/app_database_v2.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/financial_transaction_repository.dart';
import '../data/repositories/ledger_query_service.dart';
import '../data/repositories/merchant_tag_repository.dart';
import '../data/repositories/quick_entry_service.dart';
import '../data/repositories/template_repository.dart';

/// The app's composition root (ADR-014): the one V2 database and the
/// services built on it. Replaces the old global database singleton.
/// Production code opens it once in `main`; tests construct it over an
/// in-memory database and close it in the test body.
class AppServices {
  /// [syncBackend] defaults to the real Google Sheets V2 backend;
  /// tests pass a fake. [files] defaults to the platform file pickers.
  /// [clock] is a test seam for the repositories.
  AppServices({
    required this.database,
    SheetsV2SyncBackend? syncBackend,
    FileGateway? files,
    DateTime Function()? clock,
  }) : accounts = AccountRepository(database, clock: clock),
       categories = CategoryRepository(database),
       transactions = FinancialTransactionRepository(database, clock: clock),
       merchantsTags = MerchantTagRepository(database, clock: clock),
       templates = TemplateRepository(database, clock: clock),
       backup = BackupCodec(database, clock: clock),
       files = files ?? const PlatformFileGateway() {
    queries = LedgerQueryService(database, transactions);
    entries = QuickEntryService(
      database,
      transactions,
      accounts,
      merchantsTags,
      templates,
    );
    sync = SheetsSyncCoordinator(
      backend: syncBackend ?? GoogleSheetsV2Backend.instance,
      store: DriftV2SyncStore(database, transactions),
    );
  }

  /// Opens (or creates on first launch) the `expense_tracker_v2`
  /// database. The old `expense_tracker` file is never opened.
  static Future<AppServices> open() async {
    final database = await const AppDatabaseV2Factory().create();
    return AppServices(database: database);
  }

  final AppDatabaseV2 database;
  final AccountRepository accounts;
  final CategoryRepository categories;
  final FinancialTransactionRepository transactions;
  final MerchantTagRepository merchantsTags;
  final TemplateRepository templates;
  final BackupCodec backup;
  final FileGateway files;
  late final LedgerQueryService queries;
  late final QuickEntryService entries;
  late final SheetsSyncCoordinator sync;

  Future<void> close() async {
    sync.dispose();
    await database.close();
  }
}

/// Makes [AppServices] available to every screen.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
