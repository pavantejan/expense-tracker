import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/v2/app_database_v2.dart';
import '../../data/notifications/notification.dart';

class NotificationManager extends ChangeNotifier {
  NotificationManager._();

  static final NotificationManager instance = NotificationManager._();

  final _uuid = const Uuid();

  final List<AppNotification> _notifications = [];

  Future<void>? _initializationFuture;

  /// Persistence target, set by [initialize]. Until then (and in
  /// widget tests that never initialize it) notifications are kept
  /// in memory only.
  AppDatabaseV2? _database;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  Future<void> initialize(AppDatabaseV2 database) {
    _database = database;
    return _initializationFuture ??= _loadNotifications(database);
  }

  Future<void> _loadNotifications(AppDatabaseV2 appDatabase) async {
    final savedNotifications =
        await (appDatabase.select(appDatabase.notifications)..orderBy([
              (notification) => OrderingTerm(
                expression: notification.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
            .get();

    _notifications
      ..clear()
      ..addAll(
        savedNotifications.map(
          (notification) => AppNotification(
            id: notification.id,
            type: _notificationTypeFromString(notification.type),
            title: notification.title,
            message: notification.message,
            createdAt: notification.createdAt,
            isRead: notification.isRead,
          ),
        ),
      );

    notifyListeners();
  }

  void add({
    required NotificationType type,
    required String title,
    required String message,
  }) {
    final notification = AppNotification(
      id: _uuid.v4(),
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, notification);
    notifyListeners();

    final appDatabase = _database;
    if (appDatabase == null) {
      return;
    }
    unawaited(
      appDatabase
          .into(appDatabase.notifications)
          .insert(
            NotificationsCompanion.insert(
              id: notification.id,
              type: notification.type.name,
              title: notification.title,
              message: notification.message,
              createdAt: notification.createdAt,
            ),
          ),
    );
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere(
      (notification) => notification.id == id,
    );

    if (index == -1 || _notifications[index].isRead) {
      return;
    }

    _notifications[index] = _notifications[index].copyWith(isRead: true);

    notifyListeners();

    final appDatabase = _database;
    if (appDatabase == null) {
      return;
    }
    unawaited(
      (appDatabase.update(appDatabase.notifications)
            ..where((notification) => notification.id.equals(id)))
          .write(const NotificationsCompanion(isRead: Value(true))),
    );
  }

  void markAllAsRead() {
    var changed = false;

    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }

    if (!changed) {
      return;
    }

    notifyListeners();

    final appDatabase = _database;
    if (appDatabase == null) {
      return;
    }
    unawaited(
      (appDatabase.update(appDatabase.notifications)
            ..where((notification) => notification.isRead.equals(false)))
          .write(const NotificationsCompanion(isRead: Value(true))),
    );
  }

  void clearAll() {
    if (_notifications.isEmpty) {
      return;
    }

    _notifications.clear();
    notifyListeners();

    final appDatabase = _database;
    if (appDatabase == null) {
      return;
    }
    unawaited(appDatabase.delete(appDatabase.notifications).go());
  }

  NotificationType _notificationTypeFromString(String value) {
    for (final type in NotificationType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return NotificationType.transactionAdded;
  }
}
