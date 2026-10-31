# Architecture Decision Records

Companion to `master-architecture-blueprint-v1.md` (Module 0). Statuses: **Accepted** = approved product/roadmap decision or verified fact. **Proposed** = design proposed in the blueprint, awaiting technical-lead approval before implementation. **Unresolved** = decision still open; the ADR records the options and what blocks it.

How to use: when a decision changes, add a new ADR superseding the old one (never rewrite history silently); record the superseding ADR number and date in the old entry.

## Revision history

- **v1 — 2026-10-31 (Module 0):** ADR-001..ADR-012 as originally written.
- **v2 — 2026-11-01 (review corrections round 2):** the technical lead accepted the overall direction but flagged modelling contradictions. ADR-001, ADR-003, ADR-005, ADR-006, ADR-007, ADR-010, ADR-011 and ADR-012 carry dated amendment notes below (original text preserved; amendments are additive and labelled). New entries ADR-013..ADR-017 record the decisions that resolve the contradictions. Nothing in v1 was silently overwritten: where v1 and v2 disagree, the amendment note says so explicitly and v2 governs.

## Decision status summary (after v2)

| Status | ADRs |
|---|---|
| Accepted | 001, 002, 003, 004, 005, 006, 012, 013, 014, 015, 016, 017 (007: data model/privacy accepted; extraction selection still proposed) |
| Proposed | 008, 009, 010, 011 (lock design; encryption option unresolved) |
| Unresolved | Encryption option (ADR-011); package selections (ADR-007/008/010); retention default, Accounts worksheet, built-in renaming, history purge, deep links, split sync (blueprint §16.2) |

---

## ADR-001 — Integer minor-unit money storage

- **Status:** Accepted (product decision, Module 0 brief §5)
- **Context:** The current app stores amounts as SQLite `REAL` / Dart `double` and formats with `toStringAsFixed(2)`. Floating-point totals diverge from exact accounting once transfers, splits, reconciliation and import matching exist. The PR #2 review already proved second-precision timestamp collapse; floating-point money is the same class of silent-corruption risk.
- **Decision:** Store all persisted financial amounts as SQLite `INTEGER` minor units (paise for INR: ₹1,250.75 = 125075). All arithmetic on persisted/computed totals uses integers. A single immutable `Money` value object (`amountMinorUnits`, `currencyCode`) in `core/domain/` owns every conversion between minor units, decimal strings and display strings. `double` is forbidden for persisted amounts and totals.
- **Consequences:** Module 1 introduces the amount column as integer minor units in the fresh `expense_tracker_v2` database (see ADR-005); Sheets amounts are numeric cells produced/consumed only in the sync adapter at the external boundary (see ADR-006); input parsing must use decimal-string parsing (never `double.parse * 100`); tests must cover boundary values.
- **Unresolved:** none for the rule itself. Formatting library choice (`intl` or hand-rolled grouping) is a Module 1 implementation detail.
- **Amendment (v2, 2026-11-01 — supersedes the v1 rounding paragraph):** the v1 text said extra fractional digits are rounded at input boundaries. That contradicts the "maximum two decimal places" input rule. **Decided:** manual INR input with more than 2 fractional digits is *rejected* with a field error; rounding (round-half-away-from-zero) happens only at the importer-normalisation boundary, with the raw value retained for audit (ADR-016). The v1 rounding sentence no longer governs.

## ADR-002 — Initial currency scope: INR only, no exchange system

- **Status:** Accepted (product decision)
- **Context:** The user operates in INR. Multi-currency adds exchange-rate sourcing, rate dating and conversion postings — disproportionate for V1.
- **Decision:** INR is the only currency in V1. Every money-bearing row carries `currencyCode` (default `INR`) so a future currency choice does not need a schema redesign. Cross-currency transfers are blocked by validation. No exchange rates are invented, fetched, or stored.
- **Consequences:** No currency picker, no conversion UI, no rate table in Modules 1–13. A future multi-currency design needs its own ADR.
- **Unresolved:** none.

## ADR-003 — Ledger and account-balance design (LedgerAccount model)

