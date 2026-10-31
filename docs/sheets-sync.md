# Google Sheets sync — working notes

Branch: `feature/fix-google-sheets-sync`, base `master` (2231948, 31 Oct 2026).
Environment note (corrected 31 Oct 2026): a Flutter/Dart
toolchain DOES exist in this environment after all — Flutter
3.47.2 / Dart 3.13.2 at `~/workspace/build-verify/flutter/`,
left over from earlier SpendMate work. Earlier claims in
this document and in the PR description that no toolchain
existed were based only on `which flutter dart` and were
wrong. The checks below were run with that toolchain on
31 Oct 2026; the "NOT run" disclosures in earlier PR
description sections are superseded by the verification
section at the end of this document. The Android SDK in the
same directory contains only cmdline-tools and is not a
valid SDK for Flutter, and no JDK is installed, so an APK
build could not run here (see below).

## Defects verified against current master code

1. **A new spreadsheet per transaction.** `GoogleSheetsService.backupExpense()`
   calls `createSpreadsheet()` + `writeHeaders()` + `appendExpense()` for
   every new transaction. The returned spreadsheet id is discarded.
2. **Settings creates a different spreadsheet.** `SettingsPage._createGoogleSheet()`
   creates a spreadsheet and only `debugPrint`s its id. `backupExpense()`
   never reuses it. The two paths are disconnected.
3. **No persistent spreadsheet/folder id.** Nothing is stored in Drift,
   in a settings table, or anywhere else. There is no in-memory cache
   either — every call re-creates. The `AppSettings` Drift table file
   exists but is not registered in `@DriftDatabase` and its table is
   dropped by the v5 migration; it cannot be used as-is.
4. **Edits/deletes/restores never sync.** Only the create path calls
   Sheets. Edit mode shows "Transaction updated locally" and never
   touches Sheets. Dashboard / All Transactions delete/restore call
   only the repository. `syncStatus` is set to `'pending'` on every
   write and never read or cleared by any sync code.
5. **No year routing.** Rows are appended to a single sheet named
   "Expenses" in a freshly created spreadsheet. Transaction date is
   formatted as a string; the sheet is not chosen by year.
6. **No identity / idempotency.** Rows have no UUID column. A retry
   would append a duplicate row. Identity by description/amount/date
   is not possible from the stored row.
7. **Local save blocks on Sheets.** `AddTransactionPage._saveTransaction`
   `await`s `backupExpense()` after the local insert, and only then
   shows "saved and backed up". A slow/failing API call delays the
   save confirmation; a throw is caught, but the user has already
   waited for the remote call.
8. **Auth is not restored.** `GoogleAuthService._currentUser` is only
   set by interactive `signIn()`. `initialize()` never restores a
   session, and `GoogleSheetsService._getSheetsApi()` never calls
   `initialize()`. After a restart, Sheets calls throw "not signed
   in" until the user signs in again in Settings.
9. **Scopes are split.** Drive operations request `drive.file`;
   Sheets operations request `spreadsheets` in a separate
   `authorizeScopes` call. Both are needed for the actual work
   (Drive: find/create folder + spreadsheet file; Sheets: read/write
   values), but they are requested from different places.
10. **Dead code verified:** `GoogleDriveService` (find-or-create folder
    + spreadsheet, correct in itself) has zero callers.
    `GoogleSignInTestPage` has zero callers / no route.
    `TransactionRepository.getBalanceBeforeMonth()` has zero callers.
    `NotificationType.syncCompleted/syncFailed` are never emitted.
    `CustomCategoryRepository.updateCategory()` has no `where` clause
    (would update all rows) — **out of scope, left untouched, noted
    only so it is not mistaken for part of this task.**

## Proposed implementation (this PR only)

## Corrections after second technical review (third commit on PR #1)

The notes below supersede the corresponding claims in the
earlier sections. The earlier commits are not rewritten;
corrections land as a follow-up commit on the same branch.

