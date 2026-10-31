import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../sync/sheets_sync.dart';

/// Google authentication for Sheets backup.
///
/// Two modes, kept strictly separate, by construction: the
/// background code path never reaches the methods that can show
/// UI.
///
/// - **Background / in-memory-only** (`allowInteractiveAuthorization:
///   false`, the default): reads only the in-memory signed-in
///   account (`_currentUser`), set during this app session by an
///   explicit Settings sign-in or by `authenticationEvents`.
///   It never calls `initialize()`, `attemptLightweightAuthentication()`,
///   `authenticate()`, or `authorizeScopes()`. If there is no
///   in-memory account it throws [SheetsNotSignedInException];
///   if the scopes are not already authorized it inspects that
///   with `authorizationForScopes` only and throws
///   [SheetsAuthorizationMissingException]. Pending work is
///   retained in both cases. This is the mode used by background
///   sync, including app startup (`main.dart`).
/// - **Interactive / user-initiated** (`allowInteractiveAuthorization:
///   true`, only from an explicit Settings action): may call
///   `attemptLightweightAuthentication()` (via [restoreSession]),
///   `authenticate()`, and `authorizeScopes`.
///
/// `attemptLightweightAuthentication()` is NOT guaranteed to be
/// silent: the google_sign_in 7.x migration guide states it "is
/// no longer guaranteed to be silent. For example, as of the
/// publishing of 7.0, on web this may show a floating sign-in
/// card, and on Android it may show an account selection sheet."
/// It is also "no longer guaranteed to return a future": on
/// platforms where it returns no `Future`, the result arrives
/// through the `authenticationEvents` stream instead. That is
/// why [restoreSession] is Settings-only and handles both a
/// nullable returned `Future` and the stream, and why no
/// comment or document in this PR may claim lightweight
/// authentication is guaranteed silent.
///
/// `authorizationForScopes` is the silent inspection method: it
/// returns an access token if the requested scopes are already
/// authorized, or null if not. `authorizeScopes` "is expected to
/// show UI" and, on platforms where
/// `authorizationRequiresUserInteraction()` returns true, "must
/// be initiated from a user interaction like a button press"
/// (pub.dev, google_sign_in 7.2.0). It is therefore called only
/// from the explicit Settings authorize action.
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
/// This file was written against google_sign_in 7.2.0 as
/// described in the pub.dev page and migration guide. Compile/
/// analyze could not be run in the implementation environment;
/// the reviewer must verify these calls with `flutter analyze`
/// on a Flutter machine, including the nullable-Future handling
/// in [restoreSession].
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
      await _googleSignIn.initialize(serverClientId: webClientId);
      _initialized = true;

      // Retain the subscription for the app's lifetime: it is the
      // source of later session changes, and it completes a
      // pending explicit restore when lightweight authentication
      // reports through the stream instead of through its Future.
      // The subscription is kept even though background sync never
      // initiates authentication: it only observes events from
      // the active app session.
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

  /// Restores a previous session after an explicit user action in
  /// Settings. SETTINGS-ONLY: never call this from background
  /// sync, app startup, or any other non-interactive path.
  ///
  /// `attemptLightweightAuthentication()` may show UI (see the
  /// class documentation) and may not return a `Future`. When it
  /// returns a `Future`, the returned account is used when
  /// present; when it returns no `Future`, or the `Future`
  /// resolves to null, this waits (bounded to 2 seconds) for the
  /// `authenticationEvents` stream, which may still deliver the
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
      // Nullable Future: some platforms return no Future at all,
      // in which case the result arrives via the stream below.
      final Future<GoogleSignInAccount?>? lightweightFuture = _googleSignIn
          .attemptLightweightAuthentication();
      if (lightweightFuture != null) {
        account = await lightweightFuture;
      }
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
      account = await completer.future.timeout(const Duration(seconds: 2));
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

  /// Explicit, user-initiated sign-in. Call only from a Settings
  /// button tap. On platforms where `supportsAuthenticate`
  /// returns false (web), interactive sign-in needs the
  /// platform-provided sign-in button instead; this Android app
  /// does not implement that path.
  Future<GoogleSignInAccount?> signIn() async {
    await initialize();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const SheetsNotSignedInException(
        'Interactive sign-in is not supported on this platform.',
      );
    }

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

  /// Interactive sign-in path, Settings-only: initialize, then
  /// explicit restore, then interactive sign-in when needed.
  /// Background code must never call this.
  Future<GoogleSignInAccount> _ensureSignedInUserInteractive() async {
    await initialize();

    if (_currentUser == null) {
      await restoreSession();
    }

    var user = _currentUser;

    user ??= await signIn();

    if (user == null) {
      throw const SheetsNotSignedInException();
    }

    return user;
  }

  /// Background path: inspect existing authorization for the
  /// in-memory signed-in account only. Makes no authentication
  /// or authorization UI call and never initiates a session:
  /// it calls `authorizationForScopes` and nothing else. Throws
  /// [SheetsNotSignedInException] when there is no in-memory
  /// account and [SheetsAuthorizationMissingException] when the
  /// scopes are not already authorized.
  Future<GoogleSignInClientAuthorization> _backgroundAuthorization(
    GoogleSignInAccount user,
  ) async {
    GoogleSignInClientAuthorization? existing;
    try {
      existing = await user.authorizationClient.authorizationForScopes(
        syncScopes,
      );
    } catch (_) {
      existing = null;
    }
    if (existing == null) {
      throw const SheetsAuthorizationMissingException();
    }
    return existing;
  }

  /// Interactive path, Settings-only: inspect existing
  /// authorization, falling back to `authorizeScopes` (a user
  /// consent prompt) when authorization is absent. Cancellation
  /// or revocation throws to the caller.
  Future<GoogleSignInClientAuthorization> _interactiveAuthorization(
    GoogleSignInAccount user,
  ) async {
    GoogleSignInClientAuthorization? existing;
    try {
      existing = await user.authorizationClient.authorizationForScopes(
        syncScopes,
      );
    } catch (_) {
      existing = null;
    }
    if (existing != null) {
      return existing;
    }
    return user.authorizationClient.authorizeScopes(syncScopes);
  }

  /// Inspect existing authorization only, for the in-memory
  /// session. Returns `true` when the sync scopes are already
  /// authorized for the signed-in user, `false` otherwise.
  /// Never restores, signs in, or prompts: after an app restart
  /// it returns `false` until the user reconnects from
  /// Settings, which is the intended behaviour. Used by
  /// Settings to decide whether to show the explicit authorize
  /// action.
  Future<bool> hasSyncAuthorization() async {
    final user = _currentUser;
    if (user == null) {
      return false;
    }
    try {
      final existing = await user.authorizationClient.authorizationForScopes(
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
    final user = await _ensureSignedInUserInteractive();
    await _interactiveAuthorization(user);
  }

  Future<drive.DriveApi> getDriveApi({
    bool allowInteractiveAuthorization = false,
  }) async {
    final authorization = allowInteractiveAuthorization
        ? await _interactiveAuthorization(
            await _ensureSignedInUserInteractive(),
          )
        : await _backgroundAuthorization(
            _currentUser ?? (throw const SheetsNotSignedInException()),
          );
    final authenticatedClient = authorization.authClient(scopes: syncScopes);
    return drive.DriveApi(authenticatedClient);
  }

  Future<sheets.SheetsApi> getSheetsApi({
    bool allowInteractiveAuthorization = false,
  }) async {
    final authorization = allowInteractiveAuthorization
        ? await _interactiveAuthorization(
            await _ensureSignedInUserInteractive(),
          )
        : await _backgroundAuthorization(
            _currentUser ?? (throw const SheetsNotSignedInException()),
          );
    final authenticatedClient = authorization.authClient(scopes: syncScopes);
    return sheets.SheetsApi(authenticatedClient);
  }
}