- **Status:** Accepted (decided in review round 2, 2026-11-01; v1 status was Proposed)
- **Context:** There is no account concept today; a balance cannot be computed correctly (no opening balance, no per-account split, no transfer/card semantics). Full double-entry accounting is disproportionate for a single-user app. The v1 blueprint left the posting counterpart representation unresolved (clearing account vs kind-derived reporting) — the technical lead flagged this as a contradiction.
- **Decision:** `FinancialTransaction` (business event) + `Posting` rows (one valid `LedgerAccount`, distinct `direction`, always-positive integer minor units), ≥2 balanced postings per transaction, written atomically with a `TransactionHistory` row. **LedgerAccount (new in v2)** is the single posting-target abstraction: user asset/liability accounts map 1:1 to ledger accounts; each expense/income category maps to system ledger accounts; `opening_equity` and `adjustments` are single system ledger accounts; system accounts are never shown as user accounts (`isSystem`). The balancing invariant (SUM debits == SUM credits per event) is defined separately from normal-balance rules (asset/expense normal-debit; liability/income/equity/adjustment normal-credit). Balances derive from postings; opening balance is a dedicated `opening_balance` financial event (no `openingPostingId` field; one-directional `LedgerAccount.userAccountId` mapping avoids circular insertion dependencies — blueprint §6.4). Transfer/refund/adjustment semantics are specified in ADR-013.
- **Consequences:** Module 1 owns the model; reporting aggregates by transaction kind/category, never by re-deriving meaning from postings alone; a reconciliation test enforces derived balances and the invariant.
- **Unresolved:** none for the model. (The v1 open question about counterpart representation is closed by this amendment.)

## ADR-004 — Category IDs and archival