- **Background authentication must not show UI (review §1,
  supersedes the "silent authorization" / restore claims in
  the second-commit notes and the Auth bullet below; the
  Settings-only restoration rule in this bullet is itself
  superseded in part by the startup-restoration section at
  the end of this document).**
  The google_sign_in 7.x migration guide states
  `attemptLightweightAuthentication()` "is no longer
  guaranteed to be silent. For example, as of the publishing
  of 7.0, on web this may show a floating sign-in card, and on
  Android it may show an account selection sheet", and it is
  "no longer guaranteed to return a future" — on some
  platforms the result arrives only through the
  `authenticationEvents` stream. Background sync therefore
  never calls `attemptLightweightAuthentication()`,
  `authenticate()`, or `authorizeScopes()`, and never calls
  `initialize()` either: it reads only the in-memory
  signed-in account set during this app session, inspects
  existing authorization with `authorizationForScopes`
  only, and throws `SheetsNotSignedInException` /
  `SheetsAuthorizationMissingException` when there is no
  in-memory account or no existing authorization. Pending
  work stays pending. `restoreSession()` is now Settings-only
  (called from the Settings sign-in button tap and from the
  interactive authorization path), handles the nullable
  returned `Future` (no `Future` → wait bounded 2s for the
  stream), and the `authenticationEvents` subscription is
  still retained for the app lifetime to observe session
  changes in the active session. Settings offers a clear
  reconnect action after a restart: the "Sign in with Google"
  button (with explainer text that background sync never
  signs the user in on its own) first tries an explicit
  restore, then interactive sign-in. `hasSyncAuthorization()`
  no longer restores: it inspects only the in-memory session
  and returns `false` after a restart until the user
  reconnects. No comment or document in this PR claims
  lightweight authentication is guaranteed silent.
- **Worksheet discovery errors abort the run (review §2).**
  The best-effort catch around `listYearSheets` is removed.
  If listing fails, the engine throws before any remote
  write or local acknowledgement; the coordinator treats it
  as an ordinary failure and retries with its bounded
  backoff. A partial worksheet list could miss a year-moved
  row and leave two active rows for one UUID, so there is
  no fallback to pending years alone.
- **Deletion before first synchronization (review §3).**
  The engine reads existing worksheets first and only
  ensures (creates) a year worksheet when a write to it is
  about to happen. A pending deletion with no prior row
  anywhere is acknowledged locally with no worksheet and no
  remote row. A previously synchronized deletion still
  tombstones every existing row. The fake backend's
  `ensureYearSheet` now records calls and creates the year
  when called, so tests prove no worksheet was created.
- **RAW for transaction values (review §4).** Append and
  update now use `RAW` (previously `USER_ENTERED` for both).
  Text beginning with `=` is stored literally, never
  evaluated as a formula; amounts are passed as JSON
  numbers and stay numbers. Header writing already used
  `RAW` and is unchanged. The `SheetsApiClient` boundary
  now carries a typed `SheetsValueInputOption` so tests can
  record the option the production client chose.
