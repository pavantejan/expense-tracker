// Read models for screens (V2).
//
// Lists transactions with their resolved account/category names and a
// per-row display direction, and streams reporting output. All totals
// and balances come from the canonical reporting layer
// (`core/domain/reporting.dart`); this file never sums amounts.

import 'package:drift/drift.dart';

import '../../core/domain/reporting.dart';
import '../database/v2/app_database_v2.dart';
import 'financial_transaction_repository.dart';
import 'merchant_tag_repository.dart';

/// How a transaction moved money from the user's point of view.
enum DisplayFlow {
  /// Money in (asset up) or debt down.
  inflow,

  /// Money out (asset down) or debt up.
  outflow,

  /// Between the user's own accounts (transfers, card payments).
  neutral,
}

class TransactionView {
  const TransactionView({
    required this.transaction,
    required this.flow,
    required this.isReversed,
    this.category,
    this.account,
    this.sourceAccount,
    this.destinationAccount,
    this.merchant,
    this.tags = const [],
  });

  final FinancialTransaction transaction;
  final DisplayFlow flow;

  /// True when an active reversal references this transaction.
  final bool isReversed;
  final Category? category;

  /// The account whose balance this transaction moves (expense,
  /// income, refund, adjustment, opening balance, and their reversals).
  final Account? account;
  final Account? sourceAccount;
  final Account? destinationAccount;
  final Merchant? merchant;
  final List<Tag> tags;

  String get uuid => transaction.uuid;
  String get kind => transaction.kind;
  bool get isDeleted => transaction.status == 'deleted';

  /// Text a search query is matched against.
  String get searchText => [
    transaction.description,
    transaction.notes,
    transaction.paymentChannel,
    category?.name,
    account?.name,
    sourceAccount?.name,
    destinationAccount?.name,
    merchant?.name,
    ...tags.map((t) => t.name),
  ].whereType<String>().join(' ').toLowerCase();
}

/// Optional filters for the transaction list. Every set field must
/// match; amounts compare integer minor units.
class TransactionFilter {
  const TransactionFilter({
    this.from,
    this.toInclusive,
    this.categoryId,
    this.accountUuid,
    this.merchantUuid,
    this.tagId,
    this.minAmountMinorUnits,
    this.maxAmountMinorUnits,
    this.kinds = const {},
  });

  final DateTime? from;
  final DateTime? toInclusive;
  final String? categoryId;
  final String? accountUuid;
  final String? merchantUuid;
  final int? tagId;
  final int? minAmountMinorUnits;
  final int? maxAmountMinorUnits;
  final Set<String> kinds;

  bool get isEmpty =>
      from == null &&
      toInclusive == null &&
      categoryId == null &&
      accountUuid == null &&
      merchantUuid == null &&
      tagId == null &&
      minAmountMinorUnits == null &&
      maxAmountMinorUnits == null &&
      kinds.isEmpty;

  int get activeCount => [
    from != null || toInclusive != null,
    categoryId != null,
    accountUuid != null,
    merchantUuid != null,
    tagId != null,
    minAmountMinorUnits != null || maxAmountMinorUnits != null,
    kinds.isNotEmpty,
  ].where((active) => active).length;

  bool matches(TransactionView view) {
    final tx = view.transaction;
    final date = tx.occurredAt.toLocal();
    final day = DateTime(date.year, date.month, date.day);
    if (from != null && day.isBefore(from!)) {
      return false;
    }
    if (toInclusive != null && day.isAfter(toInclusive!)) {
      return false;
    }
    if (categoryId != null && tx.categoryId != categoryId) {
      return false;
    }
    if (accountUuid != null &&
        view.account?.uuid != accountUuid &&
        view.sourceAccount?.uuid != accountUuid &&
        view.destinationAccount?.uuid != accountUuid) {
      return false;
    }
    if (merchantUuid != null && tx.merchantId != merchantUuid) {
      return false;
    }
    if (tagId != null && !view.tags.any((t) => t.id == tagId)) {
      return false;
    }
    if (minAmountMinorUnits != null &&
        tx.amountMinorUnits < minAmountMinorUnits!) {
      return false;
    }
    if (maxAmountMinorUnits != null &&
        tx.amountMinorUnits > maxAmountMinorUnits!) {
      return false;
    }
    if (kinds.isNotEmpty && !kinds.contains(tx.kind)) {
      return false;
    }
    return true;
  }
}

