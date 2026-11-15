import 'dart:convert';

import 'package:expense_tracker/core/sync/google_drive_service.dart';
import 'package:expense_tracker/core/sync/google_sheets_backend.dart';
import 'package:expense_tracker/core/sync/v2/drift_v2_sync_store.dart';
import 'package:expense_tracker/core/sync/v2/google_sheets_v2_backend.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_contract.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_engine.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_mapper.dart';
import 'package:expense_tracker/data/repositories/financial_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_stage2_helpers.dart';

const _bank = SheetV2AccountRef(id: 'acc-bank', name: 'Bank');
const _cash = SheetV2AccountRef(id: 'acc-cash', name: 'Cash');
const _card = SheetV2AccountRef(id: 'acc-card', name: 'Card');

SheetV2Source _source({
  String uuid = 'tx-1',
  String kind = 'expense',
  DateTime? occurredAt,
  int amount = 50000,
  bool deleted = false,
  String? categoryId = 'food',
  String? categoryName = 'Food',
  SheetV2AccountRef? account = _bank,
  SheetV2AccountRef? sourceAccount,
  SheetV2AccountRef? destinationAccount,
  SheetV2AccountRef? refundAccount,
  SheetBalanceDirection? balanceDirection,
  String? originalUuid,
  String? relatedUuid,
  SheetV2Source? original,
  DateTime? updatedAt,
}) {
  return SheetV2Source(
    uuid: uuid,
    kind: kind,
    occurredAt: occurredAt ?? DateTime(2026, 3, 10),
    amountMinorUnits: amount,
    currencyCode: 'INR',
    paymentChannel: 'UPI',
    source: 'manual',
    updatedAt: updatedAt ?? DateTime.utc(2026, 3, 10, 12),
    deleted: deleted,
    categoryId: categoryId,
    categoryName: categoryName,
    description: 'desc',
    account: account,
    sourceAccount: sourceAccount,
    destinationAccount: destinationAccount,
    refundAccount: refundAccount,
    balanceDirection: balanceDirection,
    originalUuid: originalUuid,
    relatedUuid: relatedUuid,
    original: original,
  );
}

SheetV2Source _transfer({String uuid = 'tr-1'}) => _source(
  uuid: uuid,
  kind: 'transfer',
  categoryId: null,
  categoryName: null,
  account: null,
  sourceAccount: _bank,
  destinationAccount: _cash,
);

SheetV2Source _opening(SheetBalanceDirection direction) => _source(
  uuid: 'ob-1',
  kind: 'opening_balance',
  categoryId: null,
  categoryName: null,
  balanceDirection: direction,
);

/// In-memory V2 backend recording every write.
class _FakeV2Backend implements SheetsV2SyncBackend {
  final Map<int, List<SheetV2Row>> sheets = <int, List<SheetV2Row>>{};
  final List<String> writes = <String>[];
  bool identityOk = true;
  bool failListing = false;

  @override
  Future<String> resolveSpreadsheetId() async => 'v2-id';

  @override
  Future<void> verifyV2Identity(String spreadsheetId) async {
    if (!identityOk) {
      throw const SheetsV2IdentityException('not v2');
    }
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async {
    if (failListing) {
      throw Exception('listing failed');
    }
    return sheets.keys.toList();
  }

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    sheets.putIfAbsent(year, () {
      writes.add('create $year');
      return <SheetV2Row>[];
    });
  }

  @override
  Future<List<SheetV2Row>> readYearSheet(String spreadsheetId, int year) async {
    final rows = sheets[year] ?? const <SheetV2Row>[];
    return <SheetV2Row>[
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(rowIndex: i + 2),
    ];
  }

  @override
  Future<void> appendRow(String spreadsheetId, int year, SheetV2Row row) async {
    writes.add('append $year ${row.uuid}');
    sheets[year]!.add(row);
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetV2Row row,
  ) async {
    writes.add('update $year ${row.uuid} deleted=${row.deleted}');
    sheets[year]![rowIndex - 2] = row;
  }
}

