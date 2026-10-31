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

  /// When true, listing year worksheets throws, as the production
  /// backend does when discovery fails. The engine must abort
  /// the whole run in that case.
  bool failListYearSheets = false;

  /// Years `ensureYearSheet` was called for, in call order.
  /// Mirrors production: calling it for a missing year creates
  /// that year, so tests can prove a path created nothing.
  final List<int> ensureCalls = <int>[];
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
    if (failListYearSheets) {
      throw Exception('Worksheet discovery failed');
    }
    return sheets.keys.toList();
  }

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    ensureCalls.add(year);
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
/// synced only when the stored integer revision ([SyncTransaction.syncRevision]
/// + deleted) and pending state still match the uploaded
/// snapshot. Editing a transaction advances its revision and
/// keeps it pending. Mirrors the production rule in
/// `markTransactionSyncedIfUnchanged`: `updatedAt` is timestamp
/// metadata, never the acknowledgement token.
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
    final nextUpdatedAt = old.updatedAt.add(const Duration(seconds: 1));
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
        syncRevision: old.syncRevision + 1,
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
    if (entry.tx.syncRevision != transaction.syncRevision ||
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
  int syncRevision = 0,
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
    syncRevision: syncRevision,
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

  /// The value-input option the production backend requested on
  /// the most recent write, so tests can prove transaction
  /// values are written RAW. This records the backend's choice
  /// of option only; it says nothing about how the Sheets API
  /// itself interprets RAW (that is a Google-side behaviour).
  SheetsValueInputOption? lastUpdateInputOption;
  SheetsValueInputOption? lastAppendInputOption;
  String? lastUpdateRange;
  String? lastAppendRange;

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
    required SheetsValueInputOption valueInputOption,
  }) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    lastUpdateInputOption = valueInputOption;
    lastUpdateRange = range;
    final year = int.parse(range.replaceAll("'", '').split('!').first);
    final rows = sheets.putIfAbsent(year, () => <List<Object?>>[]);
    // The backend writes single-row ranges such as A1:J1 or
    // A3:J3: replace exactly those rows, leaving the rest
    // untouched (mirrors the Sheets API for a bounded range).
    final rowMatch = RegExp(r'A(\d+):').firstMatch(range);
    if (rowMatch != null) {
      final startIndex = int.parse(rowMatch.group(1)!) - 1;
      for (var i = 0; i < values.length; i++) {
        final index = startIndex + i;
        while (rows.length <= index) {
          rows.add(const <Object?>[]);
        }
        rows[index] = values[i];
      }
      return;
    }
    sheets[year] = values;
  }

  @override
  Future<void> appendValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {
    final error = writeError;
    if (error != null) {
      throw error;
    }
    lastAppendInputOption = valueInputOption;
    lastAppendRange = range;
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
  ) async => <SheetRowData>[];

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
  ) async => <SheetRowData>[];

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
      final row = SheetRowData.fromValues(<Object?>[
        '2025-12-01',
        'Expense',
        'Food',
        'Old',
        99,
      ], 2);
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

    test(
      'retrying the same transaction updates instead of duplicating',
      () async {
        final backend = FakeSheetsBackend();
        final store = FakeStore([makeTx(amount: 250)]);

        await runEngine(SheetsSyncEngine(), backend, store);
        store.edit(localId: 1, amount: 300);
        await runEngine(SheetsSyncEngine(), backend, store);

        expect(backend.sheets[2026], hasLength(1));
        expect(backend.sheets[2026]!.single.amount, 300);
      },
    );

    test(
      'soft delete marks the row deleted and restore flips it back',
      () async {
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
      },
    );

    test(
      'deleting before first sync creates no row but still syncs locally',
      () async {
        final backend = FakeSheetsBackend();
        final store = FakeStore([makeTx(deleted: true)]);

        await runEngine(SheetsSyncEngine(), backend, store);

        expect(store.pending, isEmpty);
        expect(backend.sheets, isEmpty);
        expect(backend.ensureCalls, isEmpty);
        expect(backend.appendCalls, 0);
        expect(backend.updateCalls, 0);
      },
    );

    test(
      'deleted before first sync creates nothing even when other years exist',
      () async {
        final backend = FakeSheetsBackend();
        backend.seedRow(
          2024,
          SheetRowData.fromTransaction(makeTx(uuid: 'old')),
        );
        final store = FakeStore([makeTx(deleted: true)]);

        await runEngine(SheetsSyncEngine(), backend, store);

        expect(store.pending, isEmpty);
        expect(backend.sheets.keys, [2024]);
        expect(backend.ensureCalls, isEmpty);
        expect(backend.sheets[2024], hasLength(1));
      },
    );

    test('deleted transaction with a prior row in another year tombstones it and creates no new sheet', () async {
      final backend = FakeSheetsBackend();
      backend.seedRow(
        2025,
        SheetRowData.fromTransaction(makeTx(date: DateTime(2025, 12, 31))),
      );
      // Local date moved to 2026 and the transaction deleted.
      final store = FakeStore([
        makeTx(date: DateTime(2026, 1, 5), deleted: true),
      ]);

      await runEngine(SheetsSyncEngine(), backend, store);

      expect(store.pending, isEmpty);
      expect(backend.sheets[2026], isNull);
      expect(backend.ensureCalls, [2025]);
      expect(backend.sheets[2025], hasLength(1));
      expect(backend.sheets[2025]!.single.deleted, isTrue);
      expect(backend.activeRows(2025), isEmpty);
    });

    test(
      'moving across years deletes the old row and writes the new year',
      () async {
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
      },
    );

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

    test(
      'tombstone succeeds but append fails: retry does not duplicate',
      () async {
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
      },
    );

    test(
      'append succeeds but acknowledgement fails: retry updates in place',
      () async {
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
      },
    );

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
    test(
      'duplicate rows in one worksheet are reported and nothing is written',
      () async {
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
      },
    );

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
        SheetRowData.fromTransaction(tx).copyWith(deleted: true, rowIndex: 2),
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
    test(
      'missing worksheet after spreadsheet verification reads as empty',
      () async {
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
      },
    );

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
      final permissionBackend = GoogleSheetsBackend.forTesting(
        client: permissionClient,
      );
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
      final networkBackend = GoogleSheetsBackend.forTesting(
        client: networkClient,
      );
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
        onNotification: ({required type, required title, required message}) {
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
        onNotification: ({required type, required title, required message}) {
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
        onNotification: ({required type, required title, required message}) {
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

    test(
      'trigger during a run is drained without another manual trigger',
      () async {
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
      },
    );

    test(
      'concurrent triggers join a single run when no new work arrives',
      () async {
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
      },
    );
  });

  group('Authorization mode routing (not plugin behaviour)', () {
    // These tests prove only which mode this code requests from
    // its own factory boundary. They do NOT prove what the
    // google_sign_in plugin does on a device: whether a given
    // plugin call shows UI is a platform behaviour documented
    // in the migration guide, and must be verified by the
    // manual Android checklist, not by a fake.
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
      expect(GoogleSheetsBackend.interactiveInstance.interactive, isTrue);
    });
  });

  group('Worksheet discovery failure aborts the run', () {
    test('listYearSheets failure: no writes, no acks, old row stays active, no new sheet', () async {
      final backend = FakeSheetsBackend();
      backend.seedRow(
        2025,
        SheetRowData.fromTransaction(makeTx(date: DateTime(2025, 12, 31))),
      );
      // Local date moved to 2026.
      final store = FakeStore([makeTx(date: DateTime(2026, 1, 5))]);
      backend.failListYearSheets = true;

      await expectLater(
        SheetsSyncEngine().syncAll(
          pending: await store.getPending(),
          backend: backend,
          onSynced: (tx) => store.markSynced(tx),
        ),
        throwsException,
      );

      expect(store.pending, hasLength(1));
      expect(backend.appendCalls, 0);
      expect(backend.updateCalls, 0);
      expect(backend.ensureCalls, isEmpty);
      expect(backend.resolveCalls, 1);
      expect(backend.sheets.keys, [2025]);
      expect(backend.activeRows(2025), hasLength(1));
      expect(backend.sheets[2026], isNull);
    });

    test('retry after discovery recovers converges the year move', () async {
      final backend = FakeSheetsBackend();
      backend.seedRow(
        2025,
        SheetRowData.fromTransaction(makeTx(date: DateTime(2025, 12, 31))),
      );
      final store = FakeStore([makeTx(date: DateTime(2026, 1, 5))]);
      backend.failListYearSheets = true;
      final engine = SheetsSyncEngine();

      await expectLater(
        engine.syncAll(
          pending: await store.getPending(),
          backend: backend,
          onSynced: (tx) => store.markSynced(tx),
        ),
        throwsException,
      );
      expect(store.pending, hasLength(1));

      backend.failListYearSheets = false;
      await runEngine(engine, backend, store);

      expect(store.pending, isEmpty);
      expect(backend.activeRows(2025), isEmpty);
      expect(backend.activeRows(2026), hasLength(1));
    });
  });

  group('Missing or revoked session never marks synced', () {
    test('not signed in aborts before any write or acknowledgement', () async {
      final backend = _NotSignedInBackend();
      final store = FakeStore([makeTx()]);

      await expectLater(
        SheetsSyncEngine().syncAll(
          pending: await store.getPending(),
          backend: backend,
          onSynced: (tx) => store.markSynced(tx),
        ),
        throwsA(isA<SheetsNotSignedInException>()),
      );
      expect(store.pending, hasLength(1));
      expect(store.markedSynced, isEmpty);
    });

    test(
      'authorization missing aborts before any write or acknowledgement',
      () async {
        final backend = _AuthorizationMissingBackend();
        final store = FakeStore([makeTx()]);

        await expectLater(
          SheetsSyncEngine().syncAll(
            pending: await store.getPending(),
            backend: backend,
            onSynced: (tx) => store.markSynced(tx),
          ),
          throwsA(isA<SheetsAuthorizationMissingException>()),
        );
        expect(store.pending, hasLength(1));
        expect(store.markedSynced, isEmpty);
      },
    );
  });

  group('RAW transaction values', () {
    const formulaDescription = '=IMPORTXML("https://example.invalid","//x")';
    const formulaNotes = '=1+1';

    test('append stores formula-like text literally and keeps amount numeric, with RAW', () async {
      final client = FakeSheetsApiClient();
      final backend = GoogleSheetsBackend.forTesting(client: client);
      final row = SheetRowData.fromTransaction(
        makeTx(description: formulaDescription, notes: formulaNotes),
      );

      await backend.appendRow('spreadsheet-1', 2026, row);

      expect(client.lastAppendInputOption, SheetsValueInputOption.raw);
      final stored = client.sheets[2026]!.single;
      expect(stored[3], formulaDescription);
      expect(stored[7], formulaNotes);
      expect(stored[4], isA<num>());
      expect(stored[4], 250);

      // Reading it back parses the same literal values.
      final rows = await backend.readYearSheet('spreadsheet-1', 2026);
      expect(rows, hasLength(1));
      expect(rows.single.description, formulaDescription);
      expect(rows.single.notes, formulaNotes);
      expect(rows.single.amount, 250);
    });

    test('update stores formula-like text literally with RAW', () async {
      final client = FakeSheetsApiClient();
      client.sheets[2026] = <List<Object?>>[
        sheetHeaders,
        <Object?>[
          '2026-03-10',
          'Expense',
          'Food',
          'Lunch',
          250,
          'uuid-1',
          'UPI',
          '',
          '2026-03-10T12:00:00.000',
          'FALSE',
        ],
      ];
      final backend = GoogleSheetsBackend.forTesting(client: client);
      final row = SheetRowData.fromTransaction(
        makeTx(description: formulaDescription, notes: formulaNotes),
        rowIndex: 2,
      );

      await backend.updateRow('spreadsheet-1', 2026, 2, row);

      expect(client.lastUpdateInputOption, SheetsValueInputOption.raw);
      expect(client.sheets[2026], hasLength(2));
      expect(client.sheets[2026]![1][3], formulaDescription);
      expect(client.sheets[2026]![1][7], formulaNotes);
      expect(client.sheets[2026]![1][4], isA<num>());
    });

    test('header writing still uses RAW (unchanged behaviour)', () async {
      final client = FakeSheetsApiClient();
      final backend = GoogleSheetsBackend.forTesting(client: client);

      await backend.ensureYearSheet('spreadsheet-1', 2026);

      expect(client.lastUpdateInputOption, SheetsValueInputOption.raw);
      expect(client.sheets[2026]!.first, sheetHeaders);
    });
  });

  group('Legacy five-column headers', () {
    const legacyHeader = <Object?>[
      'Date',
      'Type',
      'Category',
      'Description',
      'Amount',
    ];

    List<Object?> legacyRow(String date, String description, Object amount) {
      return <Object?>[date, 'Expense', 'Food', description, amount];
    }

    test('ensureYearSheet extends only the header row to A:J and preserves every data row', () async {
      final client = FakeSheetsApiClient();
      client.sheets[2025] = <List<Object?>>[
        legacyHeader,
        legacyRow('2025-01-05', 'Old lunch', 120),
        legacyRow('2025-02-11', 'Bus fare', 40),
        legacyRow('2025-03-20', 'Books', 350),
      ];
      final backend = GoogleSheetsBackend.forTesting(client: client);

      await backend.ensureYearSheet('spreadsheet-1', 2025);

      final stored = client.sheets[2025]!;
      expect(stored, hasLength(4));
      expect(stored.first, sheetHeaders);
      expect(stored[1], legacyRow('2025-01-05', 'Old lunch', 120));
      expect(stored[2], legacyRow('2025-02-11', 'Bus fare', 40));
      expect(stored[3], legacyRow('2025-03-20', 'Books', 350));
      // No UUID was invented for any legacy row.
      for (var i = 1; i < stored.length; i++) {
        expect(stored[i].length, 5);
      }
    });

    test('readYearSheet skips the legacy header and returns legacy rows with empty UUIDs', () async {
      final client = FakeSheetsApiClient();
      client.sheets[2025] = <List<Object?>>[
        legacyHeader,
        legacyRow('2025-01-05', 'Old lunch', 120),
        legacyRow('2025-02-11', 'Bus fare', 40),
      ];
      final backend = GoogleSheetsBackend.forTesting(client: client);

      final rows = await backend.readYearSheet('spreadsheet-1', 2025);

      expect(rows, hasLength(2));
      expect(rows[0].uuid, '');
      expect(rows[0].description, 'Old lunch');
      expect(rows[0].amount, 120);
      expect(rows[0].rowIndex, 2);
      expect(rows[1].uuid, '');
      expect(rows[1].rowIndex, 3);
    });

    test(
      'engine sync preserves legacy rows and appends the new UUID row',
      () async {
        final client = FakeSheetsApiClient();
        client.sheets[2026] = <List<Object?>>[
          legacyHeader,
          legacyRow('2026-01-05', 'Old lunch', 120),
          legacyRow('2026-02-11', 'Bus fare', 40),
        ];
        final backend = GoogleSheetsBackend.forTesting(client: client);
        final store = FakeStore([makeTx(date: DateTime(2026, 3, 10))]);
        final engine = SheetsSyncEngine();

        await engine.syncAll(
          pending: await store.getPending(),
          backend: backend,
          onSynced: (tx) => store.markSynced(tx),
        );

        final stored = client.sheets[2026]!;
        expect(stored, hasLength(4));
        expect(stored.first, sheetHeaders);
        expect(stored[1], legacyRow('2026-01-05', 'Old lunch', 120));
        expect(stored[2], legacyRow('2026-02-11', 'Bus fare', 40));
        expect(stored[3][5], 'uuid-1');
        expect(stored[3][3], 'Lunch');
        expect(store.pending, isEmpty);
      },
    );

    test(
      'year move with a legacy old-year sheet leaves legacy rows untouched',
      () async {
        final client = FakeSheetsApiClient();
        client.sheets[2025] = <List<Object?>>[
          legacyHeader,
          legacyRow('2025-12-01', 'Old lunch', 120),
        ];
        final backend = GoogleSheetsBackend.forTesting(client: client);
        final store = FakeStore([makeTx(date: DateTime(2026, 1, 5))]);
        final engine = SheetsSyncEngine();

        await engine.syncAll(
          pending: await store.getPending(),
          backend: backend,
          onSynced: (tx) => store.markSynced(tx),
        );

        // The legacy 2025 header was extended (engine prepared
        // 2026 only for the write; 2025 was read, not written,
        // because no UUID row matched there). Legacy data row
        // is byte-for-byte the same.
        final stored2025 = client.sheets[2025]!;
        expect(stored2025, hasLength(2));
        expect(stored2025[1], legacyRow('2025-12-01', 'Old lunch', 120));
        expect(stored2025[0], legacyHeader);
        expect(client.sheets[2026]!.last[5], 'uuid-1');
        expect(store.pending, isEmpty);
      },
    );

    test('a current A:J header is left alone by ensureYearSheet', () async {
      final client = FakeSheetsApiClient();
      client.sheets[2026] = <List<Object?>>[
        sheetHeaders,
        <Object?>[
          '2026-03-10',
          'Expense',
          'Food',
          'Lunch',
          250,
          'uuid-9',
          'UPI',
          '',
          '2026-03-10T12:00:00.000',
          'FALSE',
        ],
      ];
      final backend = GoogleSheetsBackend.forTesting(client: client);

      await backend.ensureYearSheet('spreadsheet-1', 2026);

      expect(client.lastUpdateInputOption, isNull);
      expect(client.sheets[2026], hasLength(2));
      expect(client.sheets[2026]!.first, sheetHeaders);
    });
  });
}
