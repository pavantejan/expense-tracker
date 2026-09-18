import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../data/notifications/notification.dart';
// import 'notification.dart';
// notification_manager.dart';

class NotificationManager extends ChangeNotifier {
  NotificationManager._();

  static final NotificationManager instance = NotificationManager._();

  final _uuid = const Uuid();

  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((notification) => !notification.isRead).length;

  void add({
    required NotificationType type,
    required String title,
    required String message,
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: _uuid.v4(),
        type: type,
        title: title,
        message: message,
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();
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

    if (changed) {
      notifyListeners();
    }
  }

  void clearAll() {
    if (_notifications.isEmpty) {
      return;
    }

    _notifications.clear();
    notifyListeners();
  }
}