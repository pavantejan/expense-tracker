# Custom category management

## What this module adds

- `CustomCategoryRepository.updateCategory()` now targets only the
  supplied category ID (Drift `where` clause). Previously it wrote
  without a `where` clause and would have updated every custom
  category row. Updating a non-existent ID returns `false`.
- Custom categories can be added, edited, and deleted from
  **Settings → Custom categories** (`CategoriesPage`). Built-in
  categories stay visible and read-only. Each custom category
  picks an icon from a curated Material icon set; only the icon
  code point is stored.
- The add/edit transaction category selector lists built-in
  categories plus all saved custom categories, showing each
  custom category's stored icon.
- Renaming a custom category renames the matching local
  transactions in the same database transaction, with updated
  revision timestamps and `syncStatus: 'pending'`, so the
  renamed rows re-sync through the existing Sheets sync. The
  sync coordinator is triggered after a successful rename.
  Deleting a custom category never touches transactions:
  historical rows keep their stored category text, and editing
  such a transaction shows its stored text as an extra selector
  item instead of silently replacing it.

## No schema change

No database schema or migration was introduced (schema stays
version 6). Category identity in transactions remains the stored
name text; the rename path updates that text. The only
constructor change is an optional test-only `QueryExecutor`
parameter on `AppDatabase` (production code still uses the
default file-backed connection); it enables in-memory database
tests and changes no table or migration.

## Validation

Category names are trimmed; empty names are rejected;
duplicates are rejected case-insensitively against other custom
categories and against built-in category names, with distinct
messages. The repository enforces the custom-category duplicate
rule as well (`ArgumentError`), so the form check is not the
only guard. Editing a category without renaming it is not a
duplicate of itself.

## Tests

- `test/custom_categories_test.dart`: repository tests on an
  in-memory Drift database covering add, targeted update,
  non-existent update, delete isolation, duplicate rejection,
  rename propagation to transactions, pending-sync marking,
  icon-only rename touching no transaction, and delete leaving
  historical transactions intact.
- `test/category_form_test.dart`: form-dialog validation tests
  (empty, duplicate, built-in collision, valid save with icon,
  edit-without-rename) plus `CategoriesPage` add/delete/edit
  flow tests against an in-memory database.

Test-environment note: widget tests that mount a page backed by
a live Drift database must close the database inside the test
body (before teardown) — an open Drift connection leaves a
Timer pending in the widget-test binding and fails teardown.
The page tests do this via a `closeDatabase` helper; the
pre-existing `widget_test.dart` Timer failure is a separate,
unchanged baseline (see the PR description).
