# Karvaan UI restructure — Phase 9 evidence (polish sweep)

Date: 2026-10-19. Branch: update/karvaan-restructure @ 479e648.

## Method
Sweep, not rebuild: the per-phase workers already implemented the Phase 9 items in their files. This phase verified each item holds app-wide and fixed what didn't.

## Findings (all verified, no code changes needed)
- **Thousands separators**: `displayMoney` (PKR + grouped digits) is the single formatting path. Grep over app/lib: zero raw `'PKR '` string interpolations, zero `toStringAsFixed` calls outside tests. Amounts in KarvaanFigure/KarvaanMetric/KarvaanAmount all render tabular + Latin digits.
- **Integer counts**: `displayCount` is the single count path. Zero `"1.00"`/`"0.00"` literals and zero `count.toString()`/`length.toString()` in app/lib. Trip cards, pagination, and report counts all use it.
- **Status wording**: standardized on catalogue-driven chips — TripStatusBadge (Draft/Dispatched/Arrived/Cancelled), MoneyStateChip (held/outstanding/due/credit), ExpenseStatusChip (Active/Historical), consignmentStateLabel. No raw English-only status strings in UI code.
- **Searchable pickers, recent-first**: trips `_MasterChoice` and expenses `_MasterPicker`/`_TripPicker` are searchable with session-local 5-most-used first (Phases 3/5). Money pickers stay searchable; usage-ordered needs a backend change (flagged in Phase 6, not improvised).
- **Corrections/cancellations**: consignment cancel lives in a PopupMenuButton overflow with a reversal-narrating confirmation (Phase 4); backend reversal behavior untouched.
- **Keyboard/focus**: trip editor wraps in CallbackShortcuts — Enter advances steps, Esc goes back, save stays explicit-tap (Phase 3). Visible focus indicators come from the theme (2px ink border on focused filled buttons; Material defaults elsewhere).
- **200% text scaling**: covered by worker widget tests at 100%/200% across 320/360/1280px widths (trips, expenses, money, reports, auth suites). KarvaanFigure keeps long figures on one line via bounded horizontal scroll instead of clipping; Urdu never below 11pt with natural line height.
- **No clipping/overlap**: no fixed-height text containers introduced; BilingualText stacks with intrinsic height; toolbar heights measured via bilingualToolbarHeight.

## QA-fix rollup (from the brief's ALSO FIX list)
- Draft-trip wizard completable: YES (Phase 3).
- Trip-detail Expenses/History tabs work: YES (Phase 4; expenses tab is a working deep-link — inline listing needs a trip-scoped expense query, flagged).
- Per-trip paid-vs-outstanding visible: YES (Phase 4 Money tab: billed vs outstanding; no UI-derived "paid" figure by design).
- Money balances/custody view: YES (Phase 6 hero figure).
- Aging bands: NOT implemented — needs backend due-date aging (flagged in Phase 6).
- Disabled Backups/Imports buttons explained: YES (Phase 8).
- Failed-login error visible without scrolling: YES (Phase 8).

## Verification
- `flutter analyze --no-pub`: No issues found (12.7s, full tree).
- No new tests in this phase (sweep only); full suite runs in Phase 10.
