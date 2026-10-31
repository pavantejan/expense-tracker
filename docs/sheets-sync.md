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

- **One spreadsheet, resolved via Drive (no Drift schema change).**
  Reuse the existing, correct `GoogleDriveService.setupExpenseTracker()`:
  find-or-create folder "Expense Tracker", then find-or-create
  spreadsheet "Expense Tracker" inside it. Drive itself is the
  persistent store: the id is re-resolved on every sync run, cached
  only in memory for that run, and re-resolved after a restart, so
  no duplicate folder/spreadsheet is created by repeated setup.
  This deliberately avoids a Drift schema change: adding a table
  would require regenerating `app_database.g.dart` with
  `build_runner`, which cannot run in this environment, and
  hand-editing 2,351 lines of generated code is unsafe. Follow-up
  (optional, owner/reviewer decision): add a Drift `SyncSettings`
  table holding folder/spreadsheet ids and regenerate on a machine
  with Flutter, to avoid the Drive list calls on every run.
  Duplicate spreadsheets already in Drive are NOT deleted or merged:
  the first match inside the folder wins, and the situation is
  documented for manual reconciliation (pick the sheet with the
  data, rename/delete the others by hand in Drive).
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
- **Auth.** `GoogleAuthService` now subscribes to
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
