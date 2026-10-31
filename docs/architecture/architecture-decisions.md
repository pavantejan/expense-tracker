# Architecture Decision Records

Companion to `master-architecture-blueprint-v1.md` (Module 0). Statuses: **Accepted** = approved product/roadmap decision or verified fact. **Proposed** = design proposed in the blueprint, awaiting technical-lead approval before implementation. **Unresolved** = decision still open; the ADR records the options and what blocks it.

How to use: when a decision changes, add a new ADR superseding the old one (never rewrite history silently); record the superseding ADR number and date in the old entry.

---

## ADR-001 — Integer minor-unit money storage

- **Status:** Accepted (product decision, Module 0 brief §5)
- **Context:** The current app stores amounts as SQLite `REAL` / Dart `double` and formats with `toStringAsFixed(2)`. Floating-point totals diverge from exact accounting once transfers, splits, reconciliation and import matching exist. The PR #2 review already proved second-precision timestamp collapse; floating-point money is the same class of silent-corruption risk.
- **Decision:** Store all persisted financial amounts as SQLite `INTEGER` minor units (paise for INR: ₹1,250.75 = 125075). All arithmetic on persisted/computed totals uses integers. A single immutable `Money` value object (`amountMinorUnits`, `currencyCode`) in `core/domain/` owns every conversion between minor units, decimal strings and display strings. `double` is forbidden for persisted amounts and totals.
- **Consequences:** Module 1 migrates/resets the amount column (see ADR-005); Sheets amounts stay decimal but are produced/consumed only in the sync adapter via string arithmetic; input parsing must use decimal-string parsing with round-half-away-from-zero (never `double.parse * 100`); tests must cover boundary values.
- **Unresolved:** none for the rule itself. Formatting library choice (`intl` or hand-rolled grouping) is a Module 1 implementation detail.

## ADR-002 — Initial currency scope: INR only, no exchange system

- **Status:** Accepted (product decision)
- **Context:** The user operates in INR. Multi-currency adds exchange-rate sourcing, rate dating and conversion postings — disproportionate for V1.
- **Decision:** INR is the only currency in V1. Every money-bearing row carries `currencyCode` (default `INR`) so a future currency choice does not need a schema redesign. Cross-currency transfers are blocked by validation. No exchange rates are invented, fetched, or stored.
- **Consequences:** No currency picker, no conversion UI, no rate table in Modules 1–13. A future multi-currency design needs its own ADR.
- **Unresolved:** none.

## ADR-003 — Ledger and account-balance design (double-entry-lite)

- **Status:** Proposed
- **Context:** There is no account concept today; a balance cannot be computed correctly (no opening balance, no per-account split, no transfer/card semantics). Full double-entry accounting is disproportionate for a single-user app.
- **Decision:** `FinancialTransaction` (business event) + `Posting` rows (account, direction, positive minor-unit amount), ≥2 balanced postings per transaction, written atomically with a `TransactionHistory` row. Balances derive from postings; opening balance is an opening posting; edits replace postings atomically; soft-delete excludes postings by predicate; restores re-include them. Posting rules A–G are specified in the blueprint §6.3.
- **Consequences:** Module 1 owns the model; reporting aggregates by transaction kind/category, never by re-deriving meaning from postings alone; a reconciliation test enforces derived balances.
- **Unresolved:** posting counterpart representation — real system clearing/equity account vs kind-derived reporting (blueprint §6.3, §16.2 Q2). The Module 1 plan must pick one and record it before coding.

## ADR-004 — Category IDs and archival

