import 'dart:async';

import 'package:expense_tracker/core/sync/google_sheets_backend.dart';
import 'package:expense_tracker/core/sync/sheets_sync.dart';
import 'package:expense_tracker/core/sync/sync_coordinator.dart';
import 'package:expense_tracker/data/notifications/notification.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes for the SheetsSyncBackend boundary (engine + coordinator tests)
// ---------------------------------------------------------------------------

class FakeSheetsBackend implements SheetsSyncBackend {
  final Map<int, List<SheetRowData>> sheets = <int, List<SheetRowData>>{};
  int resolveCalls = 0;
  bool failResolve = false;
  bool failNextWrite = false;
  bool failNextAppend = false;
  bool failNextUpdate = false;
  int appendCalls = 0;
  int updateCalls = 0;

  /// When set, appendRow signals [writeStarted] and waits for
  /// [writeGate] before writing. Used for deterministic
  /// pause/edit and trigger-during-run tests.
  Completer<void>? writeGate;
  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<String> resolveSpreadsheetId() async {
    resolveCalls++;
    if (failResolve) {
      throw Exception('Drive unavailable');
    }
    return 'spreadsheet-1';
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async {
    return sheets.keys.toList();
  }

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    sheets.putIfAbsent(year, () => <SheetRowData>[]);
  }

  @override
  Future<List<SheetRowData>> readYearSheet(
    String spreadsheetId,
    int year,
  ) async {
    return List<SheetRowData>.unmodifiable(
      sheets[year] ?? const <SheetRowData>[],
    );
  }

  void _maybeFailNext() {
    if (failNextWrite) {
      failNextWrite = false;
      throw Exception('Sheets write failed');
    }
  }

  @override
  Future<void> appendRow(
    String spreadsheetId,
    int year,
    SheetRowData row,
  ) async {
    final gate = writeGate;
    if (gate != null) {
      if (!writeStarted.isCompleted) {
        writeStarted.complete();
      }
      await gate.future;
    }
    if (failNextAppend) {
      failNextAppend = false;
      throw Exception('Sheets append failed');
    }
    _maybeFailNext();
    appendCalls++;
    final rows = sheets.putIfAbsent(year, () => <SheetRowData>[]);
    rows.add(row.copyWith(rowIndex: rows.length + 2));
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw Exception('Sheets update failed');
    }
    _maybeFailNext();
    updateCalls++;
    final rows = sheets.putIfAbsent(year, () => <SheetRowData>[]);
    final index = rows.indexWhere((r) => r.rowIndex == rowIndex);
    if (index == -1) {
      throw StateError('Row $rowIndex not found in $year');
    }
    rows[index] = row.copyWith(rowIndex: rowIndex);
  }

  List<SheetRowData> activeRows(int year) {
    return (sheets[year] ?? const <SheetRowData>[])
        .where((row) => !row.deleted)
        .toList();
  }

  void seedRow(int year, SheetRowData row) {
    final rows = sheets.putIfAbsent(year, () => <SheetRowData>[]);
    rows.add(row.copyWith(rowIndex: rows.length + 2));
  }
}

/// Fake store with conditional acknowledgement: a row is marked
/// synced only when the stored revision (updatedAt + deleted) and
/// pending state still match the uploaded snapshot. Editing a
/// transaction advances its revision and keeps it pending.
class FakeStore implements SyncTransactionStore {
  FakeStore(List<SyncTransaction> initial) {
    for (final tx in initial) {
      _entries[tx.localId] = _Entry(tx, pending: true);
    }
  }

  final Map<int, _Entry> _entries = <int, _Entry>{};
  bool failNextAck = false;
  final List<int> markedSynced = <int>[];

  List<SyncTransaction> get pending =>
      _entries.values.where((e) => e.pending).map((e) => e.tx).toList();

  void add(SyncTransaction tx) {
    _entries[tx.localId] = _Entry(tx, pending: true);
  }

  SyncTransaction? entry(int localId) => _entries[localId]?.tx;

