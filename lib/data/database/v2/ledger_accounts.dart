import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';

/// The ledger-level account every posting references (blueprint
/// sections 5.2 and 6.3).
///
/// This is the single posting-target abstraction: user accounts,
/// per-category system accounts, and the opening-equity and adjustment
/// system accounts are all ledger accounts of different kinds. System
/// ledger accounts are never shown as user accounts; account pickers
/// and balances query `isSystem = false` only (enforced by callers in
/// later stages).
///
/// Exactly one of [userAccountId] and [categoryId] is set for user and
/// category-system rows; neither is set for `opening_equity` and
/// `adjustments`. That rule is enforced by the service layer in a later
/// stage; the database enforces the foreign keys, the unique mappings,
/// and the existence of every referenced row.
@TableIndex(
  name: 'ledger_accounts_category_kind',
  columns: {#categoryId, #kind},
  unique: true,
)
class LedgerAccounts extends Table {
  /// Stable string id. User rows use the account uuid; system rows use
  /// fixed ids: `opening_equity`, `adjustments`,
  /// `expense:<categoryId>`, `income:<categoryId>`.
  TextColumn get ledgerAccountId => text()();

  /// `user_asset`, `user_liability`, `system_expense`,
  /// `system_income`, `system_opening_equity`, or `system_adjustment`.
  TextColumn get kind => text()();

  /// Set exactly when [kind] is `user_asset` or `user_liability`.
  TextColumn get userAccountId =>
      text().nullable().unique().references(Accounts, #uuid)();

  /// Set exactly when [kind] is `system_expense` or `system_income`.
  TextColumn get categoryId =>
      text().nullable().references(Categories, #categoryId)();

  /// True for every `system_*` kind.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// Normal balance side: `debit` or `credit`. Asset and expense
  /// accounts are normal-debit; liability, income, opening-equity, and
  /// adjustment accounts are normal-credit (blueprint section 6.3).
  TextColumn get normalBalance => text()();

  /// Mirrors the archival state of its account or category.
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {ledgerAccountId};
}