V2SyncItem _item(SheetV2Source source, {int revision = 0}) => V2SyncItem(
  localId: 1,
  syncRevision: revision,
  status: source.deleted ? 'deleted' : 'active',
  source: source,
);

/// Fake Sheets API client for the real V2 backend.
class _FakeClient implements SheetsApiClient {
  _FakeClient(this.titles);

  final List<String> titles;
  final Map<String, List<List<Object?>>> values =
      <String, List<List<Object?>>>{};
  final List<String> calls = <String>[];
  final List<SheetsValueInputOption> inputOptions = <SheetsValueInputOption>[];
  final List<List<Object?>> appended = <List<Object?>>[];

  @override
  Future<String> resolveSpreadsheetId() async => 'v2-id';

  @override
  Future<List<String>> sheetTitles(String spreadsheetId) async => titles;

  @override
  Future<List<List<Object?>>> readValues(
    String spreadsheetId,
    String range,
  ) async {
    return values[range] ?? const <List<Object?>>[];
  }

  @override
  Future<void> addSheet(String spreadsheetId, String title) async {
    calls.add('addSheet $title');
    titles.add(title);
  }

  @override
  Future<void> updateValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {
    calls.add('update $range');
    inputOptions.add(valueInputOption);
    this.values[range] = values;
  }

  @override
  Future<void> appendValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {
    calls.add('append $range');
    inputOptions.add(valueInputOption);
    appended.addAll(values);
  }
}

