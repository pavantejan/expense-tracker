import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../data/notifications/notification.dart';
import '../database/database_provider.dart';

class NotificationManager extends ChangeNotifier {
  NotificationManager._();

  static final NotificationManager instance = NotificationManager._();

  final _uuid = const Uuid();

  final List<AppNotification> _notifications = [];

  Future<void>? _initializationFuture;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  Future<void> initialize() {
    return _initializationFuture ??= _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final savedNotifications =
        await (appDatabase.select(appDatabase.notifications)
              ..orderBy([
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
            type: _notificationTypeFromString(
              notification.type,
            ),
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

    unawaited(
      appDatabase.into(appDatabase.notifications).insert(
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

    _notifications[index] = _notifications[index].copyWith(
      isRead: true,
    );

    notifyListeners();

    unawaited(
      (appDatabase.update(appDatabase.notifications)
            ..where((notification) => notification.id.equals(id)))
          .write(
        const NotificationsCompanion(
          isRead: Value(true),
        ),
      ),
    );
  }

  void markAllAsRead() {
    var changed = false;

    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(
          isRead: true,
        );
        changed = true;
      }
    }

    if (!changed) {
      return;
    }

    notifyListeners();

    unawaited(
      (appDatabase.update(appDatabase.notifications)
            ..where((notification) => notification.isRead.equals(false)))
          .write(
        const NotificationsCompanion(
          isRead: Value(true),
        ),
      ),
    );
  }

  void clearAll() {
    if (_notifications.isEmpty) {
      return;
    }

    _notifications.clear();
    notifyListeners();

    unawaited(
      appDatabase.delete(appDatabase.notifications).go(),
    );
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