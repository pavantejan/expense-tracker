// Sync failures shared by the Sheets backend and coordinator.
//
// The V1 A:J sync engine that used to live here was superseded by the
// V2 engine (`v2/sheets_v2_engine.dart`) in the Module 1 cutover; the
// V1 spreadsheet is never written by current code.

/// Thrown by a backend when no Google account is signed in.
///
/// The coordinator treats this differently from other failures: it
/// stays silent and leaves work pending instead of notifying or
/// retrying on a timer, because signing in is a user action.
class SheetsNotSignedInException implements Exception {
  const SheetsNotSignedInException([this.message = 'Not signed in.']);

  final String message;

  @override
  String toString() => 'SheetsNotSignedInException: $message';
}

/// Thrown when Sheets scopes have not been authorized yet and the
/// caller is in silent/background mode, where prompting for
/// authorization is forbidden. The user must authorize explicitly
/// from Settings; pending work is retained.
class SheetsAuthorizationMissingException implements Exception {
  const SheetsAuthorizationMissingException([
    this.message = 'Sheets authorization is missing.',
  ]);

  final String message;

  @override
  String toString() => 'SheetsAuthorizationMissingException: $message';
}
