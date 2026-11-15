import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/auth/google_auth_service.dart';
import 'core/notifications/notification_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opens the `expense_tracker_v2` database (created with its baseline
  // seed on first launch). The old `expense_tracker` database file is
  // never opened, modified, or deleted: it stays on the device as an
  // archive until an explicit, user-confirmed cleanup (Module 12).
  final services = await AppServices.open();

  await NotificationManager.instance.initialize(services.database);

  // Restore the previously authenticated Google account once, so
  // the user is not asked to sign in again after every restart.
  // This runs exactly once here; initialization and restoration
  // are idempotent and shared with Settings. It only calls
  // attemptLightweightAuthentication() — never authenticate()
  // or authorizeScopes() — and may show minimal
  // platform-controlled UI on Android; it is not claimed to be
  // silent. Background sync runs after restoration settles so it
  // can use the restored account; if no account was restored,
  // sync stays silent and pending work is retained. Sheets
  // authorization stays separate and is never requested here.
  unawaited(
    GoogleAuthService.instance.restoreOnStartup().whenComplete(
      () => unawaited(services.sync.requestBackgroundSync()),
    ),
  );

  runApp(ExpenseTrackerApp(services: services));
}
