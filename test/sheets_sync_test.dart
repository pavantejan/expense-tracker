import 'package:expense_tracker/core/sync/sheets_sync.dart';
import 'package:expense_tracker/core/sync/sync_coordinator.dart';
import 'package:expense_tracker/data/notifications/notification.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSheetsBackend implements SheetsSyncBackend {
  final Map<int, List<SheetRowData>> sheets = <int, List<SheetRowData>>{};
  int resolveCalls = 0;
  bool failResolve = false;
  bool failNextWrite = false;

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
    return List<SheetRowData>.unmodifiable(sheets[year] ?? const <SheetRowData>[]);
  }

  void _maybeFail() {
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
    _maybeFail();
    final rows = sheets.putIfAbsent(year, () => <SheetRowData>[]);
    // Header is row 1; the first data row is row 2.
    rows.add(row.copyWith(rowIndex: rows.length + 2));
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) async {
    _maybeFail();
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
}

class FakeStore implements SyncTransactionStore {
  FakeStore(this.pending);

  List<SyncTransaction> pending;
  final List<int> markedSynced = <int>[];

  @override
  Future<List<SyncTransaction>> getPending() async {
    return List<SyncTransaction>.unmodifiable(pending);
  }

  @override
  Future<void> markSynced(int localId) async {
    markedSynced.add(localId);
    pending = pending.where((tx) => tx.localId != localId).toList();
  }
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

  group('SheetsSyncEngine', () {
    test('create appends one row to the transaction-date year sheet', () async {
      final backend = FakeSheetsBackend();
      final engine = SheetsSyncEngine();
      final marked = <String>[];

      final result = await engine.syncAll(
        pending: [makeTx(date: DateTime(2025, 11, 2))],
        backend: backend,
        onSynced: (tx) async => marked.add(tx.uuid),
      );

      expect(result.failedUuids, isEmpty);
      expect(marked, ['uuid-1']);
      expect(backend.sheets[2025], hasLength(1));
      expect(backend.sheets[2026], isNull);
      expect(backend.activeRows(2025).single.uuid, 'uuid-1');
    });

    test('retrying the same transaction updates instead of duplicating', () async {
      final backend = FakeSheetsBackend();
      final engine = SheetsSyncEngine();
      final marked = <String>[];

      Future<void> run(SyncTransaction tx) async {
        await engine.syncAll(
          pending: [tx],
          backend: backend,
          onSynced: (t) async => marked.add(t.uuid),
        );
      }

      await run(makeTx(amount: 250));
      await run(makeTx(amount: 300, updatedAt: DateTime(2026, 3, 11)));

      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.amount, 300);
    });

    test('soft delete marks the row deleted and restore flips it back', () async {
      final backend = FakeSheetsBackend();
      final engine = SheetsSyncEngine();

      Future<void> run(SyncTransaction tx) async {
        await engine.syncAll(
          pending: [tx],
          backend: backend,
          onSynced: (_) async {},
        );
      }

      await run(makeTx());
      await run(makeTx(deleted: true));
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isTrue);
      expect(backend.activeRows(2026), isEmpty);

      await run(makeTx(deleted: false));
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isFalse);
    });

    test('deleting before first sync creates no row but still syncs locally', () async {
      final backend = FakeSheetsBackend();
      final engine = SheetsSyncEngine();
      final marked = <String>[];

      final result = await engine.syncAll(
        pending: [makeTx(deleted: true)],
        backend: backend,
        onSynced: (tx) async => marked.add(tx.uuid),
      );

      expect(result.failedUuids, isEmpty);
      expect(marked, ['uuid-1']);
      expect(backend.sheets, isEmpty);
    });

    test('moving across years deletes the old row and writes the new year', () async {
      final backend = FakeSheetsBackend();
      final engine = SheetsSyncEngine();

      Future<void> run(SyncTransaction tx) async {
        await engine.syncAll(
          pending: [tx],
          backend: backend,
          onSynced: (_) async {},
        );
      }

      await run(makeTx(date: DateTime(2025, 12, 31)));
      await run(makeTx(date: DateTime(2026, 1, 2)));

      expect(backend.sheets[2025], hasLength(1));
      expect(backend.sheets[2025]!.single.deleted, isTrue);
      expect(backend.sheets[2026], hasLength(1));
      expect(backend.sheets[2026]!.single.deleted, isFalse);
      expect(backend.activeRows(2025), isEmpty);
      expect(backend.activeRows(2026), hasLength(1));
    });

    test('failed write retains pending status and retry succeeds', () async {
      final backend = FakeSheetsBackend()..failNextWrite = true;
      final engine = SheetsSyncEngine();
      final marked = <String>[];

      final failed = await engine.syncAll(
        pending: [makeTx()],
        backend: backend,
        onSynced: (tx) async => marked.add(tx.uuid),
      );

      expect(failed.failedUuids, ['uuid-1']);
      expect(marked, isEmpty);
      expect(backend.sheets[2026], isEmpty);

      final retried = await engine.syncAll(
        pending: [makeTx()],
        backend: backend,
        onSynced: (tx) async => marked.add(tx.uuid),
      );

      expect(retried.failedUuids, isEmpty);
      expect(marked, ['uuid-1']);
      expect(backend.sheets[2026], hasLength(1));
    });

    test('failed spreadsheet resolution syncs nothing', () async {
      final backend = FakeSheetsBackend()..failResolve = true;
      final engine = SheetsSyncEngine();

      await expectLater(
        engine.syncAll(
          pending: [makeTx()],
          backend: backend,
          onSynced: (_) async {},
        ),
        throwsException,
      );
      expect(backend.sheets, isEmpty);
    });

    test('one failing transaction does not block the others', () async {
      final backend = FakeSheetsBackend();
      final engine = SheetsSyncEngine();
      // Fail only the first write by making the second transaction
      // use a backend that fails once: simulate via a wrapper.
      var writes = 0;
      final flaky = _FlakyBackend(backend, () {
        writes++;
        return writes == 1;
      });

      final result = await engine.syncAll(
        pending: [makeTx(localId: 1, uuid: 'a'), makeTx(localId: 2, uuid: 'b')],
        backend: flaky,
        onSynced: (_) async {},
      );

      expect(result.failedUuids, ['a']);
      expect(result.syncedUuids, ['b']);
      expect(backend.sheets[2026], hasLength(1));
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

    test('concurrent triggers join a single run', () async {
      final backend = FakeSheetsBackend();
      final store = FakeStore([makeTx()]);
      final coordinator = SheetsSyncCoordinator(
        backend: backend,
        store: store,
        onNotification: ({required type, required title, required message}) {},
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
}

class _FlakyBackend implements SheetsSyncBackend {
  _FlakyBackend(this.inner, this.shouldFail);

  final FakeSheetsBackend inner;
  final bool Function() shouldFail;

  @override
  Future<String> resolveSpreadsheetId() => inner.resolveSpreadsheetId();

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) =>
      inner.listYearSheets(spreadsheetId);

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) =>
      inner.ensureYearSheet(spreadsheetId, year);

  @override
  Future<List<SheetRowData>> readYearSheet(String spreadsheetId, int year) =>
      inner.readYearSheet(spreadsheetId, year);

  @override
  Future<void> appendRow(String spreadsheetId, int year, SheetRowData row) async {
    if (shouldFail()) {
      throw Exception('Sheets write failed');
    }
    return inner.appendRow(spreadsheetId, year, row);
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) =>
      inner.updateRow(spreadsheetId, year, rowIndex, row);
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
