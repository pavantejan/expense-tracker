import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class GoogleAuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  static const String webClientId =
      '941418472008-lr9c35esffflkr38qh43u0s979uufquc.apps.googleusercontent.com';

  static const List<String> driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _initialized = false;
  GoogleSignInAccount? _currentUser;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _googleSignIn.initialize(
      serverClientId: webClientId,
    );

    _initialized = true;
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

  Future<drive.DriveApi> getDriveApi() async {
    await initialize();

    final user = _currentUser;

    if (user == null) {
      throw StateError(
        'Google account is not signed in.',
      );
    }

    final authorization = await user.authorizationClient.authorizeScopes(
      driveScopes,
    );

    final authenticatedClient = authorization.authClient(
      scopes: driveScopes,
    );

    return drive.DriveApi(authenticatedClient);
  }
}