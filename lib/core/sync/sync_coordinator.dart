import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/database/repository_provider.dart';
import '../../data/notifications/notification.dart';
import '../notifications/notification_manager.dart';
import 'google_sheets_backend.dart';
import 'sheets_sync.dart';

/// Source of pending work and the place synced state is recorded.
///
/// Kept separate from Drift so the coordinator can be tested with a
/// fake store and no database.
abstract class SyncTransactionStore {
  Future<List<SyncTransaction>> getPending();
  Future<void> markSynced(int localId);
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
  Future<void> markSynced(int localId) {
    return transactionRepository.markTransactionSynced(localId);
  }
}

/// Coordinates Sheets synchronization without ever blocking local
/// saving.
///
/// - Local writes save first; sync is always fire-and-forget from UI.
/// - Only one sync run executes at a time; concurrent triggers join
///   the running run instead of duplicating work.
/// - A failure leaves every affected transaction pending and
///   schedules a bounded retry with exponential backoff. Retries
///   stop after [_retryDelays] is exhausted, until the next explicit
///   trigger (save, sign-in, manual retry, or app start).
/// - "Not signed in" is silent: no notification, no retry timer.
///   Signing in and retrying is a user action.
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
  Future<void>? _currentRun;
  int _consecutiveFailures = 0;
  bool _failureNotified = false;
  Timer? _retryTimer;

  /// Fire-and-forget trigger used after local saves, sign-in, and
  /// app start. Never throws to the caller.
  Future<void> requestSync() {
    if (_running && _currentRun != null) {
      return _currentRun!;
    }
    _currentRun = _run(notifyOnFailure: true);
    return _currentRun!;
  }

  /// Silent background trigger used on app start. A missing sign-in
  /// is expected here and must not notify or schedule retries.
  Future<void> requestBackgroundSync() {
    if (_running && _currentRun != null) {
      return _currentRun!;
    }
    _currentRun = _run(notifyOnFailure: false);
    return _currentRun!;
  }

  /// Manual retry from Settings. Resets the backoff chain and runs
  /// immediately.
  Future<void> syncNow() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _consecutiveFailures = 0;
    _failureNotified = false;
    return requestSync();
  }

  Future<void> _run({required bool notifyOnFailure}) async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      final pending = await _store.getPending();
      if (pending.isEmpty) {
        _consecutiveFailures = 0;
        _failureNotified = false;
        return;
      }

      final result = await _engine.syncAll(
        pending: pending,
        backend: _backend,
        onSynced: (transaction) => _store.markSynced(transaction.localId),
      );

      if (result.failedUuids.isEmpty) {
        _consecutiveFailures = 0;
        if (result.syncedUuids.isNotEmpty) {
          _failureNotified = false;
          _notify(
            type: NotificationType.syncCompleted,
            title: 'Google Sheets backup complete',
            message: 'Pending transactions were backed up.',
          );
        }
      } else {
        _handleFailure(notifyOnFailure: notifyOnFailure);
      }
    } on SheetsNotSignedInException {
      // Silent: local data is safe, work stays pending, and the
      // user can sign in and retry from Settings.
      debugPrint('Sheets sync: not signed in, leaving work pending');
    } catch (_) {
      // No error details are logged: API errors can embed request
      // data, and sync failures must never leak transaction data.
      _handleFailure(notifyOnFailure: notifyOnFailure);
    } finally {
      _running = false;
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
