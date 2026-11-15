import 'package:flutter/material.dart';

import '../../core/notifications/notification_manager.dart';
import '../../data/notifications/notification.dart';

/// Badge button that opens the in-app notification list.
class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationManager.instance,
      builder: (context, child) {
        final unreadCount = NotificationManager.instance.unreadCount;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () => showNotificationsPopup(context),
              icon: const Icon(Icons.notifications_none_rounded),
              tooltip: 'Notifications',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

void showNotificationsPopup(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _NotificationPopup();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _NotificationPopup extends StatelessWidget {
  const _NotificationPopup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 56, right: 12, left: 24),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(24),
            color: theme.colorScheme.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 520),
              child: AnimatedBuilder(
                animation: NotificationManager.instance,
                builder: (context, child) {
                  final notifications =
                      NotificationManager.instance.notifications;

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Notifications',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (notifications.any(
                              (notification) => !notification.isRead,
                            ))
                              TextButton(
                                onPressed: () {
                                  NotificationManager.instance.markAllAsRead();
                                },
                                child: const Text('Mark all read'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (notifications.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 48,
                                ),
                                SizedBox(height: 12),
                                Text('No notifications'),
                              ],
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: notifications.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final notification = notifications[index];

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    child: Icon(
                                      _notificationIcon(notification.type),
                                    ),
                                  ),
                                  title: Text(
                                    notification.title,
                                    style: TextStyle(
                                      fontWeight: notification.isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(notification.message),
                                  trailing: notification.isRead
                                      ? null
                                      : Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                  onTap: () {
                                    NotificationManager.instance.markAsRead(
                                      notification.id,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.transactionAdded:
        return Icons.add_rounded;
      case NotificationType.transactionUpdated:
        return Icons.edit_rounded;
      case NotificationType.transactionDeleted:
        return Icons.delete_outline_rounded;
      case NotificationType.transactionRestored:
        return Icons.restore_rounded;
      case NotificationType.syncCompleted:
        return Icons.cloud_done_outlined;
      case NotificationType.syncFailed:
        return Icons.cloud_off_outlined;
    }
  }
}
