# Google Sheets sync — working notes

Branch: `feature/fix-google-sheets-sync`, base `master` (2231948, 31 Oct 2026).
Environment note: no Flutter/Dart toolchain in this environment
(`which flutter dart` empty), so `dart format`, `flutter analyze`,
`flutter test`, and an Android build could NOT be run here. They must
be run by the reviewer / owner. Nothing in this PR claims otherwise.

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
  the second-commit notes and the Auth bullet below).**
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
  above — background sync never restores).** `GoogleAuthService` now subscribes to
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
