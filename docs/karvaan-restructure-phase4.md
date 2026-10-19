# Karvaan UI restructure — Phase 4 evidence (trip detail)

Date: 2026-10-19. Branch: update/karvaan-restructure. No commit, push, merge, or branch switch. Only `app/lib/features/trips/trip_workspace.dart` touched (presentation only); no repository/RPC/migration/calculation changes. Physical-vs-financial separation stays visible (arrival never implies payment).

## Baseline & scope
The branch already had the detail hero, `KarvaanPinnedTabs` (Overview/Money/Expenses/History), and `TripTotalsStrip`. Phase 4 audited and filled the gaps: outstanding in the hero strip, a working Money tab with per-trip paid-vs-outstanding, overflow-menu corrections, verified Expenses/History tabs.

## What changed (TripDetail)
- **Hero**: now uses `TripRouteLine` (route-drawn, per-leg date meta) and `TripTotalsStrip` with a new optional `outstanding` parameter — the 4th cell is highlighted (`#EAF4ED`, via `_OutstandingCell`) and shows the settled wording at zero. Billed totals (Customer total, Owner share, Brokerage) unchanged.
- **Money tab**: shows billed totals plus a per-trip outstanding section — open CUSTOMER_RECEIVABLE claims render as `PaperTrailAmount` rows deep-linking to Payments & allocations (`widget.onPayments`). No "paid" figure is computed in the UI; the backend owns that arithmetic, so the tab shows billed vs outstanding without inventing a derived paid amount.
- **TripDetail params**: gained optional `initialTab` (the trips-list money figure deep-links with `initialTab: 1`) and `finance` (wired from `detail()` and `openLinked`).
- **Corrections/cancellations**: per-consignment Cancel moved from an inline TextButton into a `PopupMenuButton` overflow; the confirmation dialog narrates what will be reversed. Backend reversal behavior unchanged.
- **Notes** use `ExpandableNote` (Read more, one-way expand).
- **Expenses tab**: verified — the tab renders; there is no trip-scoped expense query in `ExpenseCommands` (another agent's file, read-only for this task), so the working deep-link to the Expenses workspace is retained rather than inventing a data path. This was the spec-allowed fallback.
- **History tab**: verified rendering (already lazy/working; unchanged).

## Verification
- `flutter analyze --no-pub`: zero issues in touched files.
- New tests: "detail money tab shows per-trip paid-vs-outstanding" (hero outstanding cell; Money tab claim row deep-links to Payments) and "consignment cancellation lives in an overflow menu" (no inline cancel; popup menu opens the narrated confirmation). Both PASS.
- Full required suite: 33/33 PASS (incl. pre-existing `gui_trip_detail_test.dart`). Financial suites: 16/16 PASS.
- Test-harness fixes (no app change): the pinned tab bar sits below the fold in the test viewport — the test scrolls it into view and settles before tapping, mirroring `gui_trip_detail_test.dart`.

## Intentionally left out / flagged
- Inline per-trip expense listing: no trip-scoped expense repository method exists and `ExpenseCommands` belongs to another agent — deep-link retained per the spec's fallback. If a trip-scoped expense query is added later, the tab is ready to render it inline.
- A concurrent edit by another agent removed `accountPurposeLabel` from `payment_workspace.dart` mid-task, breaking compilation of the Money-tab code that referenced it; replaced with `L10n.customerOutstanding` directly (exactly what the helper returned for CUSTOMER_RECEIVABLE). No behavior change.
- Per-trip "paid" is deliberately NOT derived in the UI (would be a financial-calculation change); the Money tab shows billed totals and outstanding only.
- The spec's `<language-toggle>` block is superseded (user decision 2026-10-19): stacked bilingual retained, no toggle.
