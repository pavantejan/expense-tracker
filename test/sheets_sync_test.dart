import 'dart:async';

import 'package:expense_tracker/core/sync/google_sheets_backend.dart';
import 'package:expense_tracker/core/sync/sync_coordinator.dart';
import 'package:expense_tracker/core/sync/sync_errors.dart';
import 'package:expense_tracker/core/sync/v2/drift_v2_sync_store.dart';
import 'package:expense_tracker/core/sync/v2/google_sheets_v2_backend.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_contract.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_engine.dart';
import 'package:expense_tracker/core/sync/v2/sheets_v2_mapper.dart';
import 'package:expense_tracker/data/notifications/notification.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakeBackend implements SheetsV2SyncBackend {
  final Map<int, List<SheetV2Row>> sheets = <int, List<SheetV2Row>>{};
  int resolveCalls = 0;
  bool failNextWrite = false;
  bool failNextUpdate = false;
  bool failNextAppend = false;
  Object? resolveError;

  /// When set, appendRow signals [writeStarted] and waits for
  /// [writeGate] before writing.
  Completer<void>? writeGate;
  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<String> resolveSpreadsheetId() async {
    resolveCalls++;
    final error = resolveError;
    if (error != null) {
      throw error;
    }
    return 'v2-id';
  }

  @override
  Future<void> verifyV2Identity(String spreadsheetId) async {}

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async =>
      sheets.keys.toList();

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    sheets.putIfAbsent(year, () => <SheetV2Row>[]);
  }

  @override
  Future<List<SheetV2Row>> readYearSheet(String spreadsheetId, int year) async {
    final rows = sheets[year] ?? const <SheetV2Row>[];
    return [
      for (var i = 0; i < rows.length; i++) rows[i].copyWith(rowIndex: i + 2),
    ];
  }

  @override
  Future<void> appendRow(String spreadsheetId, int year, SheetV2Row row) async {
    final gate = writeGate;
    if (gate != null) {
      if (!writeStarted.isCompleted) {
        writeStarted.complete();
      }
      await gate.future;
    }
    if (failNextWrite || failNextAppend) {
      failNextWrite = false;
      failNextAppend = false;
      throw Exception('append failed');
    }
    sheets[year]!.add(row);
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetV2Row row,
  ) async {
    if (failNextWrite || failNextUpdate) {
      failNextWrite = false;
      failNextUpdate = false;
      throw Exception('update failed');
    }
    sheets[year]![rowIndex - 2] = row;
  }

  List<SheetV2Row> active(String uuid) => [
    for (final rows in sheets.values)
      ...rows.where((r) => r.uuid == uuid && !r.deleted),
  ];
}

SheetV2Source source({
  String uuid = 'uuid-1',
  DateTime? date,
  int amount = 25000,
  bool deleted = false,
  String description = 'Lunch',
}) {
  return SheetV2Source(
    uuid: uuid,
    kind: 'expense',
    occurredAt: date ?? DateTime(2026, 3, 10),
    amountMinorUnits: amount,
    currencyCode: 'INR',
    paymentChannel: 'UPI',
    source: 'manual',
    updatedAt: DateTime.utc(2026, 3, 10, 12),
    deleted: deleted,
    categoryId: 'food',
    categoryName: 'Food',
    description: description,
    account: const SheetV2AccountRef(id: 'acc-1', name: 'Bank'),
  );
}

/// In-memory store with the same conditional-acknowledgement rule as
/// the Drift store: revision and status must still match.
class FakeStore implements V2SyncStore {
  FakeStore(List<V2SyncItem> initial) {
    for (final item in initial) {
      _items[item.localId] = item;
      _pending.add(item.localId);
    }
  }

  final Map<int, V2SyncItem> _items = <int, V2SyncItem>{};
  final Set<int> _pending = <int>{};
  final List<int> markedSynced = <int>[];

  List<V2SyncItem> get pending => [for (final id in _pending) _items[id]!];

  void add(V2SyncItem item) {
    _items[item.localId] = item;
    _pending.add(item.localId);
  }

  void edit(int localId, SheetV2Source newSource) {
    final old = _items[localId]!;
    _items[localId] = V2SyncItem(
      localId: localId,
      syncRevision: old.syncRevision + 1,
      status: newSource.deleted ? 'deleted' : 'active',
      source: newSource,
    );
    _pending.add(localId);
  }

  @override
  Future<List<V2SyncItem>> getPending() async => pending;

  @override
  Future<bool> markSynced(V2SyncItem item) async {
    final current = _items[item.localId];
    if (current == null ||
        !_pending.contains(item.localId) ||
        current.syncRevision != item.syncRevision ||
        current.status != item.status) {
      return false;
    }
    _pending.remove(item.localId);
    markedSynced.add(item.localId);
    return true;
  }
}

V2SyncItem item(SheetV2Source s, {int localId = 1, int revision = 0}) =>
    V2SyncItem(
      localId: localId,
      syncRevision: revision,
      status: s.deleted ? 'deleted' : 'active',
      source: s,
    );