class LedgerQueryService {
  LedgerQueryService(this._database, this._transactions)
    : _merchantsTags = MerchantTagRepository(_database);

  final AppDatabaseV2 _database;
  final FinancialTransactionRepository _transactions;
  final MerchantTagRepository _merchantsTags;

  /// Emits [load] now and again after every change to [tables].
  Stream<T> _watch<T>(
    List<TableInfo<Table, Object?>> tables,
    Future<T> Function() load,
  ) async* {
    yield await load();
    await for (final _ in _database.tableUpdates(
      TableUpdateQuery.onAllTables(tables),
    )) {
      yield await load();
    }
  }

  /// Transactions newest first. [from]/[toExclusive] filter by
  /// `occurredAt`; [accountUuid] keeps only rows touching that
  /// account. Deleted rows are excluded unless [includeDeleted].
  Stream<List<TransactionView>> watchTransactions({
    DateTime? from,
    DateTime? toExclusive,
    String? accountUuid,
    bool includeDeleted = false,
    int? limit,
  }) {
    return _watch(
      [
        _database.financialTransactions,
        _database.postings,
        _database.accounts,
        _database.categories,
        _database.merchants,
        _database.tags,
        _database.transactionTags,
      ],
      () => loadTransactions(
        from: from,
        toExclusive: toExclusive,
        accountUuid: accountUuid,
        includeDeleted: includeDeleted,
        limit: limit,
      ),
    );
  }

