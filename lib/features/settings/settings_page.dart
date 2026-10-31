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
  final GoogleAuthService _googleAuthService =
      GoogleAuthService.instance;

  bool _isLoading = false;
  bool _isDriveSettingUp = false;
  bool _isSyncing = false;

  String? get _userEmail =>
      _googleAuthService.currentUser?.email;

  // ============================================================
  // GOOGLE SIGN IN
  // ============================================================

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _googleAuthService.signIn();

      if (!mounted) {
        return;
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google account connected successfully.',
          ),
        ),
      );

      // Pending local changes can now sync in the background.
      unawaited(sheetsSyncCoordinator.requestSync());
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-in failed: $error',
          ),
        ),
      );
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

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Google account disconnected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-out failed: $error',
          ),
        ),
      );
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
        const SnackBar(
          content: Text(
            'Please sign in with Google first.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isDriveSettingUp = true;
    });

    try {
      final spreadsheetId =
          await GoogleSheetsBackend.instance.resolveSpreadsheetId();
      await GoogleSheetsBackend.instance.ensureYearSheet(
        spreadsheetId,
        DateTime.now().year,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Expense Tracker Google Sheet is ready for backup.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google Sheet setup failed: $error',
          ),
        ),
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
        const SnackBar(
          content: Text(
            'Please sign in with Google first.',
          ),
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(
                          Icons.account_circle_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Google Account',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email ?? 'Not connected',
                              style:
                                  theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: email == null
                        ? FilledButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _signInWithGoogle,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.login_rounded,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Signing in...'
                                  : 'Sign in with Google',
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _isLoading
                                ? null
                                : _signOutFromGoogle,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.logout_rounded,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Signing out...'
                                  : 'Sign out',
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      CircleAvatar(
                        child: Icon(
                          Icons.table_chart_outlined,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense Tracker Sheet',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
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
                      onPressed:
                          email == null ||
                                  _isDriveSettingUp
                              ? null
                              : _createGoogleSheet,
                      icon: _isDriveSettingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.add_chart_rounded,
                            ),
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
                      CircleAvatar(
                        child: Icon(
                          Icons.sync_rounded,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending backup',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: email == null || _isSyncing
                          ? null
                          : _retrySync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.sync_rounded,
                            ),
                      label: Text(
                        _isSyncing ? 'Syncing...' : 'Retry sync now',
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
                child: Icon(
                  Icons.info_outline_rounded,
                ),
              ),
              title: const Text(
                'Expense Tracker',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Personal expense and income tracker',
              ),
            ),
          ),
        ],
      ),
    );
  }
}