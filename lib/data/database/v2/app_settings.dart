import 'package:drift/drift.dart';

import 'accounts.dart';

/// Single-row application configuration (blueprint section 5.2, V2
/// model). This V2 table lives only in the V2 namespace; the legacy
/// `lib/data/database/app_settings.dart` file is untouched in Stage 1.
///
/// One row, fixed id 1, updated in place, never deleted. Settings are
/// device-local and never synced. Seed defaults below are seed values
/// only, not architecture decisions: the document-retention default
/// remains unresolved (blueprint section 16.2) and is seeded null so
/// that no default is invented here.
class AppSettings extends Table {
  IntColumn get id => integer()();

  TextColumn get currencyCode => text().withDefault(const Constant('INR'))();

  /// Optional default account. At most one default account, and none
  /// is valid. Must never be used as a fallback account for a
  /// transaction, posting, or Sheets row (later stages).
  TextColumn get defaultAccountId =>
      text().nullable().references(Accounts, #uuid)();

  /// `system`, `light`, or `dark`. Mirrors the current system
  /// behaviour; a user choice is added in Module 12.
  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  BoolColumn get appLockEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Days originals are retained. Null until the Module 7 retention
  /// default is decided.
  IntColumn get documentRetentionDays => integer().nullable()();

  IntColumn get defaultReminderDays =>
      integer().withDefault(const Constant(1))();

  /// Preference default only (approved Stage 1 seed default: true).
  /// Sheets sync remains gated by explicit Google authentication and
  /// authorisation; this flag never bypasses consent and no sync runs
  /// from seeding. No reminder scheduling or app-lock functionality
  /// is implied by any field in this table.
  BoolColumn get sheetsBackupEnabled =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get setupCompleted =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
