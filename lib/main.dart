import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/auth/google_auth_service.dart';
import 'core/notifications/notification_manager.dart';
import 'core/sync/sync_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationManager.instance.initialize();

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
      () => unawaited(sheetsSyncCoordinator.requestBackgroundSync()),
    ),
  );

  runApp(const ExpenseTrackerApp());
}