- **Status:** Proposed
- **Context:** Today transactions store a category *name* as text, forcing rename-propagation machinery (PR #2) and coupling history to display strings. Built-in categories already have stable ids in code (`food`, …) that are not persisted as relationships.
- **Decision:** Categories have stable string ids (built-ins keep existing ids; customs get stable ids at creation). Transactions reference `categoryId`. Rename is a Category-row update only. Categories are archived, never deleted, while referenced; deletion is allowed only with zero references. Built-in names are fixed strings by default.
- **Consequences:** The PR #2 rename-propagation path becomes unnecessary after the Module 1 fresh-database switch (kept until then); historical transactions stay valid after rename/retire.
- **Unresolved:** whether built-in categories may be user-renamed (blueprint §16.2 Q8; recommended: no).

## ADR-005 — Fresh database strategy (supersedes the v1 reset proposal)

- **Status:** Accepted (decided in review round 2, 2026-11-01; v1 status was Proposed)
- **Context:** The current schema (v7, `double` amounts, text categories, no accounts) cannot evolve into the §5 model by migration without pretending disposable test data must be preserved. The v1 blueprint proposed deleting/recreating the database in Module 1; the technical lead required a safe clean-start approach given the global database singleton.
- **Decision:** Target a clean new financial data model in a **new database identity, `expense_tracker_v2`**, created with `onCreate` at a new schema version. The old v7 database file is left untouched as an archive/fallback until an explicit, user-approved cleanup action; it is never opened by new code. No deletion of a live/open SQLite database, no automatic destructive reset during normal startup, and no migration from v7 (a different file is a different database). The global singleton is replaced by an injectable database provider/factory for the v2 database. Validation follows blueprint §7.3 (v2 creation, old file untouched, restart persistence, V2 Sheets identity, no startup deletion). **The v1 "reset" proposal is superseded in full by this entry** — the word "reset" must not be used for the Module 1 switch; it is a fresh database identity.
- **Consequences:** Local test history is inaccessible in the new app (approved disposable-data premise); disk temporarily holds both files; rollback = previous app version can still open the old file until cleanup; migration tests for the old chain are superseded in the Module 1 PR, stated in that PR.
- **Unresolved:** none for the strategy. Execution still needs per-module approval in Module 1 (validation §7.3 must pass).

## ADR-006 — Google Sheets compatibility contract (V2 identity + frozen K+ order)

- **Status:** Accepted (decided in review round 2, 2026-11-01; v1 status was Proposed)
- **Context:** Sheets sync works and must be preserved. Stretching it into a general backend (accounts, cards, documents) would make it a second source of truth and break old spreadsheets. The v1 blueprint left the V2 spreadsheet disposition and the K+ order unresolved — the technical lead flagged both as contradictions (a "frozen" contract cannot have an unfrozen order, and old `Type` semantics could misclassify new kinds).
- **Decision:** **Distinct V2 spreadsheet identity:** the new model writes to a separate spreadsheet (`Expense Tracker v2`, resolved per run by Drive query with an `appProperties` marker, never hardcoded); the V1 spreadsheet is preserved completely untouched as an archive and never written by V2 code; V1 rows are not migrated (see ADR-015). Columns A:J frozen within each version (identical headers/order in V1 and V2). **K+ order frozen by specification (K `Kind`, L `CategoryId`, M `AccountId`, N `Account`, O `FromAccountId`, P `FromAccount`, Q `ToAccountId`, R `ToAccount`, S `CardId`, T `Merchant`, U `Tags`, V `OriginalUuid`, W `RelatedUuid`, X `Source`)** — stable identity fields plus human-readable names; no `TransferGroupId`. `Type` (column B) uses the full kind vocabulary; unknown kinds are rejected, never coerced. UUID remains the only row identity; upsert/duplicate/year-move/deleted-before-sync rules preserved. `syncRevision` stays local-only. **Money conversion:** amounts are numeric spreadsheet cells produced from integer paise at the boundary only — never a decimal text string under RAW, never `double` arithmetic internally (round-trip tests for 0/1/99/100/125075/9007199254740991 paise required). Sheets is never the canonical ledger; balances/postings/documents/settings never sync. Sensitive data (beyond last-4, documents, passwords, tokens) never uploads.
- **Consequences:** Module 1 must implement V2 resolution + frozen K+ order before the first V2 write; readers tolerate missing/unknown columns; old sheets read as V1 with name→id mapping fallbacks only through an explicitly approved future archive feature.
- **Unresolved:** separate `Accounts` worksheet (deferred, revisit after Module 1); `_meta` worksheet cell-layout detail (Module 1 implementation detail).

## ADR-007 — Document processing and privacy

- **Status:** Accepted for data model/privacy; Proposed for extraction package selection (amended in review round 2, 2026-11-01)
- **Context:** Document import is a major feature (Module 7) handling sensitive financial documents. Accuracy requires human review; privacy requires on-device processing. The v1 data model mixed statement totals into the document row and did not separate statement metadata from line candidates — the technical lead flagged the double-counting risk.
- **Decision:** One intake pipeline for all sources; per-field confidence; human review gate; no automatic posting of unverified data; duplicate detection reference-first with fallback matching and user-chosen resolution; originals in app-private storage with configurable retention; no document upload to Sheets/Drive/cloud in V1; on-device extraction (PDF text-layer first, OCR fallback) recommended, cloud extraction out of scope unless explicitly approved with consent design. **Data-model separation (new in v2):** `ImportDocument` carries document-level metadata only; statement totals live in `BankStatementSummary` / `CardStatement` (chain `ImportDocument` → `CardStatement` → `CreditCard`; at most one statement summary per document; summaries reference the document, never the reverse); individual lines are `ExtractionCandidate`s and statement totals are never candidates. `ImportDocument` mutual exclusion: once classified, exactly one of `accountId`/`creditCardId` is set; both set is invalid. Never store full card numbers, CVV, PIN or PDF passwords. **Module 7 readiness gate (new in v2):** minimum sensitive-file/import protections (blueprint §11.9) must be in place and listed in the Module 7 PR before import ships, even though app lock itself stays in Module 12.
- **Consequences:** Module 7 must define the extractor interface before choosing an OCR approach; deterministic fixture tests; retention + interruption recovery are first-class requirements, not polish.
- **Unresolved:** extraction package selection (Q9); retention default (Q4).

## ADR-008 — Android sharing

- **Status:** Proposed
- **Context:** Sharing from payment apps (e.g. CRED) is an approved first-class intake method, but the source app controls the share sheet and payload; nothing about it can be guaranteed.
- **Decision:** Support `ACTION_SEND`/`ACTION_SEND_MULTIPLE` for `image/*`, `application/pdf`, `text/plain`, cold and warm, converging on the single import intake. Evaluate an established sharing plugin behind an app-owned `ShareIntake` interface first; custom MethodChannel only on demonstrated gaps. State the compatibility limitation in product copy and docs: if a source app never offers this app, in-app intake remains the supported path.
- **Consequences:** Module 7 device tests must cover cold/warm/multiple/text cases; no feature may assume a share will arrive.
- **Unresolved:** plugin vs custom channel (Q10).

## ADR-009 — State management: no new framework

- **Status:** Proposed
- **Context:** The current app uses Drift streams + repository singletons + StatefulWidget/ChangeNotifier and is correct and testable. The new complexity is domain/data (ledger, import, sync), not UI state plumbing.
- **Decision:** Keep the current approach. Do not introduce Riverpod, Bloc, or another framework for this redesign. Revisit only with recorded evidence that cross-screen derived state is unmanageable, via a new ADR.
- **Consequences:** Modules build on the existing provider pattern; view-models (where needed) are plain Dart classes fed by streams, not framework constructs.
- **Unresolved:** none unless evidence emerges.

## ADR-010 — Notification approach (generic scheduler owned by M5)

- **Status:** Proposed (amended in review round 2, 2026-11-01)
- **Context:** Notifications today are in-app only (ChangeNotifier + Drift table). There is no OS scheduling capability. Reminders (Module 5) need one. The v1 dependency graph implied M6 depended on M5; the technical lead corrected this: the scheduler is a reusable service, not a hard dependency.
- **Decision:** Keep the in-app store and history behaviour. **Module 5 provides a generic reminder scheduler** behind an interface (so tests use a fake), with reminder content masked per §11. Notification *content* rules (no card numbers, limited amounts) apply from Module 5 onward. M6 (card reminders), M4 (budget alerts) and M11 (insight nudges) *may reuse* the scheduler as optional integrations — each remains buildable/shippable with in-app reminders first, and none hard-depends on M5.
- **Consequences:** Module 5 owns scheduler package selection (Q12) and device testing of delivery (including exact/inexact alarm behaviour on Android).
- **Unresolved:** scheduler package selection (Q12).

## ADR-011 — App lock, encryption, and backup security (gates decided)

- **Status:** Proposed (lock design) / Unresolved (encryption option) — amended in review round 2, 2026-11-01
- **Context:** Financial data on a personal device needs an access gate; a gate is not encryption; exporting unencrypted backups without a decision would be a privacy regression.
- **Decision:** App lock (biometric + PIN fallback) is an access gate only — UI copy and docs must say it does not encrypt the database. PINs are never stored in plaintext. Logs/crash reports must never contain financial data. Whether the database and/or backup files are encrypted, and with what key management, is unresolved and must be decided before Module 3 ships export. **Gates (new in v2, decided):** (1) backup/DB encryption is a *hard gate* before Module 3 export/restore ships — no export code ships undecided; (2) minimum sensitive-file/import protections (§11.9) are a *readiness gate* before Module 7 ships, even though app lock implementation stays in Module 12.
- **Consequences:** Module 12 owns lock implementation; Module 3 owns the encryption decision + implementation; each earlier module implements its §14 security slice.
- **Unresolved:** encryption option (Q3); lock mechanism details (Q13).

## ADR-013 — Transfer, refund and adjustment semantics (new, review round 2)

- **Status:** Accepted (2026-11-01)
- **Context:** The v1 blueprint carried a `transferGroupId` and left refund/adjustment semantics vague, while card-payment and transfer handling risked double-counting. The technical lead required one chosen transfer design and explicit refund/adjustment rules.
- **Decision:** **Transfer:** one `FinancialTransaction` (kind `transfer`), exactly two postings, `sourceAccountId` + `destinationAccountId`, no group id, same-currency enforced, no self-transfer, excluded from income/expense reporting. **Refund:** kind `refund`, must link via `reversesTransactionId` to an active expense/income transaction; partial and multiple refunds allowed; maximum refundable = original − sum of active refunds (over-refund rejected); destination defaults to the original account and is explicit when different; postings mirror the original reversed; reporting nets against the original category in the refund's period. **Adjustment:** kind `adjustment`, requires `adjustmentReason` and a counterpart (category ledger account or system `adjustments` account), two postings, `relatedTransactionId` when correcting another event, reported separately unless the counterpart is a category ledger. **Reversal:** kind `reversal`, full mirror of the original, original marked reversed and retained. Refunding a transfer/card payment/opening balance is rejected — those are corrected via adjustment/reversal. Card UI/billing stays in Module 6; Module 1 provides only the generic liability-ledger foundation (ADR-003).
- **Consequences:** No `transferGroupId` anywhere (data model, Sheets contract, APIs). Refund-capacity and transfer rules are service-level invariants with tests.
- **Unresolved:** none.

## ADR-014 — Fresh-database provider and validation (new, review round 2)

- **Status:** Accepted (2026-11-01; detail under ADR-005)
- **Context:** The current code opens the database through a global singleton. A safe clean start must not delete a live/open database or reset anything on startup.
- **Decision:** The v2 database is opened through an injectable provider/factory (constructed once, explicitly, at startup); the old file is never opened. Validation follows blueprint §7.3 (creation, old-file-untouched, restart persistence, V2 Sheets identity, no startup deletion). Explicit cleanup of the old file (if ever) is a separate confirmed settings action, only when no connection to it is open.
- **Consequences:** No `deleteDatabase` on any startup path; the factory opening only the v2 name is asserted by test.
- **Unresolved:** none.

## ADR-015 — Sheets V2 spreadsheet identity (new, review round 2)

- **Status:** Accepted (2026-11-01; detail under ADR-006)
- **Context:** V1 and V2 data must never share a spreadsheet, or old `Type` semantics and old rows would corrupt the new model (and vice versa).
- **Decision:** Distinct V2 spreadsheet titled `Expense Tracker v2`, resolved per sync run by Drive query scoped to app-created files with an `appProperties` marker (`expenseTrackerSchemaVersion = 2`); identity = resolved Drive file id, held in memory per run, never hardcoded, never stored in the sheet or the local database as a secret. V1 spreadsheet is never opened for writing by V2 code; V1 rows are not migrated; V2 starts empty with a `_meta` worksheet (`sheetSchemaVersion = 2`).
- **Consequences:** Module 1 implements V2 resolution before the first V2 write; a fake-backend test asserts no write targets the V1 identity.
- **Unresolved:** `_meta` cell-layout detail (Module 1 implementation detail).

## ADR-016 — Input precision: reject vs normalise (new, review round 2)

- **Status:** Accepted (2026-11-01; amends ADR-001)
- **Context:** "Maximum two decimal places" and "round extra digits" contradict each other: silent rounding changes what the user typed.
- **Decision:** Manual INR input with more than 2 fractional digits is rejected with a field error. The sole rounding path is importer normalisation (documents/CSVs/Sheets): round-half-away-from-zero at the import parse boundary, original raw value retained on the candidate, normalised value shown in review. No rounding inside totals; no `double` parsing anywhere.
- **Consequences:** Amount-field validation + importer tests cover both paths explicitly.
- **Unresolved:** none.

## ADR-017 — Savings-goal allocation vs transfer contribution (new, review round 2)

- **Status:** Accepted (2026-11-01)
- **Context:** The v1 model conflated "money set aside in my head" with "money actually moved", which would double-count goal progress against account balances.
- **Decision:** `GoalContribution.contributionKind` distinguishes `allocation` (virtual: goal progress only, no balance movement, no backing transaction) from `transfer` (real money movement via a backing `transfer` `FinancialTransaction`; account + goal balances move exactly once, through the transaction). Deleting a contribution unlinks rather than deleting the backing transaction.
- **Consequences:** Goal progress, account balances and income/expense reporting each count a contribution exactly in the way its kind dictates; tests cover both kinds.
- **Unresolved:** none.

---

*Record of decisions for Module 0. New decisions must be added as new ADRs (or as superseding entries) in the module that makes them — never by silently editing this file's history.*