  void edit({
    required int localId,
    double? amount,
    DateTime? transactionDate,
    bool? deleted,
    String? description,
  }) {
    final entry = _entries[localId];
    if (entry == null) {
      throw StateError('No entry $localId');
    }
    final old = entry.tx;
    final nextUpdatedAt =
        old.updatedAt.add(const Duration(seconds: 1));
    _entries[localId] = _Entry(
      SyncTransaction(
        localId: old.localId,
        uuid: old.uuid,
        transactionDate: transactionDate ?? old.transactionDate,
        type: old.type,
        category: old.category,
        description: description ?? old.description,
        amount: amount ?? old.amount,
        paymentMethod: old.paymentMethod,
        notes: old.notes,
        updatedAt: nextUpdatedAt,
        deleted: deleted ?? old.deleted,
      ),
      pending: true,
    );
  }

  @override
  Future<List<SyncTransaction>> getPending() async {
    return pending;
  }

  @override
  Future<bool> markSynced(SyncTransaction transaction) async {
    if (failNextAck) {
      failNextAck = false;
      return false;
    }
    final entry = _entries[transaction.localId];
    if (entry == null || !entry.pending) {
      return false;
    }
    if (entry.tx.updatedAt != transaction.updatedAt ||
        entry.tx.deleted != transaction.deleted) {
      return false;
    }
    _entries[transaction.localId] = _Entry(entry.tx, pending: false);
    markedSynced.add(transaction.localId);
    return true;
  }
}

class _Entry {
  const _Entry(this.tx, {required this.pending});

  final SyncTransaction tx;
  final bool pending;
}

SyncTransaction makeTx({
  int localId = 1,
  String uuid = 'uuid-1',
  DateTime? date,
  String type = 'Expense',
  String category = 'Food',
  String description = 'Lunch',
  double amount = 250,
  String paymentMethod = 'UPI',
  String? notes,
  DateTime? updatedAt,
  bool deleted = false,
}) {
  final when = date ?? DateTime(2026, 3, 10);
  return SyncTransaction(
    localId: localId,
    uuid: uuid,
    transactionDate: when,
    type: type,
    category: category,
    description: description,
    amount: amount,
    paymentMethod: paymentMethod,
    notes: notes,
    updatedAt: updatedAt ?? DateTime(2026, 3, 10, 12),
    deleted: deleted,
  );
}

Future<void> runEngine(
  SheetsSyncEngine engine,
  FakeSheetsBackend backend,
  FakeStore store,
) async {
  await engine.syncAll(
    pending: await store.getPending(),
    backend: backend,
    onSynced: (tx) => store.markSynced(tx),
  );
}

// ---------------------------------------------------------------------------
// Fake SheetsApiClient (error-classification + authorization-mode tests)
// ---------------------------------------------------------------------------

class FakeSheetsApiClient implements SheetsApiClient {
  final Map<int, List<List<Object?>>> sheets = <int, List<List<Object?>>>{};
  SheetsApiException? titlesError;
  SheetsApiException? readError;
  SheetsApiException? writeError;
  int titlesCalls = 0;

  @override
  Future<String> resolveSpreadsheetId() async => 'spreadsheet-1';

  @override
  Future<List<String>> sheetTitles(String spreadsheetId) async {
    titlesCalls++;
    final error = titlesError;
    if (error != null) {
      throw error;
    }
    return sheets.keys.map((y) => '$y').toList();
  }

  @override
  Future<List<List<Object?>>> readValues(
    String spreadsheetId,
    String range,
  ) async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    final year = int.parse(range.replaceAll("'", '').split('!').first);
    return sheets[year] ?? const <List<Object?>>[];
  }

  @override
  Future<void> updateValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required bool userEntered,
  }) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    final year = int.parse(range.replaceAll("'", '').split('!').first);
    sheets[year] = values;
  }

  @override
  Future<void> appendValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values,
  ) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    final year = int.parse(range.replaceAll("'", '').split('!').first);
    final rows = sheets.putIfAbsent(year, () => <List<Object?>>[]);
    rows.addAll(values);
  }

  @override
  Future<void> addSheet(String spreadsheetId, String title) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    sheets.putIfAbsent(int.parse(title), () => <List<Object?>>[]);
  }
}

