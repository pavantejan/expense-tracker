import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import 'sheets_sync.dart';

import '../sync/sheets_sync.dart';

/// Google authentication for Sheets backup.
///
/// Scopes are requested only when a sync operation actually runs,
/// and only the two scopes the operations need:
/// - `drive.file`: find/create the "Expense Tracker" folder and
///   spreadsheet. This is the least-privilege Drive scope: it covers
///   only files the app created or the user opened with it, not the
///   whole Drive.
/// - `spreadsheets`: read/write values in that spreadsheet.
///
/// No tokens, secrets, or transaction data are logged here. The
/// web client id below is a public OAuth client id, not a secret;
/// no service-account credentials are embedded anywhere in the app.
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
  bool _listeningToAuthEvents = false;
  GoogleSignInAccount? _currentUser;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId: webClientId,
    );

    _initialized = true;

    if (!_listeningToAuthEvents) {
      _listeningToAuthEvents = true;
      _googleSignIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: (_) {},
      );
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    _currentUser = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };
  }

  /// Best-effort restoration of a previous session, without UI.
  ///
  /// Follows the google_sign_in pub.dev example pattern: after
  /// [initialize], call `attemptLightweightAuthentication()` and let
  /// the authentication-events stream report the signed-in user.
  /// Failures (never signed in, revoked, cancelled) are swallowed:
  /// callers treat "no user" as "needs interactive sign-in" and
  /// leave local data untouched.
  Future<void> restoreSession() async {
    await initialize();

    try {
      await _googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      // No previous session to restore. The user can sign in
      // interactively from Settings.
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

  Future<GoogleSignInAccount> _ensureSignedInUser() async {
    await initialize();

    if (_currentUser == null) {
      await restoreSession();
    }

    final user = _currentUser;

    if (user == null) {
      throw const SheetsNotSignedInException();
    }

    return user;
  }

  /// Authorize [scopes], silently when already granted, interactively
  /// when not. A cancellation or revocation throws to the caller,
  /// which must leave local data and pending sync state untouched.
  Future<GoogleSignInClientAuthorization> _authorize(
    GoogleSignInAccount user,
    List<String> scopes,
  ) async {
    try {
      final existing =
          await user.authorizationClient.authorizationForScopes(scopes);
      if (existing != null) {
        return existing;
      }
    } catch (_) {
      // Fall through to an interactive authorization request.
    }

    return user.authorizationClient.authorizeScopes(scopes);
  }

  Future<drive.DriveApi> getDriveApi() async {
    final user = await _ensureSignedInUser();
    final authorization = await _authorize(user, syncScopes);
    final authenticatedClient = authorization.authClient(
      scopes: syncScopes,
    );
    return drive.DriveApi(authenticatedClient);
  }

  Future<sheets.SheetsApi> getSheetsApi() async {
    final user = await _ensureSignedInUser();
    final authorization = await _authorize(user, syncScopes);
    final authenticatedClient = authorization.authClient(
      scopes: syncScopes,
    );
    return sheets.SheetsApi(authenticatedClient);
  }
}
