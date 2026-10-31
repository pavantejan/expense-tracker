import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/notification_manager.dart';
import 'core/sync/sync_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationManager.instance.initialize();

  // Best-effort background sync of any pending work from a previous
  // run. Silent when not signed in; never blocks startup and never
  // throws into app launch.
  unawaited(sheetsSyncCoordinator.requestBackgroundSync());

  runApp(const ExpenseTrackerApp());
}
