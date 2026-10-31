import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/google_auth_service.dart';
import '../../core/sync/google_sheets_backend.dart';
import '../../core/sync/sync_coordinator.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GoogleAuthService _googleAuthService = GoogleAuthService.instance;

  bool _isLoading = false;
  bool _isDriveSettingUp = false;
  bool _isSyncing = false;
  bool _isAuthorizing = false;

  /// True while the one-time startup account restoration has not
  /// settled. The signed-out UI must not be shown as final until
  /// this clears.
  bool _isRestoring = true;
  StreamSubscription<AuthRestorationState>? _restorationSubscription;

  /// `null` while unchecked (or signed out). `true` when signed
  /// in but Sheets scopes are not yet authorized — the explicit
  /// authorize action in this page is then the way forward.
  bool? _authorizationMissing;

  @override
  void initState() {
    super.initState();
    _isRestoring =
        _googleAuthService.restorationState == AuthRestorationState.checking;
    _restorationSubscription = _googleAuthService.restorationStateStream.listen(
      (state) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isRestoring = state == AuthRestorationState.checking;
        });
        if (state != AuthRestorationState.checking) {
          unawaited(_refreshAuthorizationStatus());
        }
      },
    );
    unawaited(_refreshAuthorizationStatus());
  }

  @override
  void dispose() {
    unawaited(_restorationSubscription?.cancel());
    super.dispose();
  }

  Future<void> _refreshAuthorizationStatus() async {
    if (_userEmail == null) {
      if (mounted) {
        setState(() {
          _authorizationMissing = null;
        });
      }
      return;
    }
    final hasAuthorization = await _googleAuthService.hasSyncAuthorization();
    if (!mounted) {
      return;
    }
    setState(() {
      _authorizationMissing = !hasAuthorization;
    });
  }

  /// Explicit user-initiated authorization. This is the only
  /// place in the app that may show a consent prompt for Sheets
  /// scopes. Background sync never calls this.
  Future<void> _authorizeForSync() async {
    setState(() {
      _isAuthorizing = true;
    });
    try {
      await _googleAuthService.authorizeForSync();
      await _refreshAuthorizationStatus();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Sheets backup authorized.')),
      );
      unawaited(sheetsSyncCoordinator.syncNow());
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Authorization was not completed. Transactions stay saved locally.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAuthorizing = false;
        });
      }
    }
  }

  String? get _userEmail => _googleAuthService.currentUser?.email;

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  /// Explicit sign-in, from this button tap only.
  ///
  /// The previously authenticated account is normally restored
  /// automatically once at app startup. Tapping this button
  /// first tries an explicit restore of the previous session
  /// (which may itself show an account sheet — that is allowed
  /// here because the user tapped), then falls back to
  /// interactive sign-in when no session was restored.
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _googleAuthService.restoreSession();
      if (_googleAuthService.currentUser == null) {
        await _googleAuthService.signIn();
      }

      if (!mounted) {
        return;
      }

      setState(() {});

      await _refreshAuthorizationStatus();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account connected successfully.')),
      );

      // Pending local changes can now sync in the background.
      // This is silent: if Sheets authorization is missing, no
      // consent prompt appears here — the authorize button in
      // the Sync section below is the explicit action.
      unawaited(sheetsSyncCoordinator.requestSync());
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE SIGN OUT
  // ============================================================

  Future<void> _signOutFromGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _googleAuthService.signOut();

      if (!mounted) {
        return;
      }

      setState(() {
        _authorizationMissing = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google account disconnected.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-out failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE SHEETS — ONE MASTER SPREADSHEET
  //
  // Resolves (or creates, only if missing) the single
  // "Expense Tracker" folder + spreadsheet, and ensures the
  // current-year worksheet exists. It never creates a second
  // spreadsheet, never deletes anything, and never touches
  // local transactions.
  // ============================================================

  Future<void> _createGoogleSheet() async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in with Google first.')),
      );

      return;
    }

    setState(() {
      _isDriveSettingUp = true;
    });

    try {
      final spreadsheetId = await GoogleSheetsBackend.interactiveInstance
          .resolveSpreadsheetId();
      await GoogleSheetsBackend.interactiveInstance.ensureYearSheet(
        spreadsheetId,
        DateTime.now().year,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense Tracker Google Sheet is ready for backup.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sheet setup failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDriveSettingUp = false;
        });
      }
    }
  }

  Future<void> _retrySync() async {
    if (_userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in with Google first.')),
      );
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await sheetsSyncCoordinator.syncNow();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = _userEmail;
    final isRestoring = _isRestoring;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ======================================================
          // GOOGLE ACCOUNT
          // ======================================================

          Text(
            'Google Account',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.account_circle_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Account',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRestoring
                                  ? 'Checking your Google account…'
                                  : email ?? 'Not connected',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (isRestoring) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Restoring your previous Google sign-in…',
                                style: theme.textTheme.bodySmall,
                              ),
                            ] else if (email == null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Sign in to enable Google Sheets backup. '
                                'If you signed in before, the app restores '
                                'your account automatically when it starts. '
                                'Background sync never asks for Sheets '
                                'permission on its own.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: isRestoring
                        ? FilledButton.icon(
                            onPressed: null,
                            icon: const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            label: const Text('Checking…'),
                          )
                        : email == null
                        ? FilledButton.icon(
                            onPressed: _isLoading ? null : _signInWithGoogle,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: Text(
                              _isLoading
                                  ? 'Signing in...'
                                  : 'Sign in with Google',
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _isLoading ? null : _signOutFromGoogle,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout_rounded),
                            label: Text(
                              _isLoading ? 'Signing out...' : 'Sign out',
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // GOOGLE SHEETS
          // ======================================================
          const SizedBox(height: 24),

          Text(
            'Google Sheets',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(child: Icon(Icons.table_chart_outlined)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense Tracker Sheet',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create your Google Sheet for automatic backup.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: email == null || _isDriveSettingUp
                          ? null
                          : _createGoogleSheet,
                      icon: _isDriveSettingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_chart_rounded),
                      label: Text(
                        _isDriveSettingUp
                            ? 'Creating Sheet...'
                            : 'Create Expense Tracker Sheet',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // SYNC
          // ======================================================
          const SizedBox(height: 24),

          Text(
            'Sync',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(child: Icon(Icons.sync_rounded)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending backup',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Transactions are always saved locally first. Retry sends pending changes to Google Sheets.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_authorizationMissing == true)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Google Sheets backup is not authorized yet. Authorize it here — background sync never asks for permission on its own.',
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: email == null || _isSyncing || _isAuthorizing
                          ? null
                          : (_authorizationMissing == true
                                ? _authorizeForSync
                                : _retrySync),
                      icon: _isSyncing || _isAuthorizing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _isAuthorizing
                            ? 'Authorizing...'
                            : _isSyncing
                            ? 'Syncing...'
                            : _authorizationMissing == true
                            ? 'Authorize Google Sheets'
                            : 'Retry sync now',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // APP
          // ======================================================
          const SizedBox(height: 24),

          Text(
            'App',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.info_outline_rounded),
              ),
              title: const Text(
                'Expense Tracker',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Personal expense and income tracker'),
            ),
          ),
        ],
      ),
    );
  }
}