- **Status:** Proposed
- **Context:** Today transactions store a category *name* as text, forcing rename-propagation machinery (PR #2) and coupling history to display strings. Built-in categories already have stable ids in code (`food`, …) that are not persisted as relationships.
- **Decision:** Categories have stable string ids (built-ins keep existing ids; customs get stable ids at creation). Transactions reference `categoryId`. Rename is a Category-row update only. Categories are archived, never deleted, while referenced; deletion is allowed only with zero references. Built-in names are fixed strings by default.
- **Consequences:** The PR #2 rename-propagation path becomes unnecessary after the Module 1 reset (kept until then); historical transactions stay valid after rename/retire.
- **Unresolved:** whether built-in categories may be user-renamed (blueprint §16.2 Q8; recommended: no).

## ADR-005 — Database reset approach

- **Status:** Proposed (user confirmed existing data is disposable; execution needs per-module approval)
- **Context:** The current schema (v7, `double` amounts, text categories, no accounts) cannot evolve into the §5 model by migration without pretending disposable test data must be preserved.
- **Decision:** Target a clean new financial data model. No reset in Module 0. In Module 1, execute an explicit, user-approved, confirmed reset: delete local DB + import storage, create the new baseline schema via `onCreate` at a new schema version, retain the v2–v7 migration chain until that PR. The existing spreadsheet is left untouched; new-model data goes to a new spreadsheet or the same one under the versioned extension (unresolved — Q1). The reset path must be production-gated and never automatic.
- **Consequences:** Local test history is discarded (approved as a category of action); old spreadsheet remains as an archive; migration tests for the old chain are superseded in the reset PR, with the supersession stated in the PR.
- **Unresolved:** Sheets disposition on reset (Q1); rollback/export verification step details (Module 1 plan).

## ADR-006 — Google Sheets compatibility contract

- **Status:** Proposed
- **Context:** Sheets sync works and must be preserved. Stretching it into a general backend (accounts, cards, documents) would make it a second source of truth and break old spreadsheets.
- **Decision:** Columns A:J frozen forever in order. New fields extend rightward (K+) under a versioned schema recorded in a `_meta` worksheet (absence = v1). UUID remains the only row identity; upsert/duplicate/year-move/deleted-before-sync rules preserved. `syncRevision` stays local-only. Sheet `Amount` stays decimal. Sheets is never the canonical ledger; balances/postings/documents/settings never sync. Sensitive data (beyond last-4, documents, passwords, tokens) never uploads.
- **Consequences:** Module 1 must freeze the K+ order before the first v2 write; readers tolerate missing/unknown columns; old sheets read as v1 with name→id mapping fallbacks.
- **Unresolved:** exact K+ order (Q5); transfer second-row question (Q6, recommended: one row); separate Accounts worksheet (Q7, recommended: deferred).

## ADR-007 — Document processing and privacy

- **Status:** Proposed
- **Context:** Document import is a major feature (Module 7) handling sensitive financial documents. Accuracy requires human review; privacy requires on-device processing.
- **Decision:** One intake pipeline for all sources; per-field confidence; human review gate; no automatic posting of unverified data; statement reconciliation as a warning, not a blocker; duplicate detection reference-first with fallback matching and user-chosen resolution; originals in app-private storage with configurable retention; no document upload to Sheets/Drive/cloud in V1; on-device extraction (PDF text-layer first, OCR fallback) recommended, cloud extraction out of scope unless explicitly approved with consent design.
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

## ADR-010 — Notification approach

- **Status:** Proposed
- **Context:** Notifications today are in-app only (ChangeNotifier + Drift table). There is no OS scheduling capability. Reminders (Module 5) need one.
- **Decision:** Keep the in-app store and history behaviour. Add an OS notification scheduler in Module 5 behind an interface (so tests use a fake), with reminder content masked per §11. Notification *content* rules (no card numbers, limited amounts) apply from Module 5 onward.
- **Consequences:** Module 5 owns scheduler package selection (Q12) and device testing of delivery (including exact/inexact alarm behaviour on Android).
- **Unresolved:** scheduler package selection (Q12).

## ADR-011 — App lock, encryption, and backup security

- **Status:** Proposed (lock design) / Unresolved (encryption)
- **Context:** Financial data on a personal device needs an access gate; a gate is not encryption; exporting unencrypted backups without a decision would be a privacy regression.
- **Decision:** App lock (biometric + PIN fallback) is an access gate only — UI copy and docs must say it does not encrypt the database. PINs are never stored in plaintext. Logs/crash reports must never contain financial data. Whether the database and/or backup files are encrypted, and with what key management, is unresolved and must be decided before Module 3 ships export.
- **Consequences:** Module 12 owns lock implementation; Module 3 owns the encryption decision + implementation; each earlier module implements its §14 security slice.
- **Unresolved:** encryption option (Q3); lock mechanism details (Q13).

## ADR-012 — Split-and-settle last, local-only in V1

- **Status:** Accepted (roadmap decision)
- **Context:** Split-and-settle depends on accounts, people/groups, and a settled ledger, and would otherwise distort the foundation design toward multi-user concerns.
- **Decision:** Split-and-settle is Module 13 (last). People/groups/split entities are placeholders in this blueprint only and must not be built early. V1 split data is local-only; no multi-user sync design is included.
- **Consequences:** Foundation modules must not add split-specific fields "just in case"; settlement uses the ledger (transfer postings) when Module 13 arrives.
- **Unresolved:** whether split data ever syncs (Q16, revisit in Module 13).

---

*Record of decisions for Module 0. New decisions must be added as new ADRs (or as superseding entries) in the module that makes them — never by silently editing this file's history.*
