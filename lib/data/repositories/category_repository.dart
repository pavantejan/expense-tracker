// V2 category repository (blueprint sections 5.2, 6.3).
//
// V2-only. Creating a custom category creates its ledger accounts
// in the same database transaction (one per applicable side for its
// kind). Renaming a built-in category is rejected: built-in renaming
// is unresolved (blueprint section 16.2). Kind changes are rejected
// once any posting references the category's ledgers, including
// postings of soft-deleted transactions (C2); at zero postings the
// ledger set is adjusted (missing sides created, removed sides
// archived — ledger rows are never hard-deleted) in the same
// transaction. Archival mirrors onto every category ledger row.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/domain/ledger/posting_rules.dart';
import '../database/v2/app_database_v2.dart';

/// Category kinds, as stored on `Categories.kind`.
const Set<String> categoryKinds = <String>{'expense', 'income', 'both'};

class CategoryRepository {
  CategoryRepository(this._database, {String Function()? uuidGenerator})
    : _newUuid = uuidGenerator ?? (() => const Uuid().v4());

  final AppDatabaseV2 _database;
  final String Function() _newUuid;

  /// Creates a custom category (`custom_<uuid>`) with its ledger
  /// accounts: expense side unless kind is `income`, income side
  /// unless kind is `expense`. Built-in categories are seeded by the
  /// factory and are never created here.
  Future<Category> createCategory({
    required String name,
    required String kind,
    required int iconCodePoint,
    int? colorValue,
    int displayOrder = 0,
  }) async {
    if (name.trim().isEmpty) {
      throw const PostingValidationException(
        'Category name must not be empty.',
      );
    }
    if (!categoryKinds.contains(kind)) {
      throw PostingValidationException('Unknown category kind: $kind.');
    }
    return _database.transaction(() async {
      final categoryId = 'custom_${_newUuid()}';
      await _database
          .into(_database.categories)
          .insert(
            CategoriesCompanion.insert(
              categoryId: categoryId,
              name: name,
              iconCodePoint: iconCodePoint,
              colorValue: Value(colorValue),
              kind: kind,
              origin: 'custom',
              displayOrder: Value(displayOrder),
            ),
          );
      await _ensureLedger(categoryId, ReportingKind.expense, kind);
      await _ensureLedger(categoryId, ReportingKind.income, kind);
      return (await getCategoryById(categoryId))!;
    });
  }

  Future<Category?> getCategoryById(String categoryId) async {
    return (_database.select(
      _database.categories,
    )..where((t) => t.categoryId.equals(categoryId))).getSingleOrNull();
  }

  Future<List<Category>> listCategories({bool includeArchived = true}) async {
    final query = _database.select(_database.categories)
      ..orderBy([
        (t) => OrderingTerm(expression: t.displayOrder),
        (t) => OrderingTerm(expression: t.categoryId),
      ]);
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    return query.get();
  }

