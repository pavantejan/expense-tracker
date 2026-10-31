import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/repository_provider.dart';
import '../../data/notifications/notification.dart';
import '../notifications/notification_manager.dart';
import 'google_sheets_backend.dart';
import 'sheets_sync.dart';

/// Source of pending work and the place synced state is recorded.
///
/// Kept separate from Drift so the coordinator can be tested with a
/// fake store and no database. [markSynced] is conditional: it
/// returns `true` only when the local row is still the revision
/// that was uploaded (see `markTransactionSyncedIfUnchanged`).
abstract class SyncTransactionStore {
  Future<List<SyncTransaction>> getPending();
  Future<bool> markSynced(SyncTransaction transaction);
}

/// Production store backed by the Drift transaction repository.
class DriftSyncTransactionStore implements SyncTransactionStore {
  @override
  Future<List<SyncTransaction>> getPending() async {
    final rows = await transactionRepository.getPendingTransactions();
    return rows
        .map(
          (row) => SyncTransaction(
            localId: row.id,
            uuid: row.uuid,
            transactionDate: row.transactionDate,
            type: row.type,
            category: row.category,
            description: row.description ?? '',
            amount: row.amount,
            paymentMethod: row.paymentMethod,
            notes: row.notes,
            updatedAt: row.updatedAt,
            deleted: row.deleted,
          ),
        )
        .toList();
  }

  @override
  Future<bool> markSynced(SyncTransaction transaction) {
    return transactionRepository.markTransactionSyncedIfUnchanged(
      id: transaction.localId,
      updatedAt: transaction.updatedAt,
      deleted: transaction.deleted,
    );
  }
}

/// Coordinates Sheets synchronization without ever blocking local
/// saving.
///
/// - Local writes save first; sync is always fire-and-forget from UI.
/// - Only one sync run executes at a time. A trigger received while
///   a run is active sets [_rerunRequested]; the run drains its
///   queue by re-reading pending work until no trigger arrived
///   during the last batch, so no trigger is lost. A trigger that
///   arrives in the tiny window where a run is finishing starts a
///   follow-up run from the `finally` block.
/// - A failure leaves every affected transaction pending and
///   schedules a bounded retry with exponential backoff. Retries
///   stop after [_retryDelays] is exhausted, until the next explicit
///   trigger (save, sign-in, manual retry, or app start).
/// - "Not signed in" and "authorization missing" are silent in
///   background sync: no retry timer. The latter also sets
///   [authorizationMissing] so Settings can present the explicit
///   authorize action. Signing in / authorizing is a user action.
/// - Exactly one sync notification per run, never per row or per
///   retry attempt.
class SheetsSyncCoordinator {
  SheetsSyncCoordinator({
    required SheetsSyncBackend backend,
    required SyncTransactionStore store,
    SheetsSyncEngine? engine,
    void Function({
      required NotificationType type,
      required String title,
      required String message,
    })? onNotification,
  })  : _backend = backend,
        _store = store,
        _engine = engine ?? SheetsSyncEngine(),
        _onNotification = onNotification;

  final SheetsSyncBackend _backend;
  final SyncTransactionStore _store;
  final SheetsSyncEngine _engine;
  final void Function({
    required NotificationType type,
    required String title,
    required String message,
  })? _onNotification;

  void _notify({
    required NotificationType type,
    required String title,
    required String message,
  }) {
    final handler = _onNotification;
    if (handler != null) {
      handler(type: type, title: title, message: message);
      return;
    }
    NotificationManager.instance.add(
      type: type,
      title: title,
      message: message,
    );
  }

