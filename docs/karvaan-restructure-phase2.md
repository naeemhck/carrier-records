# Karvaan UI restructure — Phase 2 evidence (trips list)

Date: 2026-10-19. Branch: update/karvaan-restructure. No commit, push, merge, or branch switch. Only `app/lib/features/trips/trip_workspace.dart` touched for app source (presentation only); catalogue additions in `tools/karvaan/phrases.json` + hand-appended to `app/lib/app/ui_catalogue.dart` (`generate_catalogue.py` NOT run).

## Baseline & scope
The branch already had a working trips list (search, office/vehicle/date-range filters, status dropdown, plain cards). Phase 2 replaced the plain cards with route-drawn cards and restyled the filters; all data flows, validation, and repository calls unchanged.

## What changed (trip_workspace.dart, list section)
- **Route-drawn cards**: each card now renders `TripRouteLine` (from `karvaan_patterns.dart`, Phase 0) with per-leg meta (city + date + office, forced LTR), a vehicle+driver line (registration · owner_name; `driver_name` is not returned by `list_trips` — flagged below), `TripStatusBadge`, and `TimestampFooter` (created date + dispatch date).
- **ONE headline figure**: the card's money figure is the customer outstanding rendered as `PaperTrailAmount` (green, tabular, deep-links to that trip's Money tab via `detail(id, initialTab: 1)`). Zero outstanding renders the settled zero-state wording (`L10n.settled`), never "PKR 0.00".
- **Outstanding source**: per-trip outstanding comes from the existing `get_trip_financials` via `widget.finance` (already injected for moneyMode), memoized per trip id in `_moneyFutures` and cleared on reload. Loading/error states render nothing — never a guessed figure.
- **Notes**: long notes truncate behind an `ExpandableNote` "Read more" control (`L10n.readMore`); expansion is one-way.
- **Filter chips**: the status dropdown was replaced with chips for All / Draft / Dispatched / Arrived / Cancelled (`ValueKey('trip-filter-<STATE>')`; Cancelled added beyond the spec's four because the backend state exists and `tripStateLabel` supports it). The existing office/vehicle/date-range filters keep working, restyled compactly into a shared Wrap; the prominent search field is kept.
- **Empty state**: one guidance line + New trip action. Blue = movement, green = money throughout.
- Car counts use `displayCount` (integers, never "1.00"); all amounts tabular with Latin digits.

## Catalogue
New strings: `ui.settled` ("Settled" / "تصفیہ شدہ") and `ui.all` ("All" / "تمام"), origins `["ui-restructure-phase2"]`, appended to `tools/karvaan/phrases.json` and hand-appended to `app/lib/app/ui_catalogue.dart` (Bilingual const + Accessibility const + values-list entry).

## Verification
- `flutter analyze --no-pub`: zero issues in touched files (the single repo-wide warning is in `test/expense_phase5_test.dart`, another agent's file).
- New tests in `app/test/trip_restructure_p234_test.dart`: "trips list renders route-drawn cards with money figure" (route line, badge, vehicle, timestamps, settled wording, Read more, chips drive the status filter) and "trips list card shows outstanding as a money deep-link" (PaperTrailAmount tap opens the detail on the Money tab). Both PASS.
- Full required suite (trip_workspace, trip_steps, trip_draft, trip_lifecycle, gui_trip_detail, domain_status_qa + new file): 33/33 PASS. Financial suites (financial_contract, payment_model, expense_model, web_money): 16/16 PASS.
- Test-harness fixes (no app change): result cards render below the fold in the 800×600 test viewport, so card assertions use `skipOffstage: false`; `find.byType`/`find.text` skip offstage widgets by default. After scrolling, `ListView` unmounts off-screen children outside its cache extent — the test drags back up before tapping the filter chips.

## Intentionally left out / flagged
- `list_trips` rows do not include `driver_name`, `notes`, or `updated_at`, and there is no per-row outstanding — the vehicle line shows registration · owner_name, timestamps show created + dispatch only, and outstanding requires one `get_trip_financials` call per visible trip. Widening the row payload is a backend change: STOPPED and reported, not improvised.
- The spec's `<language-toggle>` block is superseded (user decision 2026-10-19): stacked bilingual retained, no toggle.