  /// Ledger accounts for a category, keyed by ledger account id.
  Future<Map<String, LedgerAccount>> ledgersForCategory(
    String categoryId,
  ) async {
    final rows = await (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.categoryId.equals(categoryId))).get();
    return <String, LedgerAccount>{
      for (final row in rows) row.ledgerAccountId: row,
    };
  }

  /// The ledger account for one side of a category, resolved through
  /// (`categoryId`, `kind`) via the unique index (C3). Returns null
  /// when the category has no ledger for that side.
  Future<LedgerAccount?> ledgerForCategorySide(
    String categoryId,
    ReportingKind side,
  ) async {
    final ledgerId = side == ReportingKind.expense
        ? 'expense:$categoryId'
        : 'income:$categoryId';
    return (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.ledgerAccountId.equals(ledgerId))).getSingleOrNull();
  }

  /// Presentation edits. Name changes are custom-only (built-in
  /// renaming is unresolved); icon, colour, and display order may
  /// change for any category.
  Future<Category> updateCategoryPresentation(
    String categoryId, {
    String? name,
    int? iconCodePoint,
    int? colorValue,
    int? displayOrder,
  }) async {
    final existing = await getCategoryById(categoryId);
    if (existing == null) {
      throw PostingValidationException('Unknown category: $categoryId.');
    }
    if (name != null) {
      if (name.trim().isEmpty) {
        throw const PostingValidationException(
          'Category name must not be empty.',
        );
      }
      if (existing.origin == 'builtin') {
        throw const PostingValidationException(
          'Built-in category renaming is unresolved and not allowed.',
        );
      }
    }
    await (_database.update(
      _database.categories,
    )..where((t) => t.categoryId.equals(categoryId))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        iconCodePoint: iconCodePoint == null
            ? const Value.absent()
            : Value(iconCodePoint),
        colorValue: colorValue == null
            ? const Value.absent()
            : Value(colorValue),
        displayOrder: displayOrder == null
            ? const Value.absent()
            : Value(displayOrder),
      ),
    );
    return (await getCategoryById(categoryId))!;
  }

  /// Changes a category's kind. Rejected once any posting references
  /// any of the category's ledger accounts, including postings of
  /// soft-deleted transactions. At zero postings, ledger rows for
  /// newly included sides are created (or unarchived), and ledger
  /// rows for removed sides are archived, in the same transaction.
  /// Ledger rows are never hard-deleted.
  Future<Category> changeCategoryKind(
    String categoryId, {
    required String newKind,
  }) async {
    if (!categoryKinds.contains(newKind)) {
      throw PostingValidationException('Unknown category kind: $newKind.');
    }
    return _database.transaction(() async {
      final existing = await getCategoryById(categoryId);
      if (existing == null) {
        throw PostingValidationException('Unknown category: $categoryId.');
      }
      if (existing.kind == newKind) {
        return existing;
      }
      final ledgers = await ledgersForCategory(categoryId);
      for (final ledger in ledgers.values) {
        final count = await _postingCountForLedger(ledger.ledgerAccountId);
        if (count > 0) {
          throw const PostingValidationException(
            'A category kind cannot change once postings reference '
            'its ledger accounts, including postings of soft-deleted '
            'transactions.',
          );
        }
      }
      await (_database.update(_database.categories)
            ..where((t) => t.categoryId.equals(categoryId)))
          .write(CategoriesCompanion(kind: Value(newKind)));
      await _ensureLedger(categoryId, ReportingKind.expense, newKind);
      await _ensureLedger(categoryId, ReportingKind.income, newKind);
      return (await getCategoryById(categoryId))!;
    });
  }

  /// Archives a category and mirrors archival onto its ledger
  /// accounts in the same transaction. New transactions must reject
  /// archived categories (C1); history and balances are preserved.
  Future<Category> archiveCategory(String categoryId) async {
    return _database.transaction(() async {
      final existing = await getCategoryById(categoryId);
      if (existing == null) {
        throw PostingValidationException('Unknown category: $categoryId.');
      }
      await (_database.update(_database.categories)
            ..where((t) => t.categoryId.equals(categoryId)))
          .write(const CategoriesCompanion(isArchived: Value(true)));
      await _setLedgersArchived(categoryId, true);
      return (await getCategoryById(categoryId))!;
    });
  }

  /// Restores an archived category and clears archival on its ledger
  /// accounts in the same transaction.
  Future<Category> restoreCategory(String categoryId) async {
    return _database.transaction(() async {
      final existing = await getCategoryById(categoryId);
      if (existing == null) {
        throw PostingValidationException('Unknown category: $categoryId.');
      }
      await (_database.update(_database.categories)
            ..where((t) => t.categoryId.equals(categoryId)))
          .write(const CategoriesCompanion(isArchived: Value(false)));
      await _setLedgersArchived(categoryId, false);
      return (await getCategoryById(categoryId))!;
    });
  }

  /// Creates (or unarchives) the ledger row for one side when the
  /// category kind includes it; archives it when the kind excludes
  /// it. Must run inside a database transaction with the caller.
  Future<void> _ensureLedger(
    String categoryId,
    ReportingKind side,
    String categoryKind,
  ) async {
    final wantsSide =
        categoryKind == 'both' ||
        (side == ReportingKind.expense && categoryKind == 'expense') ||
        (side == ReportingKind.income && categoryKind == 'income');
    final ledgerId = side == ReportingKind.expense
        ? 'expense:$categoryId'
        : 'income:$categoryId';
    final existing = await (_database.select(
      _database.ledgerAccounts,
    )..where((t) => t.ledgerAccountId.equals(ledgerId))).getSingleOrNull();
    if (wantsSide) {
      if (existing == null) {
        await _database
            .into(_database.ledgerAccounts)
            .insert(
              LedgerAccountsCompanion.insert(
                ledgerAccountId: ledgerId,
                kind: side == ReportingKind.expense
                    ? ledgerKindSystemExpense
                    : ledgerKindSystemIncome,
                categoryId: Value(categoryId),
                isSystem: const Value(true),
                normalBalance: side == ReportingKind.expense
                    ? LedgerDirection.debit.value
                    : LedgerDirection.credit.value,
              ),
            );
      } else if (existing.isArchived) {
        await (_database.update(_database.ledgerAccounts)
              ..where((t) => t.ledgerAccountId.equals(ledgerId)))
            .write(const LedgerAccountsCompanion(isArchived: Value(false)));
      }
    } else if (existing != null && !existing.isArchived) {
      await (_database.update(_database.ledgerAccounts)
            ..where((t) => t.ledgerAccountId.equals(ledgerId)))
          .write(const LedgerAccountsCompanion(isArchived: Value(true)));
    }
  }

  Future<void> _setLedgersArchived(String categoryId, bool archived) async {
    final ledgers = await ledgersForCategory(categoryId);
    for (final ledger in ledgers.values) {
      await (_database.update(_database.ledgerAccounts)
            ..where((t) => t.ledgerAccountId.equals(ledger.ledgerAccountId)))
          .write(LedgerAccountsCompanion(isArchived: Value(archived)));
    }
  }

  Future<int> _postingCountForLedger(String ledgerAccountId) async {
    final rows = await (_database.select(
      _database.postings,
    )..where((t) => t.ledgerAccountId.equals(ledgerAccountId))).get();
    return rows.length;
  }
}