  static const List<Duration> _retryDelays = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
  ];

  bool _running = false;
  bool _rerunRequested = false;
  bool _rerunNotify = false;
  Future<void>? _currentRun;
  int _consecutiveFailures = 0;
  bool _failureNotified = false;
  Timer? _retryTimer;

  /// True when the last sync attempt found that Sheets scopes have
  /// not been authorized. Settings reads this (via its own
  /// in-memory-only check) to show the authorize action. Cleared
  /// on a successful sync or when authorization is granted.
  bool authorizationMissing = false;

  /// Fire-and-forget trigger used after local saves and sign-in.
  /// Never throws to the caller. If a run is active, this records
  /// a rerun request and returns the running run's future; the
  /// rerun drain (see [_runLoop]) picks up work added after the
  /// active batch was read.
  Future<void> requestSync() {
    if (_running) {
      _rerunRequested = true;
      _rerunNotify = true;
      return _currentRun!;
    }
    _currentRun = _runLoop(notifyOnFailure: true);
    return _currentRun!;
  }

  /// Silent background trigger used on app start. A missing sign-in
  /// or authorization is expected here and must not notify or
  /// schedule retries.
  Future<void> requestBackgroundSync() {
    if (_running) {
      _rerunRequested = true;
      return _currentRun!;
    }
    _currentRun = _runLoop(notifyOnFailure: false);
    return _currentRun!;
  }

  /// Manual retry from Settings. Resets the backoff chain and runs
  /// immediately (or records a rerun if a run is active).
  Future<void> syncNow() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _consecutiveFailures = 0;
    _failureNotified = false;
    return requestSync();
  }

  Future<void> _runLoop({required bool notifyOnFailure}) async {
    if (_running) {
      return;
    }
    _running = true;
    var notify = notifyOnFailure;
    try {
      // Drain loop: each iteration re-reads pending work. The loop
      // only repeats when a trigger arrived during the batch it
      // just finished, so it terminates as soon as a batch sees
      // no new trigger. Batches that fail schedule a bounded
      // retry instead of looping immediately.
      while (true) {
        _rerunRequested = false;
        _rerunNotify = false;
        final hadFailure = await _runBatch(notifyOnFailure: notify);
        if (!_rerunRequested || hadFailure) {
          break;
        }
        notify = notify || _rerunNotify;
      }
    } finally {
      _running = false;
      // A trigger that arrived after the last drain check but
      // before _running was cleared must not be lost.
      if (_rerunRequested) {
        _rerunRequested = false;
        final followUp = _runLoop(notifyOnFailure: _rerunNotify);
        _currentRun = followUp;
        unawaited(followUp);
      }
    }
  }

  /// One batch: read pending once, sync it, handle the outcome.
  /// Returns `true` when a retry was scheduled for a failure.
  Future<bool> _runBatch({required bool notifyOnFailure}) async {
    try {
      final pending = await _store.getPending();
      if (pending.isEmpty) {
        _consecutiveFailures = 0;
        _failureNotified = false;
        return false;
      }

      final result = await _engine.syncAll(
        pending: pending,
        backend: _backend,
        onSynced: (transaction) => _store.markSynced(transaction),
      );

      if (result.failedUuids.isEmpty) {
        authorizationMissing = false;
        _consecutiveFailures = 0;
        if (result.syncedUuids.isNotEmpty) {
          _failureNotified = false;
          _notify(
            type: NotificationType.syncCompleted,
            title: 'Google Sheets backup complete',
            message: 'Pending transactions were backed up.',
          );
        }
        return false;
      }

      _handleFailure(notifyOnFailure: notifyOnFailure);
      return true;
    } on SheetsNotSignedInException {
      // Silent: local data is safe, work stays pending, and the
      // user can sign in and retry from Settings.
      debugPrint('Sheets sync: not signed in, leaving work pending');
      return false;
    } on SheetsAuthorizationMissingException {
      authorizationMissing = true;
      if (notifyOnFailure && !_failureNotified) {
        _failureNotified = true;
        _notify(
          type: NotificationType.syncFailed,
          title: 'Google Sheets authorization needed',
          message:
              'Open Settings to authorize Google Sheets backup. Transactions are saved locally.',
        );
      }
      return false;
    } catch (_) {
      // No error details are logged: API errors can embed request
      // data, and sync failures must never leak transaction data.
      _handleFailure(notifyOnFailure: notifyOnFailure);
      return true;
    }
  }

  void _handleFailure({required bool notifyOnFailure}) {
    _consecutiveFailures++;
    if (notifyOnFailure && !_failureNotified) {
      _failureNotified = true;
      _notify(
        type: NotificationType.syncFailed,
        title: 'Google Sheets backup failed',
        message: 'Transactions are saved locally and will retry.',
      );
    }
    if (_consecutiveFailures <= _retryDelays.length) {
      final delay = _retryDelays[_consecutiveFailures - 1];
      _retryTimer?.cancel();
      _retryTimer = Timer(delay, () {
        unawaited(requestSync());
      });
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// App-wide coordinator, created lazily with the real backend/store.
final SheetsSyncCoordinator sheetsSyncCoordinator = SheetsSyncCoordinator(
  backend: GoogleSheetsBackend.instance,
  store: DriftSyncTransactionStore(),
);