class _StubApiError {
  const _StubApiError(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'StubApiError $status: $message';
}

class _NotSignedInBackend implements SheetsSyncBackend {
  @override
  Future<String> resolveSpreadsheetId() async {
    throw const SheetsNotSignedInException();
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async => <int>[];

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {}

  @override
  Future<List<SheetRowData>> readYearSheet(
    String spreadsheetId,
    int year,
  ) async =>
      <SheetRowData>[];

  @override
  Future<void> appendRow(
    String spreadsheetId,
    int year,
    SheetRowData row,
  ) async {}

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) async {}
}

class _AuthorizationMissingBackend implements SheetsSyncBackend {
  @override
  Future<String> resolveSpreadsheetId() async {
    throw const SheetsAuthorizationMissingException();
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async => <int>[];

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {}

  @override
  Future<List<SheetRowData>> readYearSheet(
    String spreadsheetId,
    int year,
  ) async =>
      <SheetRowData>[];

  @override
  Future<void> appendRow(
    String spreadsheetId,
    int year,
    SheetRowData row,
  ) async {}

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) async {}
}

void main() {
  group('SheetRowData', () {
    test('header schema keeps UUID in column F with all fields', () {
      expect(sheetHeaders, <String>[
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

      final row = SheetRowData.fromTransaction(
        makeTx(notes: 'with team', updatedAt: DateTime(2026, 3, 10, 12)),
      );
      final values = row.toValues();
      expect(values[0], '2026-03-10');
      expect(values[1], 'Expense');
      expect(values[2], 'Food');
      expect(values[3], 'Lunch');
      expect(values[4], 250);
      expect(values[5], 'uuid-1');
      expect(values[6], 'UPI');
      expect(values[7], 'with team');
      expect(values[9], 'FALSE');

      final roundTripped = SheetRowData.fromValues(values, 2);
      expect(roundTripped.uuid, 'uuid-1');
      expect(roundTripped.amount, 250);
      expect(roundTripped.deleted, isFalse);
    });

    test('fromValues tolerates a legacy 5-column row', () {
      final row = SheetRowData.fromValues(
        <Object?>['2025-12-01', 'Expense', 'Food', 'Old', 99],
        2,
      );
      expect(row.uuid, '');
      expect(row.amount, 99);
      expect(row.deleted, isFalse);
    });
  });

  group('SheetsSyncEngine basics', () {
    test('create appends one row to the transaction-date year sheet', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(date: DateTime(2025, 11, 2))]);

      await runEngine(SheetsSyncEngine(), backend, store);

      expect(store.pending, isEmpty);
      expect(backend.sheets[2025], hasLength(1));
      expect(backend.sheets[2026], isNull);
      expect(backend.activeRows(2025).single.uuid, 'uuid-1');
    });

    test('retrying the same transaction updates instead of duplicating', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(amount: 250)]);

      await runEngine(SheetsSyncEngine(), backend, store);
      store.edit(localId: 1, amount: 300);
      await runEngine(SheetsSyncEngine(), backend, store);

      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.amount, 300);
    });

    test('soft delete marks the row deleted and restore flips it back', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx()]);

      await runEngine(SheetsSyncEngine(), backend, store);
      store.edit(localId: 1, deleted: true);
      await runEngine(SheetsSyncEngine(), backend, store);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isTrue);
      expect(backend.activeRows(2026), isEmpty);

      store.edit(localId: 1, deleted: false);
      await runEngine(SheetsSyncEngine(), backend, store);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isFalse);
    });

    test('deleting before first sync creates no row but still syncs locally', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(deleted: true)]);

      await runEngine(SheetsSyncEngine(), backend, store);

      expect(store.pending, isEmpty);
      expect(backend.sheets, isEmpty);
    });

    test('moving across years deletes the old row and writes the new year', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(date: DateTime(2025, 12, 31))]);

      await runEngine(SheetsSyncEngine(), backend, store);
      store.edit(localId: 1, transactionDate: DateTime(2026, 1, 2));
      await runEngine(SheetsSyncEngine(), backend, store);

      expect(backend.sheets[2025], hasLength(1));
      expect(backend.sheets[2025]!.single.deleted, isTrue);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isFalse);
      expect(backend.activeRows(2025), isEmpty);
      expect(backend.activeRows(2026), hasLength(1));
    });

    test('failed write retains pending status and retry succeeds', () async {
      final backend = FakeSheetsBackend()..failNextWrite = true;
      final store = FakeStore([makeTx()]);

      await runEngine(SheetsSyncEngine(), backend, store);
      expect(store.pending, hasLength(1));
      expect(backend.sheets[2026], isEmpty);

      await runEngine(SheetsSyncEngine(), backend, store);
      expect(store.pending, isEmpty);
      expect(backend.sheets[2026], hasLength(1));
    });

    test('failed spreadsheet resolution syncs nothing', () async {
      final backend = FakeSheetsBackend()..failResolve = true;
      final store = FakeStore([makeTx()]);

      await expectLater(
        SheetsSyncEngine().syncAll(
          pending: await store.getPending(),
          backend: backend,
          onSynced: (tx) => store.markSynced(tx),
        ),
        throwsException,
      );
      expect(backend.sheets, isEmpty);
      expect(store.pending, hasLength(1));
    });
  });

  group('Conditional acknowledgement after concurrent edits', () {
    test('edit during a paused remote write keeps the newer revision pending, retry uploads it', () async {
      final backend = FakeSheetsBackend();
      backend.writeGate = Completer<void>();
      final store = FakeStore([makeTx(amount: 250)]);
      final engine = SheetsSyncEngine();

      final run = engine.syncAll(
        pending: await store.getPending(),
        backend: backend,
        onSynced: (tx) => store.markSynced(tx),
      );

      // Wait until the remote write has started, then edit locally.
      await backend.writeStarted.future;
      store.edit(localId: 1, amount: 999);
      backend.writeGate!.complete();
      final result = await run;

      // The old snapshot was written, but its acknowledgement
      // must fail because the local revision moved on.
      expect(result.failedUuids, ['uuid-1']);
      expect(store.pending, hasLength(1));
      expect(store.entry(1)!.amount, 999);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.amount, 250);

      // Retry uploads the latest revision in place, no duplicate.
      backend.writeGate = null;
      await runEngine(engine, backend, store);
      expect(store.pending, isEmpty);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.amount, 999);
    });

    test('delete during a paused remote write is not marked synced', () async {
      final backend = FakeSheetsBackend();
      backend.writeGate = Completer<void>();
      final store = FakeStore([makeTx()]);
      final engine = SheetsSyncEngine();

      final run = engine.syncAll(
        pending: await store.getPending(),
        backend: backend,
        onSynced: (tx) => store.markSynced(tx),
      );

      await backend.writeStarted.future;
      store.edit(localId: 1, deleted: true);
      backend.writeGate!.complete();
      final result = await run;

      expect(result.failedUuids, ['uuid-1']);
      expect(store.pending, hasLength(1));
      expect(store.entry(1)!.deleted, isTrue);

      backend.writeGate = null;
      await runEngine(engine, backend, store);
      expect(store.pending, isEmpty);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isTrue);
    });
  });

  group('Partial year-move failures', () {
    test('tombstone failure: retry converges to one active row', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(date: DateTime(2025, 12, 31))]);
      final engine = SheetsSyncEngine();

      await runEngine(engine, backend, store);
      store.edit(localId: 1, transactionDate: DateTime(2026, 1, 2));

      backend.failNextUpdate = true;
      await runEngine(engine, backend, store);
      expect(store.pending, hasLength(1));
      expect(backend.activeRows(2025), hasLength(1));
      expect(backend.sheets[2026], isNull);

      await runEngine(engine, backend, store);
      expect(store.pending, isEmpty);
      expect(backend.activeRows(2025), isEmpty);
      expect(backend.activeRows(2026), hasLength(1));
    });

    test('tombstone succeeds but append fails: retry does not duplicate', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(date: DateTime(2025, 12, 31))]);
      final engine = SheetsSyncEngine();

      await runEngine(engine, backend, store);
      store.edit(localId: 1, transactionDate: DateTime(2026, 1, 2));

      backend.failNextAppend = true;
      await runEngine(engine, backend, store);
      expect(store.pending, hasLength(1));
      expect(backend.sheets[2025]!.single.deleted, isTrue);
      expect(backend.sheets[2026], isEmpty);

      await runEngine(engine, backend, store);
      expect(store.pending, isEmpty);
      expect(backend.activeRows(2025), isEmpty);
      expect(backend.activeRows(2026), hasLength(1));
      expect(backend.sheets[2026], hasLength(1));
    });

    test('append succeeds but acknowledgement fails: retry updates in place', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx()]);
      final engine = SheetsSyncEngine();

      store.failNextAck = true;
      await runEngine(engine, backend, store);
      expect(store.pending, hasLength(1));
      expect(backend.sheets[2026], hasLength(1));

      await runEngine(engine, backend, store);
      expect(store.pending, isEmpty);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.appendCalls, 1);
    });

    test('repeated retries after year-move failures never create duplicate active rows', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx(date: DateTime(2025, 12, 31))]);
      final engine = SheetsSyncEngine();

      await runEngine(engine, backend, store);
      store.edit(localId: 1, transactionDate: DateTime(2026, 1, 2));

      backend.failNextAppend = true;
      await runEngine(engine, backend, store);
      backend.failNextAppend = true;
      await runEngine(engine, backend, store);
      await runEngine(engine, backend, store);

      expect(store.pending, isEmpty);
      expect(backend.activeRows(2025), isEmpty);
      expect(backend.activeRows(2026), hasLength(1));
    });
  });

  group('Duplicate UUID detection', () {
    test('duplicate rows in one worksheet are reported and nothing is written', () async {
      final backend = FakeSheetsBackend();
      final tx = makeTx();
      backend.seedRow(2026, SheetRowData.fromTransaction(tx, rowIndex: 2));
      backend.seedRow(2026, SheetRowData.fromTransaction(tx, rowIndex: 3));
      final store = FakeStore([tx]);
      final appendsBefore = backend.appendCalls;
      final updatesBefore = backend.updateCalls;

      final result = await SheetsSyncEngine().syncAll(
        pending: await store.getPending(),
        backend: backend,
        onSynced: (t) => store.markSynced(t),
      );

      expect(result.duplicateUuids, ['uuid-1']);
      expect(result.failedUuids, ['uuid-1']);
      expect(backend.appendCalls, appendsBefore);
      expect(backend.updateCalls, updatesBefore);
      expect(backend.sheets[2026], hasLength(2));
      expect(store.pending, hasLength(1));
    });

    test('two active rows across years are ambiguous and skipped', () async {
      final backend = FakeSheetsBackend();
      final tx = makeTx(date: DateTime(2026, 3, 10));
      backend.seedRow(
        2025,
        SheetRowData.fromTransaction(
          makeTx(date: DateTime(2025, 3, 10)),
          rowIndex: 2,
        ),
      );
      backend.seedRow(2026, SheetRowData.fromTransaction(tx, rowIndex: 2));
      final store = FakeStore([tx]);

      final result = await SheetsSyncEngine().syncAll(
        pending: await store.getPending(),
        backend: backend,
        onSynced: (t) => store.markSynced(t),
      );

      expect(result.duplicateUuids, ['uuid-1']);
      expect(store.pending, hasLength(1));
      expect(backend.activeRows(2025), hasLength(1));
      expect(backend.activeRows(2026), hasLength(1));
    });

    test('one active row plus one tombstoned row is not a duplicate', () async {
      final backend = FakeSheetsBackend();
      final tx = makeTx(date: DateTime(2026, 3, 10));
      backend.seedRow(
        2025,
        SheetRowData.fromTransaction(tx).copyWith(
          deleted: true,
          rowIndex: 2,
        ),
      );
      backend.seedRow(2026, SheetRowData.fromTransaction(tx, rowIndex: 2));
      final store = FakeStore([tx]);

      final result = await SheetsSyncEngine().syncAll(
        pending: await store.getPending(),
        backend: backend,
        onSynced: (t) => store.markSynced(t),
      );

      expect(result.duplicateUuids, isEmpty);
      expect(result.failedUuids, isEmpty);
      expect(store.pending, isEmpty);
    });
  });

  group('Sheets error classification', () {
    test('missing worksheet after spreadsheet verification reads as empty', () async {
      final client = FakeSheetsApiClient();
      client.sheets[2026] = <List<Object?>>[];
      client.readError = const SheetsApiException(
        SheetsErrorKind.missingWorksheet,
        'Unable to parse range',
        404,
      );
      final backend = GoogleSheetsBackend.forTesting(client: client);

      final rows = await backend.readYearSheet('spreadsheet-1', 2026);

      expect(rows, isEmpty);
      expect(client.titlesCalls, greaterThanOrEqualTo(1));
    });

    test('missing spreadsheet propagates and is never empty data', () async {
      final client = FakeSheetsApiClient();
      client.titlesError = const SheetsApiException(
        SheetsErrorKind.missingSpreadsheet,
        'Requested entity was not found',
        404,
      );
      final backend = GoogleSheetsBackend.forTesting(client: client);

      await expectLater(
        backend.readYearSheet('missing-id', 2026),
        throwsA(
          isA<SheetsApiException>().having(
            (e) => e.kind,
            'kind',
            SheetsErrorKind.missingSpreadsheet,
          ),
        ),
      );
    });

    test('permission and network failures propagate', () async {
      final permissionClient = FakeSheetsApiClient();
      permissionClient.titlesError = const SheetsApiException(
        SheetsErrorKind.permissionDenied,
        'The caller does not have permission',
        403,
      );
      final permissionBackend =
          GoogleSheetsBackend.forTesting(client: permissionClient);
      await expectLater(
        permissionBackend.readYearSheet('spreadsheet-1', 2026),
        throwsA(
          isA<SheetsApiException>().having(
            (e) => e.kind,
            'kind',
            SheetsErrorKind.permissionDenied,
          ),
        ),
      );

      final networkClient = FakeSheetsApiClient();
      networkClient.readError = const SheetsApiException(
        SheetsErrorKind.network,
        'SocketException: Failed host lookup',
      );
      final networkBackend =
          GoogleSheetsBackend.forTesting(client: networkClient);
      await expectLater(
        networkBackend.readYearSheet('spreadsheet-1', 2026),
        throwsA(
          isA<SheetsApiException>().having(
            (e) => e.kind,
            'kind',
            SheetsErrorKind.network,
          ),
        ),
      );
    });

    test('classifySheetsError distinguishes status and network text', () {
      expect(
        classifySheetsError(
          const _StubApiError(401, 'Unauthorized'),
          kindFor404: SheetsErrorKind.missingSpreadsheet,
        ),
        SheetsErrorKind.authentication,
      );
      expect(
        classifySheetsError(
          const _StubApiError(403, 'Forbidden'),
          kindFor404: SheetsErrorKind.missingSpreadsheet,
        ),
        SheetsErrorKind.permissionDenied,
      );
      expect(
        classifySheetsError(
          const _StubApiError(404, 'Not found'),
          kindFor404: SheetsErrorKind.missingWorksheet,
        ),
        SheetsErrorKind.missingWorksheet,
      );
      expect(
        classifySheetsError(
          const _StubApiError(404, 'Not found'),
          kindFor404: SheetsErrorKind.missingSpreadsheet,
        ),
        SheetsErrorKind.missingSpreadsheet,
      );
      expect(
        classifySheetsError(
          Exception('SocketException: Failed host lookup'),
          kindFor404: SheetsErrorKind.missingSpreadsheet,
        ),
        SheetsErrorKind.network,
      );
      expect(
        classifySheetsError(
          Exception('Something unexpected'),
          kindFor404: SheetsErrorKind.missingSpreadsheet,
        ),
        SheetsErrorKind.unknown,
      );
    });
  });

  group('SheetsSyncCoordinator', () {
    test('failed sync leaves pending and manual retry syncs it', () async {
      final backend = FakeSheetsBackend()..failNextWrite = true;
      final store = FakeStore([makeTx()]);
      final notifications = <NotificationType>[];
      final coordinator = SheetsSyncCoordinator(
        backend: backend,
        store: store,
        onNotification: ({
          required type,
          required title,
          required message,
        }) {
          notifications.add(type);
        },
      );

      await coordinator.requestSync();
      expect(store.markedSynced, isEmpty);
      expect(store.pending, hasLength(1));
      expect(notifications, [NotificationType.syncFailed]);

      await coordinator.syncNow();
      expect(store.markedSynced, [1]);
      expect(store.pending, isEmpty);
      expect(notifications, [
        NotificationType.syncFailed,
        NotificationType.syncCompleted,
      ]);
      coordinator.dispose();
    });

    test('not signed in stays silent and leaves work pending', () async {
      final backend = _NotSignedInBackend();
      final store = FakeStore([makeTx()]);
      final notifications = <NotificationType>[];
      final coordinator = SheetsSyncCoordinator(
        backend: backend,
        store: store,
        onNotification: ({
          required type,
          required title,
          required message,
        }) {
          notifications.add(type);
        },
      );

      await coordinator.requestBackgroundSync();
      expect(store.markedSynced, isEmpty);
      expect(notifications, isEmpty);
      coordinator.dispose();
    });

    test('missing authorization stays pending, flags it, and does not retry on a timer', () async {
      final backend = _AuthorizationMissingBackend();
      final store = FakeStore([makeTx()]);
      final notifications = <NotificationType>[];
      final coordinator = SheetsSyncCoordinator(
        backend: backend,
        store: store,
        onNotification: ({
          required type,
          required title,
          required message,
        }) {
          notifications.add(type);
        },
      );

      await coordinator.requestSync();
      expect(store.pending, hasLength(1));
      expect(coordinator.authorizationMissing, isTrue);
      // One clear authorization-needed notification, not a
      // generic retry loop.
      expect(notifications, [NotificationType.syncFailed]);
      coordinator.dispose();
    });

    test('trigger during a run is drained without another manual trigger', () async {
      final backend = FakeSheetsBackend();
      backend.writeGate = Completer<void>();
      final store = FakeStore([makeTx(localId: 1, uuid: 'a')]);
      final coordinator = SheetsSyncCoordinator(
        backend: backend,
        store: store,
        onNotification: ({
          required type,
          required title,
          required message,
        }) {},
      );

      final firstRun = coordinator.requestSync();
      await backend.writeStarted.future;

      // New work arrives after the first batch was read but
      // before it finishes; its trigger joins the running run.
      store.add(makeTx(localId: 2, uuid: 'b'));
      final joined = coordinator.requestSync();
      backend.writeGate!.complete();

      await firstRun;
      await joined;

      expect(store.pending, isEmpty);
      expect(store.markedSynced, [1, 2]);
      expect(backend.sheets[2026], hasLength(2));
      coordinator.dispose();
    });

    test('concurrent triggers join a single run when no new work arrives', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx()]);
      final coordinator = SheetsSyncCoordinator(
        backend: backend,
        store: store,
        onNotification: ({
          required type,
          required title,
          required message,
        }) {},
      );

      await Future.wait([
        coordinator.requestSync(),
        coordinator.requestSync(),
      ]);

      expect(backend.resolveCalls, 1);
      expect(store.markedSynced, [1]);
      coordinator.dispose();
    });
  });

  group('Authorization mode separation', () {
    test('silent backend requests no interactive authorization', () async {
      var requestedInteractive = false;
      SheetsApiClient factory({required bool interactive}) {
        requestedInteractive = interactive;
        return FakeSheetsApiClient();
      }

      final backend = GoogleSheetsBackend.withClientFactory(
        interactive: false,
        clientFactory: factory,
      );

      expect(backend.interactive, isFalse);
      await backend.resolveSpreadsheetId();
      expect(requestedInteractive, isFalse);
    });

    test('interactive backend requests interactive authorization', () async {
      var requestedInteractive = false;
      SheetsApiClient factory({required bool interactive}) {
        requestedInteractive = interactive;
        return FakeSheetsApiClient();
      }

      final backend = GoogleSheetsBackend.withClientFactory(
        interactive: true,
        clientFactory: factory,
      );

      expect(backend.interactive, isTrue);
      await backend.resolveSpreadsheetId();
      expect(requestedInteractive, isTrue);
    });

    test('silent and interactive backend instances are distinct modes', () {
      expect(GoogleSheetsBackend.instance.interactive, isFalse);
      expect(
        GoogleSheetsBackend.interactiveInstance.interactive,
        isTrue,
      );
    });
  });
}