Future<void> runEngine(FakeBackend backend, FakeStore store) async {
  await SheetsV2SyncEngine().syncAll(
    pending: await store.getPending(),
    backend: backend,
    onSynced: store.markSynced,
  );
}

class FakeApiClient implements SheetsApiClient {
  SheetsApiException? titlesError;
  SheetsApiException? readError;
  int titlesCalls = 0;

  @override
  Future<String> resolveSpreadsheetId() async => 'v2-id';

  @override
  Future<List<String>> sheetTitles(String spreadsheetId) async {
    titlesCalls++;
    final error = titlesError;
    if (error != null) {
      throw error;
    }
    return ['_meta', '2026'];
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
    return const [];
  }

  @override
  Future<void> updateValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {}

  @override
  Future<void> appendValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {}

  @override
  Future<void> addSheet(String spreadsheetId, String title) async {}
}

class _StubApiError {
  const _StubApiError(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'StubApiError $status: $message';
}

SheetsSyncCoordinator coordinatorFor(
  SheetsV2SyncBackend backend,
  V2SyncStore store, [
  List<NotificationType>? notifications,
]) {
  return SheetsSyncCoordinator(
    backend: backend,
    store: store,
    onNotification: ({required type, required title, required message}) {
      notifications?.add(type);
    },
  );
}

void main() {
  group('Sheets error classification', () {
    test(
      'missing worksheet after spreadsheet verification reads as empty',
      () async {
        final client = FakeApiClient()
          ..readError = const SheetsApiException(
            SheetsErrorKind.missingWorksheet,
            'Unable to parse range',
            404,
          );
        final backend = GoogleSheetsV2Backend.forTesting(client: client);

        expect(await backend.readYearSheet('v2-id', 2026), isEmpty);
        expect(client.titlesCalls, greaterThanOrEqualTo(1));
      },
    );

    test(
      'missing spreadsheet, permission and network errors propagate',
      () async {
        for (final kind in [
          SheetsErrorKind.missingSpreadsheet,
          SheetsErrorKind.permissionDenied,
          SheetsErrorKind.network,
        ]) {
          final client = FakeApiClient()
            ..titlesError = SheetsApiException(kind, 'failure');
          await expectLater(
            GoogleSheetsV2Backend.forTesting(client: client)
                .readYearSheet('v2-id', 2026),
            throwsA(
              isA<SheetsApiException>().having((e) => e.kind, 'kind', kind),
            ),
          );
        }
      },
    );

    test('classifySheetsError distinguishes status and network text', () {
      SheetsErrorKind classify(Object error, SheetsErrorKind for404) =>
          classifySheetsError(error, kindFor404: for404);
      const spreadsheet = SheetsErrorKind.missingSpreadsheet;
      expect(
        classify(const _StubApiError(401, 'x'), spreadsheet),
        SheetsErrorKind.authentication,
      );
      expect(
        classify(const _StubApiError(403, 'x'), spreadsheet),
        SheetsErrorKind.permissionDenied,
      );
      expect(
        classify(
          const _StubApiError(404, 'x'),
          SheetsErrorKind.missingWorksheet,
        ),
        SheetsErrorKind.missingWorksheet,
      );
      expect(classify(const _StubApiError(404, 'x'), spreadsheet), spreadsheet);
      expect(
        classify(Exception('SocketException: Failed host lookup'), spreadsheet),
        SheetsErrorKind.network,
      );
      expect(
        classify(Exception('Something unexpected'), spreadsheet),
        SheetsErrorKind.unknown,
      );
    });
  });

  group('Partial failures converge on retry', () {
    test('year move: tombstone failure, retry leaves one active row', () async {
      final backend = FakeBackend();
      final store = FakeStore([item(source())]);
      await runEngine(backend, store);

      store.edit(1, source(date: DateTime(2025, 12, 31)));
      backend.failNextUpdate = true;
      await runEngine(backend, store);
      expect(store.pending, hasLength(1));

      await runEngine(backend, store);
      expect(store.pending, isEmpty);
      expect(backend.active('uuid-1'), hasLength(1));
      expect(backend.sheets[2025]!.single.deleted, isFalse);
    });

    test(
      'year move: target write failure, retry leaves one active row',
      () async {
        final backend = FakeBackend();
        final store = FakeStore([item(source())]);
        await runEngine(backend, store);

        store.edit(1, source(date: DateTime(2025, 12, 31)));
        backend.failNextAppend = true;
        await runEngine(backend, store);
        expect(store.pending, hasLength(1));
        expect(backend.active('uuid-1'), isEmpty);

        await runEngine(backend, store);
        expect(store.pending, isEmpty);
        expect(backend.active('uuid-1'), hasLength(1));
      },
    );

    test(
      'an edit during a paused write keeps the newer revision pending',
      () async {
        final backend = FakeBackend()..writeGate = Completer<void>();
        final store = FakeStore([item(source())]);
        final run = runEngine(backend, store);
        await backend.writeStarted.future;

        store.edit(1, source(description: 'Dinner'));
        backend.writeGate!.complete();
        await run;
        expect(store.pending, hasLength(1), reason: 'stale ack rejected');

        backend.writeGate = null;
        await runEngine(backend, store);
        expect(store.pending, isEmpty);
        expect(backend.sheets[2026]!.single.description, 'Dinner');
      },
    );
  });

  group('SheetsSyncCoordinator', () {
    test('failed sync leaves pending and manual retry syncs it', () async {
      final backend = FakeBackend()..failNextWrite = true;
      final store = FakeStore([item(source())]);
      final notifications = <NotificationType>[];
      final coordinator = coordinatorFor(backend, store, notifications);

      await coordinator.requestSync();
      expect(store.pending, hasLength(1));
      expect(notifications, [NotificationType.syncFailed]);

      await coordinator.syncNow();
      expect(store.markedSynced, [1]);
      expect(notifications, [
        NotificationType.syncFailed,
        NotificationType.syncCompleted,
      ]);
      coordinator.dispose();
    });

    test('not signed in stays silent and leaves work pending', () async {
      final backend = FakeBackend()
        ..resolveError = const SheetsNotSignedInException();
      final store = FakeStore([item(source())]);
      final notifications = <NotificationType>[];
      final coordinator = coordinatorFor(backend, store, notifications);

      await coordinator.requestBackgroundSync();
      expect(store.markedSynced, isEmpty);
      expect(notifications, isEmpty);
      coordinator.dispose();
    });

    test(
      'missing authorization stays pending, flags it, no timer retry',
      () async {
        final backend = FakeBackend()
          ..resolveError = const SheetsAuthorizationMissingException();
        final store = FakeStore([item(source())]);
        final notifications = <NotificationType>[];
        final coordinator = coordinatorFor(backend, store, notifications);

        await coordinator.requestSync();
        expect(store.pending, hasLength(1));
        expect(coordinator.authorizationMissing, isTrue);
        expect(notifications, [NotificationType.syncFailed]);
        coordinator.dispose();
      },
    );

    test('unsyncable rows notify once and schedule no retry', () async {
      final backend = FakeBackend();
      final store = FakeStore([
        item(source(uuid: 'big', amount: maxSheetAmountPaise + 1)),
        item(source(uuid: 'ok'), localId: 2),
      ]);
      final notifications = <NotificationType>[];
      final coordinator = coordinatorFor(backend, store, notifications);

      await coordinator.requestSync();
      expect(store.markedSynced, [2]);
      expect(store.pending.single.uuid, 'big');
      expect(notifications, [
        NotificationType.syncFailed,
        NotificationType.syncCompleted,
      ]);

      await coordinator.requestSync();
      expect(
        notifications.where((n) => n == NotificationType.syncFailed),
        hasLength(1),
      );
      coordinator.dispose();
    });

    test('trigger during a run is drained without another trigger', () async {
      final backend = FakeBackend()..writeGate = Completer<void>();
      final store = FakeStore([item(source(uuid: 'a'))]);
      final coordinator = coordinatorFor(backend, store);

      final firstRun = coordinator.requestSync();
      await backend.writeStarted.future;
      store.add(item(source(uuid: 'b'), localId: 2));
      final joined = coordinator.requestSync();
      backend.writeGate!.complete();
      await firstRun;
      await joined;

      expect(store.pending, isEmpty);
      expect(store.markedSynced, [1, 2]);
      expect(backend.sheets[2026], hasLength(2));
      coordinator.dispose();
    });

    test('concurrent triggers join a single run', () async {
      final backend = FakeBackend();
      final store = FakeStore([item(source())]);
      final coordinator = coordinatorFor(backend, store);

      await Future.wait([coordinator.requestSync(), coordinator.requestSync()]);
      expect(backend.resolveCalls, 1);
      expect(store.markedSynced, [1]);
      coordinator.dispose();
    });
  });

  group('Authorization mode routing (not plugin behaviour)', () {
    // These prove only which mode this code requests from its own
    // factory boundary, not what google_sign_in does on a device.
    for (final interactive in [false, true]) {
      test(
        'backend with interactive=$interactive requests that mode',
        () async {
          bool? requested;
          final backend = GoogleSheetsV2Backend.withClientFactory(
            interactive: interactive,
            clientFactory: ({required bool interactive}) {
              requested = interactive;
              return FakeApiClient();
            },
          );
          await backend.resolveSpreadsheetId();
          expect(requested, interactive);
        },
      );
    }

    test('silent and interactive instances are distinct modes', () {
      expect(GoogleSheetsV2Backend.instance.interactive, isFalse);
      expect(GoogleSheetsV2Backend.interactiveInstance.interactive, isTrue);
    });
  });
}