  Future<List<TransactionView>> loadTransactions({
    DateTime? from,
    DateTime? toExclusive,
    String? accountUuid,
    bool includeDeleted = false,
    int? limit,
  }) async {
    final query = _database.select(_database.financialTransactions)
      ..orderBy([
        (t) => OrderingTerm(expression: t.occurredAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ]);
    query.where((t) {
      Expression<bool> condition = const Constant(true);
      if (!includeDeleted) {
        condition = condition & t.status.equals('active');
      }
      if (from != null) {
        condition = condition & t.occurredAt.isBiggerOrEqualValue(from);
      }
      if (toExclusive != null) {
        condition = condition & t.occurredAt.isSmallerThanValue(toExclusive);
      }
      return condition;
    });
    final rows = await query.get();
    if (rows.isEmpty) {
      return const <TransactionView>[];
    }

    final ids = rows.map((r) => r.id).toList();
    final postings = await (_database.select(
      _database.postings,
    )..where((p) => p.transactionId.isIn(ids))).get();
    final ledgers = {
      for (final l in await _database.select(_database.ledgerAccounts).get())
        l.ledgerAccountId: l,
    };
    final accounts = {
      for (final a in await _database.select(_database.accounts).get())
        a.uuid: a,
    };
    final categories = {
      for (final c in await _database.select(_database.categories).get())
        c.categoryId: c,
    };
    final merchants = {
      for (final m in await _database.select(_database.merchants).get())
        m.uuid: m,
    };
    final tagsByTx = await _merchantsTags.tagsByTransactionIds(ids);
    final reversed =
        (await (_database.select(_database.financialTransactions)..where(
                  (t) => t.kind.equals('reversal') & t.status.equals('active'),
                ))
                .get())
            .map((r) => r.reversesTransactionId)
            .whereType<String>()
            .toSet();

    final postingsByTx = <int, List<Posting>>{};
    for (final posting in postings) {
      postingsByTx.putIfAbsent(posting.transactionId, () => []).add(posting);
    }

    final views = <TransactionView>[];
    for (final row in rows) {
      Account? account;
      var flow = DisplayFlow.neutral;
      final isTwoAccount =
          row.sourceAccountId != null && row.destinationAccountId != null;
      if (!isTwoAccount) {
        for (final posting in postingsByTx[row.id] ?? const <Posting>[]) {
          final ledger = ledgers[posting.ledgerAccountId];
          final userAccount = ledger?.userAccountId;
          if (ledger == null || userAccount == null) {
            continue;
          }
          account = accounts[userAccount];
          final increases = posting.direction == ledger.normalBalance;
          final isLiability = ledger.normalBalance == 'credit';
          flow = increases != isLiability
              ? DisplayFlow.inflow
              : DisplayFlow.outflow;
          break;
        }
      }
      final view = TransactionView(
        transaction: row,
        flow: flow,
        isReversed: reversed.contains(row.uuid),
        category: row.categoryId == null ? null : categories[row.categoryId],
        account: account,
        sourceAccount: accounts[row.sourceAccountId],
        destinationAccount: accounts[row.destinationAccountId],
        merchant: merchants[row.merchantId],
        tags: tagsByTx[row.id] ?? const [],
      );
      if (accountUuid != null &&
          view.account?.uuid != accountUuid &&
          view.sourceAccount?.uuid != accountUuid &&
          view.destinationAccount?.uuid != accountUuid) {
        continue;
      }
      views.add(view);
      if (limit != null && views.length >= limit) {
        break;
      }
    }
    return views;
  }

  /// Reporting output for one period, recomputed on every ledger
  /// change. Period totals, closing balances (at the period end) and
  /// current balances all come from [computeReporting].
  Stream<ReportingPeriod> watchReporting({
    required DateTime periodStart,
    required DateTime periodEndExclusive,
  }) {
    return _watch(
      [_database.financialTransactions, _database.postings],
      () async => computeReporting(
        await _transactions.loadReportingSnapshot(
          periodStart: periodStart,
          periodEndExclusive: periodEndExclusive,
        ),
      ),
    );
  }

  /// Twelve monthly reports for [year] plus the whole-year report
  /// (last element), recomputed on every ledger change.
  Stream<List<ReportingPeriod>> watchYearByMonth(int year) {
    return _watch(
      [_database.financialTransactions, _database.postings],
      () async {
        final reports = <ReportingPeriod>[];
        for (var month = 1; month <= 12; month++) {
          reports.add(
            computeReporting(
              await _transactions.loadReportingSnapshot(
                periodStart: DateTime(year, month),
                periodEndExclusive: DateTime(year, month + 1),
              ),
            ),
          );
        }
        reports.add(
          computeReporting(
            await _transactions.loadReportingSnapshot(
              periodStart: DateTime(year),
              periodEndExclusive: DateTime(year + 1),
            ),
          ),
        );
        return reports;
      },
    );
  }

  /// Accounts in display order, archived last.
  Stream<List<Account>> watchAccounts({bool includeArchived = true}) {
    return _watch([_database.accounts], () async {
      final query = _database.select(_database.accounts)
        ..orderBy([
          (t) => OrderingTerm(expression: t.isArchived),
          (t) => OrderingTerm(expression: t.displayOrder),
          (t) => OrderingTerm(expression: t.name),
        ]);
      if (!includeArchived) {
        query.where((t) => t.isArchived.equals(false));
      }
      return query.get();
    });
  }

  /// Categories in display order, archived last.
  Stream<List<Category>> watchCategories({bool includeArchived = true}) {
    return _watch([_database.categories], () async {
      final query = _database.select(_database.categories)
        ..orderBy([
          (t) => OrderingTerm(expression: t.isArchived),
          (t) => OrderingTerm(expression: t.displayOrder),
          (t) => OrderingTerm(expression: t.name),
        ]);
      if (!includeArchived) {
        query.where((t) => t.isArchived.equals(false));
      }
      return query.get();
    });
  }
}
