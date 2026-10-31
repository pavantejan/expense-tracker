import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../sync/sheets_sync.dart';

/// Google authentication for Sheets backup.
///
/// Two modes, kept strictly separate:
///
/// - **Silent / background** (`allowInteractiveAuthorization: false`,
///   the default): may only *inspect* existing authorization with
///   `authorizationForScopes`. It never calls `authorizeScopes`,
///   never calls `authenticate()`, and never shows an account
///   picker or consent prompt. If authorization is missing it
///   throws [SheetsAuthorizationMissingException]; pending work
///   is retained and Settings presents the explicit authorize
///   action. This is the mode used by background sync, including
///   app startup.
/// - **Interactive / user-initiated** (`allowInteractiveAuthorization:
///   true`, only from an explicit Settings action): may call
///   `authenticate()` when no user is signed in and
///   `authorizeScopes` when scopes are not yet granted.
///
/// Only the two scopes the operations need are ever requested:
/// - `drive.file`: find/create the "Expense Tracker" folder and
///   spreadsheet. Least-privilege Drive scope: it covers only
///   files the app created or the user opened with it, not the
///   whole Drive. See `GoogleDriveService` for what this does and
///   does not guarantee about manually created folders.
/// - `spreadsheets`: read/write values in that spreadsheet.
///
/// No tokens, secrets, or transaction data are logged here. The
/// web client id below is a public OAuth client id, not a secret;
/// no service-account credentials are embedded anywhere in the app.
///
/// This file was written against google_sign_in 7.2.0 as described
/// by the reviewer: `attemptLightweightAuthentication()` returns
/// `Future<GoogleSignInAccount?>`. Its result is used when present;
/// when it returns null, restoration waits (bounded) for the
/// `authenticationEvents` stream, which remains the source of
/// later session changes. Compile/analyze could not be run in the
/// implementation environment; the reviewer must verify these
/// calls with `flutter analyze` on a Flutter machine.
class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  static const String webClientId =
      '941418472008-lr9c35esffflkr38qh43u0s979uufquc.apps.googleusercontent.com';

  /// Kept for callers that referenced the old name. Both sync
  /// operations now use [syncScopes] together.
  static const List<String> driveScopes = syncScopes;

  static const List<String> syncScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;
  Future<void>? _initializeFuture;
  Future<void>? _restoreFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  Completer<GoogleSignInAccount?>? _restoreCompleter;
  GoogleSignInAccount? _currentUser;

  Future<void> initialize() {
    final inFlight = _initializeFuture;
    if (_initialized) {
      return Future<void>.value();
    }
    if (inFlight != null) {
      return inFlight;
    }
    _initializeFuture = _doInitialize();
    return _initializeFuture!;
  }

  Future<void> _doInitialize() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: webClientId,
      );
      _initialized = true;

      // Retain the subscription for the app's lifetime: it is the
      // source of later session changes, and it completes a
      // pending restore when lightweight authentication reports
      // through the stream instead of through its Future.
      _authSubscription ??= _googleSignIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: (_) {},
        cancelOnError: false,
      );
    } finally {
      _initializeFuture = null;
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    final user = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
    _currentUser = user;

    final completer = _restoreCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(user);
    }
  }

  /// Best-effort restoration of a previous session, without UI and
  /// without showing any picker or consent prompt.
  ///
  /// `attemptLightweightAuthentication()` returns a nullable
  /// Future: a non-null account is used directly. When it returns
  /// null, this waits (bounded to 2 seconds) for the
  /// authentication-events stream, which may still deliver the
  /// restored account. If neither delivers an account, the user
  /// is treated as signed out for this attempt only — local data
  /// and pending sync work are untouched, and the user can sign
  /// in interactively from Settings. Concurrent callers share
  /// one restoration.
  Future<void> restoreSession() {
    final inFlight = _restoreFuture;
    if (inFlight != null) {
      return inFlight;
    }
    _restoreFuture = _doRestore();
    return _restoreFuture!.whenComplete(() {
      _restoreFuture = null;
    });
  }

  Future<void> _doRestore() async {
    await initialize();

    if (_currentUser != null) {
      return;
    }

    final completer = Completer<GoogleSignInAccount?>();
    _restoreCompleter = completer;

    GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      account = null;
    }

    if (account != null) {
      _currentUser = account;
      _restoreCompleter = null;
      return;
    }

    if (_currentUser != null) {
      _restoreCompleter = null;
      return;
    }

    try {
      account = await completer.future.timeout(
        const Duration(seconds: 2),
      );
      if (account != null) {
        _currentUser = account;
      }
    } on TimeoutException {
      // No restored session arrived through the stream either.
    } finally {
      if (_restoreCompleter == completer) {
        _restoreCompleter = null;
      }
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    await initialize();

    final user = await _googleSignIn.authenticate();

    _currentUser = user;

    return user;
  }

  Future<void> signOut() async {
    await initialize();

    await _googleSignIn.signOut();

    _currentUser = null;
  }

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<GoogleSignInAccount> _ensureSignedInUser({
    required bool allowInteractiveSignIn,
  }) async {
    await initialize();

    if (_currentUser == null) {
      await restoreSession();
    }

    var user = _currentUser;

    if (user == null && allowInteractiveSignIn) {
      user = await signIn();
    }

    if (user == null) {
      throw const SheetsNotSignedInException();
    }

    return user;
  }

  /// Inspect existing authorization only. Returns `true` when the
  /// sync scopes are already authorized for the signed-in user,
  /// `false` otherwise. Never prompts. Used by Settings to decide
  /// whether to show the explicit authorize action.
  Future<bool> hasSyncAuthorization() async {
    try {
      final user = await _ensureSignedInUser(
        allowInteractiveSignIn: false,
      );
      final existing =
          await user.authorizationClient.authorizationForScopes(
        syncScopes,
      );
      return existing != null;
    } catch (_) {
      return false;
    }
  }

  /// Explicit, user-initiated authorization for Sheets sync.
  /// Call only from a Settings button tap. Signs in interactively
  /// when needed, then requests the sync scopes. Throws on
  /// cancellation so the caller can leave state untouched.
  Future<void> authorizeForSync() async {
    final user = await _ensureSignedInUser(
      allowInteractiveSignIn: true,
    );
    await _authorize(
      user,
      syncScopes,
      allowInteractiveAuthorization: true,
    );
  }

  /// Authorize [scopes].
  ///
  /// Silent mode inspects existing authorization only and throws
  /// [SheetsAuthorizationMissingException] when it is absent.
  /// Interactive mode falls back to `authorizeScopes` (a user
  /// consent prompt) when authorization is absent. Cancellation
  /// or revocation throws to the caller.
  Future<GoogleSignInClientAuthorization> _authorize(
    GoogleSignInAccount user,
    List<String> scopes, {
    required bool allowInteractiveAuthorization,
  }) async {
    GoogleSignInClientAuthorization? existing;
    try {
      existing =
          await user.authorizationClient.authorizationForScopes(scopes);
    } catch (_) {
      existing = null;
    }
    if (existing != null) {
      return existing;
    }

    if (!allowInteractiveAuthorization) {
      throw const SheetsAuthorizationMissingException();
    }

    return user.authorizationClient.authorizeScopes(scopes);
  }

  Future<drive.DriveApi> getDriveApi({
    bool allowInteractiveAuthorization = false,
  }) async {
    final user = await _ensureSignedInUser(
      allowInteractiveSignIn: allowInteractiveAuthorization,
    );
    final authorization = await _authorize(
      user,
      syncScopes,
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
    final authenticatedClient = authorization.authClient(
      scopes: syncScopes,
    );
    return drive.DriveApi(authenticatedClient);
  }

  Future<sheets.SheetsApi> getSheetsApi({
    bool allowInteractiveAuthorization = false,
  }) async {
    final user = await _ensureSignedInUser(
      allowInteractiveSignIn: allowInteractiveAuthorization,
    );
    final authorization = await _authorize(
      user,
      syncScopes,
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
    final authenticatedClient = authorization.authClient(
      scopes: syncScopes,
    );
    return sheets.SheetsApi(authenticatedClient);
  }
}