void main() {
  group('V2 contract', () {
    test('headers keep V1 A:J order and freeze K:Y', () {
      expect(sheetV2Headers, hasLength(25));
      expect(sheetV2Headers.sublist(0, 10), <String>[
        'Date',
        'Type',
        'Category',
        'Description',
        'Amount',
        'UUID',
        'PaymentMethod',
        'Notes',
        'UpdatedAt',
        'Deleted',
      ]);
      expect(sheetV2Headers[10], 'Kind');
      expect(sheetV2Headers[24], 'BalanceDirection');
      expect(sheetV2Headers, isNot(contains('TransferGroupId')));
    });

    test('all eight kinds map exactly; unknown labels are rejected', () {
      expect(sheetKindLabels.values, <String>[
        'Expense',
        'Income',
        'Transfer',
        'CardPayment',
        'Refund',
        'Adjustment',
        'OpeningBalance',
        'Reversal',
      ]);
      for (final kind in sheetKindLabels.keys) {
        expect(kindFromSheetLabel(sheetKindLabelFor(kind)), kind);
      }
      expect(() => kindFromSheetLabel('expense'), throwsFormatException);
      expect(() => kindFromSheetLabel('Gift'), throwsFormatException);
      expect(() => sheetKindLabelFor('gift'), throwsArgumentError);
    });

    test('amounts round-trip as numeric cells up to the limit', () {
      const values = <int>[
        0,
        1,
        99,
        100,
        125075,
        7036874417766398,
        7036874417766399,
      ];
      for (final paise in values) {
        final cell = sheetAmountFromMinorUnits(paise);
        expect(cell, isA<num>(), reason: '$paise must be a NUMBER cell');
        final readBack = jsonDecode(jsonEncode(<Object>[cell])) as List;
        expect(minorUnitsFromSheetAmount(readBack.single), paise);
      }
      expect(sheetAmountFromMinorUnits(125075), 1250.75);
    });

    test('amounts above the limit or negative are rejected', () {
      expect(
        () => sheetAmountFromMinorUnits(7036874417766400),
        throwsA(isA<SheetAmountOutOfRangeException>()),
      );
      expect(
        () => sheetAmountFromMinorUnits(-1),
        throwsA(isA<SheetAmountOutOfRangeException>()),
      );
      expect(
        () => minorUnitsFromSheetAmount('70368744177664.00'),
        throwsA(isA<SheetAmountOutOfRangeException>()),
      );
    });

    test('reading normalises excess decimals and rejects text', () {
      expect(minorUnitsFromSheetAmount('1250.755'), 125076);
      expect(minorUnitsFromSheetAmount(12), 1200);
      expect(() => minorUnitsFromSheetAmount('abc'), throwsFormatException);
      expect(() => minorUnitsFromSheetAmount(null), throwsFormatException);
    });
  });

  group('V2 mapper', () {
    test('expense maps category and account columns', () {
      final row = mapToSheetV2Row(_source());
      expect(row.type, 'Expense');
      expect(row.kind, 'Expense');
      expect(row.category, 'Food');
      expect(row.categoryId, 'food');
      expect(row.accountId, 'acc-bank');
      expect(row.account, 'Bank');
      expect(row.fromAccountId, isEmpty);
      expect(row.balanceDirection, isEmpty);
      expect(row.amount, 500);
      expect(row.dateText, '2026-03-10');
      expect(row.toValues(), hasLength(25));
    });

    test('transfer is one row with from/to and no category', () {
      final row = mapToSheetV2Row(_transfer());
      expect(row.type, 'Transfer');
      expect(row.category, isEmpty);
      expect(row.categoryId, isEmpty);
      expect(row.accountId, 'acc-cash');
      expect(row.fromAccountId, 'acc-bank');
      expect(row.fromAccount, 'Bank');
      expect(row.toAccountId, 'acc-cash');
      expect(row.toAccount, 'Cash');
    });

    test('card payment uses the card as destination', () {
      final row = mapToSheetV2Row(
        _source(
          kind: 'card_payment',
          categoryId: null,
          categoryName: null,
          account: null,
          sourceAccount: _bank,
          destinationAccount: _card,
        ),
      );
      expect(row.type, 'CardPayment');
      expect(row.accountId, 'acc-card');
      expect(row.fromAccountId, 'acc-bank');
      expect(row.toAccountId, 'acc-card');
    });

    test('refund uses refundAccountId and links the original', () {
      final row = mapToSheetV2Row(
        _source(
          kind: 'refund',
          account: null,
          refundAccount: _cash,
          originalUuid: 'tx-orig',
        ),
      );
      expect(row.accountId, 'acc-cash');
      expect(row.originalUuid, 'tx-orig');
      expect(row.categoryId, 'food');
    });

    test('adjustment carries RelatedUuid, never OriginalUuid', () {
      final row = mapToSheetV2Row(
        _source(
          kind: 'adjustment',
          categoryId: null,
          categoryName: null,
          relatedUuid: 'ob-1',
          originalUuid: 'ignored',
        ),
      );
      expect(row.relatedUuid, 'ob-1');
      expect(row.originalUuid, isEmpty);
    });

    test('opening balance carries BalanceDirection', () {
      expect(
        mapToSheetV2Row(_opening(SheetBalanceDirection.positive))
            .balanceDirection,
        'positive',
      );
      expect(
        mapToSheetV2Row(_opening(SheetBalanceDirection.negative))
            .balanceDirection,
        'negative',
      );
    });

    test('transfer reversal swaps accounts', () {
      final row = mapToSheetV2Row(
        _source(
          uuid: 'rev-1',
          kind: 'reversal',
          categoryId: null,
          categoryName: null,
          account: null,
          originalUuid: 'tr-1',
          original: _transfer(),
        ),
      );
      expect(row.type, 'Reversal');
      expect(row.originalUuid, 'tr-1');
      expect(row.accountId, 'acc-bank');
      expect(row.fromAccountId, 'acc-cash');
      expect(row.fromAccount, 'Cash');
      expect(row.toAccountId, 'acc-bank');
      expect(row.toAccount, 'Bank');
      expect(row.relatedUuid, isEmpty);
    });

    test('opening-balance reversal inverts BalanceDirection', () {
      final row = mapToSheetV2Row(
        _source(
          uuid: 'rev-2',
          kind: 'reversal',
          originalUuid: 'ob-1',
          original: _opening(SheetBalanceDirection.positive),
        ),
      );
      expect(row.balanceDirection, 'negative');
      expect(row.accountId, 'acc-bank');
      expect(row.categoryId, isEmpty);
    });

    test('expense reversal copies category and account', () {
      final row = mapToSheetV2Row(
        _source(
          uuid: 'rev-3',
          kind: 'reversal',
          account: null,
          originalUuid: 'tx-1',
          original: _source(),
        ),
      );
      expect(row.categoryId, 'food');
      expect(row.accountId, 'acc-bank');
      expect(row.balanceDirection, isEmpty);
    });

    test('incomplete data is a mapping error', () {
      expect(
        () => mapToSheetV2Row(_source(kind: 'reversal')),
        throwsA(isA<SheetV2MappingException>()),
      );
      expect(
        () => mapToSheetV2Row(_source(kind: 'transfer', account: null)),
        throwsA(isA<SheetV2MappingException>()),
      );
    });
  });

  group('V2 engine', () {
    Future<V2SyncRunResult> run(
      _FakeV2Backend backend,
      List<V2SyncItem> pending, {
      bool ack = true,
    }) {
      return SheetsV2SyncEngine().syncAll(
        pending: pending,
        backend: backend,
        onSynced: (_) async => ack,
      );
    }

    test('appends once and updates in place on retry', () async {
      final backend = _FakeV2Backend();
      await run(backend, [_item(_source())]);
      await run(backend, [_item(_source(amount: 60000), revision: 1)]);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.amount, 600);
    });

    test('deleted before first sync writes nothing', () async {
      final backend = _FakeV2Backend();
      final result = await run(backend, [_item(_source(deleted: true))]);
      expect(result.syncedUuids, ['tx-1']);
      expect(backend.writes, isEmpty);
      expect(backend.sheets, isEmpty);
    });

    test('deleting a synced row tombstones it', () async {
      final backend = _FakeV2Backend();
      await run(backend, [_item(_source())]);
      await run(backend, [_item(_source(deleted: true), revision: 1)]);
      expect(backend.sheets[2026]!.single.deleted, isTrue);
    });

    test('year move tombstones the old row first', () async {
      final backend = _FakeV2Backend();
      await run(backend, [_item(_source())]);
      await run(backend, [
        _item(_source(occurredAt: DateTime(2025, 12, 31)), revision: 1),
      ]);
      expect(backend.sheets[2026]!.single.deleted, isTrue);
      expect(backend.sheets[2025]!.single.deleted, isFalse);
      expect(
        backend.writes.indexOf('update 2026 tx-1 deleted=true'),
        lessThan(backend.writes.indexOf('append 2025 tx-1')),
      );
    });

    test('over-limit amount stays pending and others still sync', () async {
      final backend = _FakeV2Backend();
      final result = await run(backend, [
        _item(_source(uuid: 'big', amount: maxSheetAmountPaise + 1)),
        _item(_source(uuid: 'ok')),
      ]);
      expect(result.unsyncableUuids, ['big']);
      expect(result.failedUuids, ['big']);
      expect(result.syncedUuids, ['ok']);
      expect(backend.writes, isNot(contains('append 2026 big')));
    });

    test('duplicate rows are reported and never written', () async {
      final backend = _FakeV2Backend();
      final row = mapToSheetV2Row(_source());
      backend.sheets[2026] = [row, row];
      final result = await run(backend, [_item(_source())]);
      expect(result.duplicateUuids, ['tx-1']);
      expect(backend.writes, isEmpty);
    });

    test('a failed conditional acknowledgement stays pending', () async {
      final backend = _FakeV2Backend();
      final result = await run(backend, [_item(_source())], ack: false);
      expect(result.failedUuids, ['tx-1']);
      expect(result.syncedUuids, isEmpty);
    });

    test('identity failure aborts before any write', () async {
      final backend = _FakeV2Backend()..identityOk = false;
      await expectLater(
        run(backend, [_item(_source())]),
        throwsA(isA<SheetsV2IdentityException>()),
      );
      expect(backend.writes, isEmpty);
    });

    test('listing failure aborts before any write', () async {
      final backend = _FakeV2Backend()..failListing = true;
      await expectLater(run(backend, [_item(_source())]), throwsException);
      expect(backend.writes, isEmpty);
    });
  });

  group('V2 backend identity', () {
    test('Drive query and metadata use the V2 marker and title', () {
      final query = sheetsV2SpreadsheetQuery('folder-1');
      expect(query, contains("'folder-1' in parents"));
      expect(query, contains("key='expenseTrackerSchemaVersion'"));
      expect(query, contains("value='2'"));
      final metadata = sheetsV2SpreadsheetMetadata('folder-1');
      expect(metadata.name, 'Expense Tracker v2');
      expect(metadata.appProperties, {'expenseTrackerSchemaVersion': '2'});
    });

    test('creates _meta on a fresh spreadsheet', () async {
      final client = _FakeClient(['Sheet1']);
      final backend = GoogleSheetsV2Backend.forTesting(client: client);
      await backend.verifyV2Identity('v2-id');
      expect(client.calls, contains('addSheet _meta'));
      expect(client.values["'_meta'!A1:B2"]!.first, [
        'sheetSchemaVersion',
        '2',
      ]);
    });

    test('accepts an existing version-2 _meta without writing', () async {
      final client = _FakeClient(['_meta', '2026']);
      client.values["'_meta'!A1:B10"] = [
        ['sheetSchemaVersion', '2'],
      ];
      await GoogleSheetsV2Backend.forTesting(client: client)
          .verifyV2Identity('v2-id');
      expect(client.calls, isEmpty);
    });

    test('refuses a spreadsheet with data but no _meta', () async {
      final client = _FakeClient(['2025']);
      await expectLater(
        GoogleSheetsV2Backend.forTesting(client: client)
            .verifyV2Identity('v2-id'),
        throwsA(isA<SheetsV2IdentityException>()),
      );
      expect(client.calls, isEmpty);
    });

    test('refuses another schema version', () async {
      final client = _FakeClient(['_meta']);
      client.values["'_meta'!A1:B10"] = [
        ['sheetSchemaVersion', '3'],
      ];
      await expectLater(
        GoogleSheetsV2Backend.forTesting(client: client)
            .verifyV2Identity('v2-id'),
        throwsA(isA<SheetsV2IdentityException>()),
      );
    });

    test('new year sheet gets the A:Y header; rows are RAW numbers', () async {
      final client = _FakeClient(['_meta']);
      final backend = GoogleSheetsV2Backend.forTesting(client: client);
      await backend.ensureYearSheet('v2-id', 2026);
      expect(client.values["'2026'!A1:Y1"]!.single, sheetV2Headers);
      await backend.appendRow('v2-id', 2026, mapToSheetV2Row(_source()));
      expect(client.calls.last, "append '2026'!A:Y");
      expect(client.appended.single[4], isA<num>());
      expect(client.inputOptions, everyElement(SheetsValueInputOption.raw));
    });

    test('a data row in row 1 is never overwritten', () async {
      final client = _FakeClient(['2026']);
      client.values["'2026'!A1:Y1"] = [
        ['2026-01-01', 'Expense'],
      ];
      await GoogleSheetsV2Backend.forTesting(client: client)
          .ensureYearSheet('v2-id', 2026);
      expect(client.calls, isEmpty);
    });
  });

  group('Drift V2 sync store', () {
    late Stage2Fixture f;

    setUp(() async {
      f = await Stage2Fixture.create();
    });

    tearDown(() => f.close());

    DriftV2SyncStore store() => DriftV2SyncStore(f.db, f.transactions);

    test('resolves accounts, categories and directions per kind', () async {
      final bank = await f.bankWithOpening(inr(100000));
      final cash = await f.cash();
      final expense = await f.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(5000),
        occurredAt: dt(2026, 2, 1),
        paymentChannel: 'UPI',
      );
      final transfer = await f.transactions.createTransfer(
        sourceAccountUuid: bank.uuid,
        destinationAccountUuid: cash.uuid,
        amount: inr(2000),
        occurredAt: dt(2026, 2, 2),
        paymentChannel: 'Cash',
      );
      final refund = await f.transactions.createRefund(
        originalUuid: expense.uuid,
        refundAccountUuid: cash.uuid,
        amount: inr(1000),
        occurredAt: dt(2026, 2, 3),
        paymentChannel: 'Cash',
      );
      final reversal = await f.transactions.createReversal(
        originalUuid: transfer.uuid,
        occurredAt: dt(2026, 2, 4),
      );

      final items = await store().getPending();
      final rows = {
        for (final item in items) item.uuid: mapToSheetV2Row(item.source),
      };

      final opening = items.firstWhere(
        (i) => i.source.kind == 'opening_balance',
      );
      expect(rows[opening.uuid]!.balanceDirection, 'positive');
      expect(rows[opening.uuid]!.accountId, bank.uuid);

      expect(rows[expense.uuid]!.accountId, bank.uuid);
      expect(rows[expense.uuid]!.account, 'Bank');
      expect(rows[expense.uuid]!.category, 'Food');
      expect(rows[expense.uuid]!.amount, 50);

      expect(rows[transfer.uuid]!.fromAccountId, bank.uuid);
      expect(rows[transfer.uuid]!.toAccountId, cash.uuid);

      expect(rows[refund.uuid]!.accountId, cash.uuid);
      expect(rows[refund.uuid]!.originalUuid, expense.uuid);

      expect(rows[reversal.uuid]!.fromAccountId, cash.uuid);
      expect(rows[reversal.uuid]!.toAccountId, bank.uuid);
      expect(rows[reversal.uuid]!.originalUuid, transfer.uuid);
    });

    test('negative opening balance maps to negative direction', () async {
      await f.accounts.createAccount(
        name: 'Overdrawn',
        kind: 'bank',
        currencyCode: 'INR',
        openingBalance: inr(-5000),
        openingOccurredAt: dt(2026, 1, 1),
      );
      final item = (await store().getPending()).single;
      expect(mapToSheetV2Row(item.source).balanceDirection, 'negative');
      expect(item.source.amountMinorUnits, 5000);
    });

    test('acknowledgement is conditional on the uploaded revision', () async {
      final bank = await f.bank();
      final expense = await f.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(5000),
        occurredAt: dt(2026, 2, 1),
        paymentChannel: 'UPI',
      );
      final stale = (await store().getPending()).single;
      await f.transactions.editTransaction(
        expense.uuid,
        const TransactionEdit(description: 'changed'),
      );
      expect(await store().markSynced(stale), isFalse);
      final fresh = (await store().getPending()).single;
      expect(await store().markSynced(fresh), isTrue);
      expect(await store().getPending(), isEmpty);
    });

    test('end to end: engine + store sync everything once', () async {
      final bank = await f.bankWithOpening(inr(100000));
      await f.transactions.createExpense(
        accountUuid: bank.uuid,
        categoryId: 'food',
        amount: inr(5000),
        occurredAt: dt(2026, 2, 1),
        paymentChannel: 'UPI',
      );
      final backend = _FakeV2Backend();
      final s = store();
      final result = await SheetsV2SyncEngine().syncAll(
        pending: await s.getPending(),
        backend: backend,
        onSynced: s.markSynced,
      );
      expect(result.failedUuids, isEmpty);
      expect(result.syncedUuids, hasLength(2));
      expect(backend.sheets[2026], hasLength(2));
      expect(await s.getPending(), isEmpty);
    });
  });
}