- **Legacy five-column headers (review §5).** A worksheet
  whose first row is exactly
  `Date, Type, Category, Description, Amount` (A:E, with no
  non-empty cells beyond column E) is recognised as a legacy
  header. `ensureYearSheet` extends only that header row to
  the current A:J schema; every data row is preserved
  byte-for-byte and no UUID is invented for legacy rows.
  `readYearSheet` skips the legacy header; legacy rows
  parse with an empty UUID and are never matched, updated,
  or tombstoned by the engine (their UUID never equals a
  local transaction's UUID), so they are untouched by sync.
  Manual reconciliation: legacy rows are historical records
  with no UUID. Leave them untouched, or reconcile by hand
  in Sheets by date/amount/description (for example, delete
  a legacy row by hand if the same transaction was later
  synced as a UUID row and now appears twice). The app does
  not expose local transaction UUIDs in its UI, so typing a
  UUID into column F by hand is not a supported path, and
  no UUID must be invented for a legacy row. Do not delete
  or merge legacy rows from the app.
- **Authentication validation (review §6) — assessment.**
  `GoogleAuthService` cannot be unit-tested against the real
  plugin without the platform: `GoogleSignIn` is a singleton
  (`GoogleSignIn.instance`, no injectable constructor in
  7.x), its account/event types are produced only by the
  plugin/platform, and no mocking dependency is in
  `pubspec.yaml`. Mocking the platform interface would
  require adding `google_sign_in_platform_interface` (and a
  mocking library) to dev dependencies and implementing the
  full platform interface, and it still could not prove
  that a native call shows no UI — platform UI behaviour is
  documented in the migration guide, not observable from a
  fake. That was NOT done here: adding unverifiable
  dependencies and a large mock surface in an environment
  where `flutter analyze`/`flutter test` cannot run would
  risk breaking the real path for no verified gain. What is
  tested instead: (a) the `SheetsApiClient` factory routing
  — which authorization mode the backend requests — with
  the explicit caveat that it proves routing only, not
  plugin behaviour; (b) engine/coordinator behaviour when
  the backend throws `SheetsNotSignedInException` /
  `SheetsAuthorizationMissingException` (silent, pending,
  no acknowledgement); (c) the manual Android checklist in
  the PR description, which is the only verification of the
  actual no-UI-in-background behaviour, including
  kill-and-relaunch with pending work. If the reviewer
  wants platform-interface mocking, that is a separate
  approved task with its own dependency and compile
  verification on a Flutter machine. Sign-out leaves
  pending records intact because sign-out touches only the
  in-memory account; the local database and `syncStatus`
  are never modified by sign-out (covered by the
  not-signed-in coordinator/engine tests, which assert
  pending work survives a missing session).

## Corrections after technical review (second commit on PR #1)

The notes below supersede the corresponding claims in the first
version of this document. The first PR commit is not rewritten;
corrections land as a follow-up commit on the same branch.

- **Conditional acknowledgement (review §2).** The engine no
  longer calls an unconditional mark-synced. The repository now
  exposes `markTransactionSyncedIfUnchanged(id, updatedAt,
  deleted)`, which updates only when the stored row still has
  the uploaded revision, the same deleted state, and status
  `pending`. Zero affected rows means the transaction stays
  pending. Every local mutation — edit, delete, and restore —
  now advances `updatedAt` monotonically (at least 1ms beyond
  the previous stored value, at millisecond precision), so
  `updatedAt` is a usable revision under Drift/SQLite
  millisecond storage. A dedicated integer revision column
  would be stronger if storage truncated below milliseconds;
  it requires `build_runner` regeneration and is left as a
  documented follow-up, not hand-edited generated code.
  `updatedAt` is never changed by the acknowledgement itself.
- **Coordinator trigger race (review §3).** `requestSync()` no
  longer merely joins a running run. A trigger during a run
  sets a rerun flag; the run drains by re-reading pending work
  until a batch finishes with no new trigger, and a trigger in
  the finishing window starts a follow-up run. One run at a
  time is preserved; failed batches schedule the existing
  bounded retry instead of looping immediately.
- **Partial year moves + duplicates (review §4).** Tombstone,
  target write, and acknowledgement are separate, non-atomic
  operations. Retries re-read and converge: tombstoning and
  target updates are idempotent, and acknowledgement is
  conditional. Duplicate UUID rows in one worksheet, or more
  than one active row for a UUID across worksheets, are
  detected, reported in `SyncRunResult.duplicateUuids`, written
  to nothing, and left pending. The engine never deletes or
  merges ambiguous rows; manual cleanup in Sheets (keep one
  row, delete the rest by hand) is required before a retry can
  succeed for that UUID.
- **Error classification (review §5).** The backend no longer
  treats any error containing "404" as an empty worksheet.
  Google APIs sit behind the injectable `SheetsApiClient`
  boundary, which throws classified `SheetsApiException`s.
  `readYearSheet` first verifies the spreadsheet via
  `sheetTitles`; only a classified missing-worksheet error
  after that verification reads as empty. Missing-spreadsheet,
  permission, authentication, and network errors propagate
  and leave work pending.
- **Sign-in / authorization separation (review §6).**
  `restoreSession()` uses the nullable
  `Future<GoogleSignInAccount?>` from
  `attemptLightweightAuthentication()`, falls back (bounded,
  2s) to the retained `authenticationEvents` subscription,
  and shares one restoration across concurrent callers.
  Background sync uses silent authorization only
  (`authorizationForScopes`, never `authorizeScopes`, never
  `authenticate()`), and throws
  `SheetsAuthorizationMissingException` when authorization is
  absent. Interactive authorization happens only from the
  explicit Settings "Authorize Google Sheets" action
  (`authorizeForSync()`). Settings shows that action when its
  silent `hasSyncAuthorization()` check finds authorization
  missing; app startup never shows a picker or consent prompt.
  The google_sign_in 7.2.0 calls could not be compile-verified
  in this environment and must be verified with
  `flutter analyze` by the reviewer.
- **Drive discovery (review §7, supersedes the claim below).**
  `drive.file` grants access only to app-created files (or
  files opened with the app). A folder/spreadsheet the user
  created manually in Drive, even with the same name, is NOT
  guaranteed to be found, and the app will create its own
  app-created folder with the same display name instead. The
  implementation therefore claims only: within the
  app-created set, find-or-create reuses the first match and
  creates no duplicates; manual duplicates are never deleted
  or merged. Scopes are NOT broadened. If picking an existing
  user-created folder becomes required, the evaluated
  follow-up is a Google Picker flow (user picks the folder,
  granting access to that file) — not implemented here, and
  it needs its own platform/setup work. Remembering the
  app-created folder/spreadsheet ids persistently (Drift
  SyncSettings table + `build_runner`) remains the preferred
  long-term fix to avoid name discovery altogether.

- **One spreadsheet, resolved via Drive (no Drift schema change).**
  Reuse the existing `GoogleDriveService.setupExpenseTracker()`:
  find-or-create folder "Expense Tracker", then find-or-create
  spreadsheet "Expense Tracker" inside it — within the
  app-created set only, per the Drive limitation above. Drive
  itself is the persistent store: the id is re-resolved on
  every sync run, cached only in memory for that run, and
  re-resolved after a restart, so no duplicate folder/
  spreadsheet is created by repeated setup *within the
  app-created set*. This deliberately avoids a Drift schema
  change: adding a table would require regenerating
  `app_database.g.dart` with `build_runner`, which cannot run
  in this environment, and hand-editing 2,351 lines of
  generated code is unsafe. Follow-up (optional,
  owner/reviewer decision): add a Drift `SyncSettings` table
  holding folder/spreadsheet ids and regenerate on a machine
  with Flutter, to avoid the Drive list calls on every run.
  Duplicate spreadsheets already in Drive are NOT deleted or
  merged: the first match inside the folder wins, and the
  situation is documented for manual reconciliation (pick the
  sheet with the data, rename/delete the others by hand in
  Drive).
- **Year worksheets.** One worksheet per calendar year, titled
  `"2026"`, `"2027"`, etc., chosen by `transactionDate.year`, never
  by the current date. Created on demand via `batchUpdate` +
  `AddSheetRequest` when missing; header written when a sheet is
  new/empty. Existing rows are never reset.
- **Header schema (documented, backwards-compatible order).**
  `Date, Type, Category, Description, Amount, UUID, PaymentMethod,
  Notes, UpdatedAt, Deleted` (A:J). The first five columns keep the
  old order so any 5-column sheet created by the old code remains
  readable; UUID and the remaining fields are appended as F:J.
  Legacy A:E headers are recognised and extended in place by
  `ensureYearSheet` (see the third-commit corrections above);
  legacy data rows keep an empty UUID and are never modified.
  Date is `YYYY-MM-DD`; UpdatedAt is ISO-8601; Deleted is
  `TRUE`/`FALSE`; Amount is a number.
- **UUID idempotency.** The existing stable transaction `uuid` is
  the external identity (column F). The sync engine reads the
  relevant year sheets once per run, indexes rows by UUID, and
  upserts: update the row if it exists in the target year, append
  if it does not. Retries therefore cannot duplicate a row.
- **Create/update/delete/restore + year moves.** Deleted rows stay
  in their sheet with `Deleted=TRUE` and current `UpdatedAt`, so
  restore is a flag flip, not a re-append. A transaction whose
  date moves across years gets its old-year row(s) marked
  `Deleted=TRUE` and a new/updated row in the new year. A
  transaction deleted before it was ever synced creates no row.
  Local soft-delete + undo behaviour is unchanged.
- **Pending + retry.** Existing `syncStatus` semantics are kept:
  `'pending'` means needs sync, `'synced'` means synced.
  New repository methods `getPendingTransactions()` and
  `markTransactionSynced(id)` (syncStatus only, `updatedAt`
  untouched). The coordinator guards concurrent runs, runs
  pending work in `updatedAt` order, marks each row synced only
  after its Sheets write succeeds, leaves failures pending, and
  retries with exponential backoff (2s, 5s, 15s, 60s, max 4
  retries per trigger, then stops until the next save / sign-in /
  manual retry). No busy polling, no indefinite retry. Sync is
  triggered fire-and-forget after local create/edit/delete/restore,
  after sign-in, from a Settings "Retry sync" action, and
  best-effort on app start. It never blocks local saving.
- **Auth (superseded by the third-commit corrections
  above and by the startup-restoration section at the end
  of this document).** `GoogleAuthService` now subscribes to
  `authenticationEvents` (pub.dev google_sign_in example pattern)
  and `restoreSession()` calls `attemptLightweightAuthentication()`
  after `initialize()`, so a previous session can be restored
  without UI. `authorizationForScopes` is tried before
  `authorizeScopes`, so re-authorization prompts only when needed.
  Both required scopes are requested together when sync runs:
  `drive.file` (least-privilege Drive access, app-created files
  only) + `spreadsheets`. No other scopes. No tokens, secrets, or
  transaction data are logged. The hardcoded web OAuth client id
  already in the code is unchanged (it is a public client id, not
  a secret; no service-account credentials are added).
- **UX / errors.** Save confirmations say "saved locally" only.
  Sync success/failure is reported once per sync run via the
  existing `syncCompleted`/`syncFailed` notification types (one
  notification per run, not per row or per retry). Settings shows
  a sync section with a manual retry; failure messages never
  suggest the local transaction was lost.
- **Testability.** Sync logic lives in `lib/core/sync/sheets_sync.dart`
  with no Flutter/googleapis imports, behind a `SheetsSyncBackend`
  interface. The real backend (`google_sheets_backend.dart`) wraps
  Drive + Sheets APIs. Tests use a fake backend + fake store and
  require no Google account and touch no real spreadsheet.
- **Files changed:** see the PR description. `GoogleSheetsService`
  (the per-transaction spreadsheet creator) is removed; its two
  callers are rewired to the coordinator/backend. `GoogleDriveService`
  is reused unchanged. No pubspec / dependency changes. No Drift
  migration (schema version stays 6).

## Verification — Flutter checks actually run (31 Oct 2026)

Toolchain: Flutter 3.47.2 / Dart 3.13.2
(`~/workspace/build-verify/flutter/`), `flutter pub get`
succeeded (exit 0, `pubspec.lock` unchanged).

- `dart format` was run only on the files this PR changed
  (6 Dart files), not repo-wide: a repo-wide
  `dart format lib test` check shows many pre-existing master
  files are unformatted, and reformatting them would touch
  unrelated files. After formatting, a check run reports
  "Formatted 6 files (0 changed)".
- `flutter analyze` (first run, before the fix below):
  14 issues — 6 errors, all in
  `google_sheets_backend.dart`: a field and a method both
  named `_client` (duplicate definition, and the field
  shadowed the method so call sites saw a nullable value),
  plus 8 infos. That means the pushed head at the time did
  NOT compile; the error predates the third commit (the
  `_client` field/method pair came from the first commit)
  and was missed because analyze had never been run.
  Fixed by renaming the field to `_cachedClient`, plus a
  `??=` tidy in `google_auth_service.dart` for a
  `prefer_conditional_assignment` info. Second run:
  "5 issues found" — 0 errors, 0 warnings, 5 infos only
  (pre-existing initializing-formal patterns and one
  `use_build_context_synchronously` info in Settings).
- `flutter test`: `test/sheets_sync_test.dart` — 44/44
  passed. The full suite is 44 passed, 1 failed: the
  pre-existing default `test/widget_test.dart` ("Expense
  Tracker app loads") fails with "A Timer is still pending"
  — the stack shows the timer is created by `drift_flutter`
  when opening the database while the dashboard builds, a
  master-code path this PR did not touch (no sync code in
  the stack). Left failing and disclosed, not papered over.
- `flutter build apk --debug`: NOT completed. Flutter
  reports "[!] No Android SDK found" — the only SDK
  directory present contains cmdline-tools only and no
  JDK is installed, so no valid Android SDK exists here.
  An APK build still needs Pavan's Windows machine (and
  the known sandbox Gradle loopback limitation applies
  there too if attempted here). No APK or build pass is
  claimed.

## Legacy Google Sheets Migration Limitations

This section states what this PR does NOT do with Google
Sheets data created before it. Do not read any part of
this PR as automatic migration or complete historical
reconciliation — neither is claimed, and neither happens.

1. **Previous `Expenses` worksheets are not automatically
   imported.** The previous implementation wrote rows to a
   single worksheet named `Expenses` inside a freshly
   created spreadsheet per transaction. This PR does not
   read, copy, or import those `Expenses` worksheets into
   the new year-based worksheets. Rows that exist only in
   an old `Expenses` worksheet do not appear in the new
   master spreadsheet unless they are also present as
   locally stored Drift transactions (see point 4).
2. **Legacy A:E header extension applies to year-named
   worksheets only.** The A:E → A:J header extension in
   `ensureYearSheet` runs only for worksheets whose title
   is a calendar year (for example `2026`), because
   worksheet discovery (`listYearSheets`) recognises only
   titles that parse as years. A worksheet titled
   `Expenses`, or any other non-year title, is never
   listed, never ensured, and never has its header
   extended by this code.
3. **Existing spreadsheets outside the app-managed folder
   are not automatically discovered.** The app requests
   only `drive.file` (plus `spreadsheets`). Under
   `drive.file`, the app is granted access only to files
   it created or files the user opened with it — not to
   the whole Drive. A spreadsheet the user created
   manually in Drive, including one holding old expense
   records, is therefore not guaranteed to be found, even
   if it has the same name. The app creates and uses its
   own app-created folder and spreadsheet instead. Scopes
   were deliberately not broadened to work around this.
   See the Google Drive OAuth scope guidance:
   https://developers.google.com/workspace/drive/api/guides/api-specific-auth
4. **Old files remain untouched. The new master
   spreadsheet is populated from locally stored Drift
   transactions.** Nothing in this PR deletes, renames,
   edits, or merges any pre-existing Drive file or
   worksheet. The new master spreadsheet starts empty
   apart from year-worksheet headers and is filled only
   from the local Drift database, which is the source of
   truth: each pending local transaction is upserted by
   UUID into its year worksheet. A record that is not in
   the local database is not written anywhere by sync.
5. **Historical records that exist only in old Google
   Sheets require a separate manual migration or a future
   Google Picker/import feature.** If the only copy of a
   historical record lives in an old spreadsheet, the user
   must reconcile it by hand (for example, re-enter it in
   the app, or copy the row by hand into the new
   spreadsheet — understanding that a hand-copied row has
   no UUID and will not be managed by sync). A future
   feature could let the user pick an existing spreadsheet
   or folder with the Google Picker (which grants access
   to the picked file) and import its rows; that feature
   does not exist in this PR and is not promised here.
   Authentication for any such future import would still
   be user-initiated from Settings, under the same
   google_sign_in 7.2.0 separation used here:
   https://pub.dev/packages/google_sign_in/versions/7.2.0
6. **No automatic migration or complete historical
   reconciliation is claimed.** Do not describe this PR,
   in release notes, messages, or documentation, as
   migrating old Sheets data, importing history, or
   reconciling all historical records. What it does is
   narrower: from now on, locally stored transactions are
   backed up, by UUID, into year worksheets in one
   app-managed spreadsheet, using the Sheets values API:
   https://developers.google.com/workspace/sheets/api/guides/values
   History that predates the local database, or that
   lives only in old spreadsheets, stays where it is
   until the manual or future-import path in point 5 is
   used.

## Verification — results on the pushed commit (round 4, 31 Oct 2026)

This section describes the checks run on the exact tree in
the commit that carries this section. It supersedes the
earlier local results in the "Verification — Flutter
checks actually run" section above, which described an
earlier local state: a 6-file-only format run, a first
analyze run that found the `_client` compile error, and
test runs before the full 12-file formatting below. Do
not quote the earlier section as the state of the pushed
commit.

Correction to an earlier claim in these notes:
`lib/core/sync/google_drive_service.dart` WAS modified
by this PR (doc comment on `drive.file` discovery limits
plus `allowInteractiveAuthorization` plumbing through
`_getDriveApi` / `setupExpenseTracker`). It is the 12th
Dart file in the PR, not "reused unchanged". The full
PR Dart set is 12 live files (plus the deleted
`google_sheets_service.dart`): google_auth_service,
sheets_sync, google_sheets_backend, sync_coordinator,
google_drive_service, transaction_repository,
add_transaction_page, dashboard_page,
all_transactions_page, settings_page, main,
sheets_sync_test.

Toolchain: Flutter 3.47.2 / Dart 3.13.2
(`~/workspace/build-verify/flutter/`). `flutter pub get`
succeeded (exit 0, `pubspec.lock` unchanged).

- `dart format` — check run over all 12 PR Dart files:
  7 already clean; 5 reformatted (semantics-preserving,
  mostly pre-existing master regions — this codebase was
  never formatted): transaction_repository (140 changed
  lines), add_transaction_page (192), dashboard_page
  (435), all_transactions_page (56), google_drive_service
  (44). Re-check after formatting: "Formatted 12 files
  (0 changed)".
- `flutter analyze` — exit code 1, "5 issues found":
  0 errors, 0 warnings, 5 infos only (initializing-formal
  patterns and one `use_build_context_synchronously` in
  Settings). The `_client` field/method collision found
  in the earlier local run is fixed in this commit
  (field renamed to `_cachedClient`, `_client()` method
  kept), so the pushed code compiles under analysis.
- `flutter test test/sheets_sync_test.dart` — exit 0,
  44/44 passed ("All tests passed!").
- Full `flutter test` — exit 1: 44 passed, 1 failed.
  The failure is `test/widget_test.dart`, "Expense
  Tracker app loads": "A Timer is still pending even
  after the widget tree was disposed", with the timer
  created by `drift_flutter` (`driftDatabase`) while the
  dashboard builds.
- Widget test on the base commit (master `2231948`,
  checked out separately and run with the same
  toolchain): exit 1, the same test fails with the same
  signature ("A Timer is still pending...", stack through
  `drift_flutter`/`driftDatabase`). The failure is
  therefore pre-existing on master and is NOT introduced
  by this PR. It was established by running the test,
  not assumed.
- `flutter build apk --debug` — exit 1, NOT completed:
  "[!] No Android SDK found", even with `ANDROID_HOME`
  set to the SDK directory present here, which contains
  only cmdline-tools (no platforms, platform-tools, or
  build-tools), and no JDK is installed (`which java`
  empty, no `/usr/lib/jvm`, `JAVA_HOME` empty).
  `flutter doctor` likewise reports "Unable to locate
  Android SDK." No APK or build pass is claimed; the
  build needs a machine with a valid Android SDK/JDK.

## Startup account restoration and SnackBar auto-dismiss (round 5)

This section supersedes the Settings-only restoration rule
from the third-commit corrections above. The background-sync
constraints from that review are otherwise unchanged:
background sync itself still never calls `initialize()`,
`attemptLightweightAuthentication()`, `authenticate()`, or
`authorizeScopes()`; it reads only the in-memory account.

- **Startup restoration.** `main.dart` calls
  `GoogleAuthService.restoreOnStartup()` exactly once at
  startup (unawaited; the app UI is not blocked). It shares
  one in-flight restoration with the Settings
  `restoreSession()` path, initialization is idempotent, and
  the `authenticationEvents` subscription is created once
  and retained. Restoration calls only
  `attemptLightweightAuthentication()` and handles both
  return modes (nullable `Future` awaited; no `Future` →
  bounded 2s wait for the stream). It never calls
  `authenticate()` or `authorizeScopes()`, never stores
  tokens manually, and never loops or shows an
  account-picker/consent prompt of its own. It may show
  minimal platform-controlled UI on Android and is not
  claimed to be guaranteed silent. Background sync runs
  after restoration settles, so it can use the restored
  account; if no account was restored, sync stays silent
  and work stays pending.
- **Restoring state.** The service exposes
  `AuthRestorationState` (`checking` / `signedIn` /
  `signedOut`) synchronously and as a broadcast stream.
  Settings listens to it, shows "Checking your Google
  account…" with a disabled button while restoration is in
  progress (never the signed-out UI as final), then shows
  the connected account email or the normal sign-in button.
  If authentication is restored but Sheets authorization is
  missing, Settings shows the separate "Authorize Google
  Sheets" action; it does not ask for Google sign-in again.
  Explicit sign-out and revocation clear only the in-memory
  session (sign-out events move the state to `signedOut`);
  local transactions and pending sync records are untouched.
- **SnackBars.** The delete SnackBar (dashboard and
  all-transactions pages) and the "Transaction restored"
  SnackBar now set `duration: Duration(seconds: 5)` and
  `persist: false`. Root cause: a SnackBar with an action
  defaults to `persist: true` in this Flutter version, so
  the Undo bar stayed until tapped despite the default
  duration. Undo behaviour is unchanged and works within
  the five seconds.
- **Mounted check.** `_signInWithGoogle()` in Settings now
  checks `mounted` immediately after
  `_refreshAuthorizationStatus()` before using
  `ScaffoldMessenger`/`context`.
- **Startup failure fallback (round 6).** Initialization
  runs inside the same try/finally as the restore attempt
  in `_doRestore()`, so restoration state always settles to
  `signedIn` or `signedOut` — even if GoogleSignIn
  initialization throws, Settings never shows "Checking
  your Google account…" indefinitely. `restoreOnStartup()`
  swallows initialization/restoration errors so the
  unawaited startup future never produces an unhandled
  asynchronous error; background sync still runs
  afterwards and stays silent with work pending. No local
  transactions or pending sync records are cleared on
  failure, and a later Settings sign-in re-runs
  initialization and restoration. The Settings-initiated
  `restoreSession()` path still propagates errors so its
  UI can report them. No `authenticate()` or
  `authorizeScopes()` call is added at startup, and
  lightweight authentication on Android remains not
  guaranteed to be silent (google_sign_in 7.x migration
  guide).

## Verification — results on the pushed commit (round 5, 31 Oct 2026)

This section describes the checks run on the exact tree in
the commit that carries this section. It supersedes the
round-4 verification section above for this commit; the
round-4 results still describe the previous commit.

Toolchain: Flutter 3.47.2 / Dart 3.13.2
(`~/workspace/build-verify/flutter/`). `flutter pub get`
succeeded (exit 0, `pubspec.lock` unchanged).

- `dart format` — check run over all 12 PR Dart files:
  "Formatted 12 files (0 changed)" after formatting
  `settings_page.dart` (the only file that needed it).
- `flutter analyze` — exit code 1, "4 issues found":
  0 errors, 0 warnings, 4 infos only (initializing-formal
  patterns). The previous `use_build_context_synchronously`
  info in Settings is gone after the new mounted check.
- `flutter test test/sheets_sync_test.dart` — exit 0,
  44/44 passed ("All tests passed!").
- Full `flutter test` — exit 1: 44 passed, 1 failed.
  The failure is the same pre-existing `test/widget_test.dart`
  ("A Timer is still pending", drift stack) that was run
  against base commit `2231948` in round 4 and failed there
  too with the same signature; it is not hidden and is not
  introduced by this commit. No new test was added: the
  auth service wraps the platform plugin singleton and
  cannot be unit-tested without new dev dependencies (see
  the earlier testability note), so startup restoration
  and the SnackBar timing are covered by the manual
  Android checklist in the PR description.
- `flutter build apk --debug` — not run in this round:
  no Android SDK/JDK exists in this environment (see the
  round-4 section). The APK build is part of Pavan's
  manual validation on his Windows machine against the
  pushed commit SHA.

## Verification — results on the pushed commit (round 6, 31 Oct 2026)

Focused robustness fix only: initialization moved inside
the `_doRestore()` try/finally, and `restoreOnStartup()`
swallows startup restoration errors. Successful restoration
behaviour, SnackBar duration/persist/Undo, and the Settings
restore path are unchanged. This section describes the
checks run on the exact tree in the commit that carries
this section (the Dart tree is identical to the tree the
checks ran on; only this documentation section was added
afterwards in the same commit).

Toolchain: Flutter 3.47.2 / Dart 3.13.2
(`~/workspace/build-verify/flutter/`).

- `dart format` — check run over all 12 PR Dart files:
  "Formatted 12 files (0 changed)".
- `flutter analyze` — exit code 1, "4 issues found":
  0 errors, 0 warnings, 4 infos only.
- `flutter test test/sheets_sync_test.dart` — exit 0,
  44/44 passed ("All tests passed!").
- Full `flutter test` — exit 1: 44 passed, 1 failed.
  The failure is the same pre-existing `test/widget_test.dart`
  ("A Timer is still pending", drift stack) that was run
  against base commit `2231948` in round 4 and failed there
  too with the same signature; it is not hidden and is not
  introduced by this commit. The initialization-throw
  edge case itself cannot be exercised by the existing
  test suite (the auth service wraps the platform plugin
  singleton); it is a code-path guarantee verified by
  inspection and by analyze, and remains part of the
  manual Android checklist.
- `flutter build apk --debug` — not run in this
  environment (no Android SDK/JDK).
