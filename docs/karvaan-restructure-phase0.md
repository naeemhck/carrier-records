# Karvaan UI restructure — Phase 0 evidence (shared foundations)

Date: 2026-10-19. Branch: update/karvaan-restructure (base update/karvaan-bilingual @ 01c6568), clean worktree at start.

## Course corrections applied during this phase
1. The 2026-10-17 full-language-toggle decision was implemented first (KarvaanLanguageController with shared_preferences persistence, KarvaanLanguageToggle "EN | اردو" in shell top bar + sign-in AppBar, single-language BilingualText/BilingualCaption, app-wide Directionality RTL in Urdu mode, `.inline` tooltips switched to active language).
2. User reversed the decision same day (2026-10-19): keep BOTH languages visible, stacked bilingual (English semibold above Urdu regular, LTR layout, RTL only on Urdu runs, Latin digits). ALL toggle work reverted via `git checkout` of the 10 touched files + deletion of app/lib/app/karvaan_language.dart. Worktree verified clean afterward. No toggle code remains: `grep -rn "KarvaanLanguage" app/lib` returns nothing.
3. Mockup HTML files in karvaan-ui-audit/mockups/ are fully authoritative again for bilingual label patterns.

## Scope
Shared foundations the per-screen phases build on:
- `app/lib/app/karvaan_patterns.dart` (new): TripRouteLine (origin pin movement-blue → dashed line → destination pin money-green, per-leg city/date/office captions, forced LTR like RouteLabel), KpiCard (headline tabular figure + stacked caption + period tag + drill-down arrow; filled brand-green variant for live state), AgingBand/AgingBandStrip (tappable receivables bands), TimestampFooter (created/updated/dispatched micro captions), PaperTrailAmount (green tappable money figure deep-linking to its source record). All presentation-only; all text stacked bilingual; all amounts tabular + Latin digits.
- Catalogue: 12 new strings appended to tools/karvaan/phrases.json (origins ["ui-restructure-patterns"]) and hand-appended to app/lib/app/ui_catalogue.dart in the exact committed format (Bilingual const + Accessibility const + values-list entry): readMore, dispatchedNow, draftTrips, settlementsDue, agingNotYetDue, agingUpTo30Days, aging31To60Days, aging61To90Days, agingOver90Days, createdOn, updatedOn, dispatchedOn. generate_catalogue.py was NOT run (it would destroy the hand-maintained Accessibility constants — verified: a trial run rewrote 6092→1685 lines).
- No repository, RPC, migration, RLS, calculation, or authorization change. No backend contact.

## Verification
- `flutter pub get`: OK (78s).
- `flutter analyze --no-pub`: No issues found (78.2s).
- Tests: not run in Phase 0 (no behavioral change to covered code; new widgets have no tests yet — widget tests for the pattern widgets are a Phase 10 item).
- Baseline for later phases: analyze was already clean at 01c6568 before Phase 0.

## Outstanding / notes for later phases
- The 2026-10-19 re-test of karvaan-test.pages.dev (preview 19) found the bilingual branch already has: stacked bilingual everywhere, KarvaanMetric KPI-style cards on the dashboard, working Expenses/History/Money tabs, a Money section with per-trip paid-vs-outstanding, an end-to-end walkable draft wizard, thousands separators + integer counts. The restructure phases therefore audit-then-fill-gaps rather than build from zero. Still open per that re-test: expense-categories master data empty on the test backend (data gap, not UI), no version shown in UI.
