import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/notifications/notification_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationManager.instance.initialize();

  runApp(const ExpenseTrackerApp());
}