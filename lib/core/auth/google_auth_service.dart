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
///   account (`_currentUser`). That account is populated once at
///   app startup by [restoreOnStartup] (called from `main.dart`)
///   and afterwards by the retained `authenticationEvents`
///   subscription and explicit Settings actions. The background
///   path itself never calls `initialize()`,
///   `attemptLightweightAuthentication()`, `authenticate()`, or
///   `authorizeScopes()`. If there is no in-memory account it
///   throws [SheetsNotSignedInException]; if the scopes are not
///   already authorized it inspects that with
///   `authorizationForScopes` only and throws
///   [SheetsAuthorizationMissingException]. Pending work is
///   retained in both cases.
/// - **Interactive / user-initiated** (`allowInteractiveAuthorization:
///   true`, only from an explicit Settings action): may call
///   `authenticate()` and `authorizeScopes`. Account restoration
///   ([restoreSession]/[restoreOnStartup]) is shared with the
///   startup path and is the only other place that calls
///   `attemptLightweightAuthentication()`.
///
/// `attemptLightweightAuthentication()` is NOT guaranteed to be
/// silent: the google_sign_in 7.x migration guide states it "is
/// no longer guaranteed to be silent. For example, as of the
/// publishing of 7.0, on web this may show a floating sign-in
/// card, and on Android it may show an account selection sheet."
/// It is also "no longer guaranteed to return a future": on
/// platforms where it returns no `Future`, the result arrives
/// through the `authenticationEvents` stream instead. That is
/// why restoration handles both a nullable returned `Future`
/// and the stream, and why no comment or document in this PR
/// may claim lightweight authentication is guaranteed silent.
/// Startup restoration may therefore show minimal
/// platform-controlled UI on Android; it never calls
/// `authenticate()` or `authorizeScopes()`, never shows an
/// account picker or consent prompt of its own, and never
/// loops: it runs once at startup, shared and idempotent.
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
/// no service-account credentials are embedded anywhere in the app,
/// and no access or refresh token is ever stored manually: the
/// plugin owns the session.
///
/// This file was written against google_sign_in 7.2.0 as
/// described in the pub.dev page and migration guide.
/// State of the one-time startup account restoration.
///
/// - [checking]: restoration has not settled yet. Callers must
///   not show the signed-out UI as final while in this state.
/// - [signedIn]: a signed-in account is held in memory.
/// - [signedOut]: restoration settled with no account, or the
///   user signed out / the session ended afterwards.
enum AuthRestorationState { checking, signedIn, signedOut }

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

  AuthRestorationState _restorationState = AuthRestorationState.checking;
  final StreamController<AuthRestorationState> _restorationController =
      StreamController<AuthRestorationState>.broadcast();

  /// Current restoration state. Starts as [AuthRestorationState.checking]
  /// and settles once the startup restoration completes, or when the
  /// session changes afterwards.
  AuthRestorationState get restorationState => _restorationState;

  /// Broadcast stream of restoration-state changes. Listeners (for
  /// example Settings) rebuild when restoration settles or the
  /// session changes. The current state is available synchronously
  /// from [restorationState], so a new listener never misses it.
  Stream<AuthRestorationState> get restorationStateStream =>
      _restorationController.stream;

  void _setRestorationState(AuthRestorationState state) {
    if (_restorationState == state || _restorationController.isClosed) {
      return;
    }
    _restorationState = state;
    _restorationController.add(state);
  }

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
    _setRestorationState(
      user != null
          ? AuthRestorationState.signedIn
          : AuthRestorationState.signedOut,
    );

    final completer = _restoreCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(user);
    }
  }

  /// Restores the previously authenticated account once, during
  /// app startup. Called exactly once from `main.dart`; safe to
  /// call again (concurrent callers share one restoration, and
  /// initialization is idempotent).
  ///
  /// Only calls `attemptLightweightAuthentication()` — never
  /// `authenticate()` or `authorizeScopes()`, and never stores
  /// tokens manually. It may show minimal platform-controlled
  /// UI on Android and is not claimed to be silent. Sheets
  /// authorization stays separate: a restored account without
  /// Sheets authorization still shows the explicit "Authorize
  /// Google Sheets" action in Settings, never another sign-in
  /// prompt.
  ///
  /// Startup failure fallback: if initialization or
  /// restoration throws, the error is swallowed here so the
  /// unawaited startup future in `main.dart` never produces
  /// an unhandled asynchronous error. Restoration state has
  /// already settled to `signedOut` (see [_doRestore]), local
  /// transactions and pending sync records are untouched, and
  /// the user can still sign in from Settings; a later
  /// Settings attempt re-runs initialization and restoration.
  /// [restoreSession] does NOT swallow errors: a
  /// Settings-initiated restoration reports them to its UI.
  Future<void> restoreOnStartup() async {
    try {
      await restoreSession();
    } catch (_) {
      // Best-effort startup restoration; see above.
    }
  }

  /// Restores a previous session: from app startup via
  /// [restoreOnStartup], or after an explicit user action in
  /// Settings. Both paths share one restoration, so a Settings
  /// tap while startup restoration is in flight waits for the
  /// same attempt instead of starting a second one.
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
  /// one restoration. Errors from initialization or restoration
  /// propagate to the caller (Settings reports them in its UI);
  /// the startup path swallows them instead, see
  /// [restoreOnStartup].
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
    // Initialization is inside the try/finally on purpose: if
    // GoogleSignIn initialization throws, restoration state
    // must still settle to `signedIn` or `signedOut` instead of
    // staying `checking` forever, and no local data is touched.
    // The error itself propagates to the caller (swallowed only
    // by the startup path, see [restoreOnStartup]).
    try {
      await initialize();
      await _doRestoreAttempt();
    } finally {
      _setRestorationState(
        _currentUser != null
            ? AuthRestorationState.signedIn
            : AuthRestorationState.signedOut,
      );
    }
  }

  Future<void> _doRestoreAttempt() async {
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
    _setRestorationState(AuthRestorationState.signedIn);

    return user;
  }

  Future<void> signOut() async {
    await initialize();

    await _googleSignIn.signOut();

    _currentUser = null;
    // Local transactions and pending sync records are untouched:
    // only the in-memory session is cleared. The next startup
    // restoration may restore the account again unless access
    // was revoked; the signed-out UI is shown until then.
    _setRestorationState(AuthRestorationState.signedOut);
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
  /// Never restores, signs in, or prompts: before startup
  /// restoration settles it returns `false`, and after an app
  /// restart it returns `false` until restoration completes or
  /// the user reconnects from Settings. Used by Settings to
  /// decide whether to show the explicit authorize action.
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
