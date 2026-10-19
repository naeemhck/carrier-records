# Karvaan restructure Phase 7 evidence — reports, documents, report formats (2026-10-19)

## Baseline
Branch `update/karvaan-restructure`, worktree `~/workspace/karvaan-work`, app in `app/`.
Phase 7 implements the spec's Phase 7 section plus the `<report-format>` block and the
competitor-addendum pattern 2 (KPI-first dashboard). The spec's `<language-toggle>` block is
superseded per the 2026-10-19 user decision: the app keeps STACKED bilingual (English
semibold above Urdu regular, LTR layout, RTL only on Urdu text runs, Latin digits
everywhere). Generated PDF/Excel stay bilingual regardless.

Presentation only: no repository, RPC, migration, RLS, calculation, authorization, or
visibility change. Legacy v1 renderers (`output_pdf.dart`, `output_xlsx.dart`) untouched —
previously issued documents reprint exactly as originally issued.

## Scope
Touched (only): `app/lib/features/reports/report_workspace.dart`,
`output_workspace.dart`, `document_workspace.dart` (read, no change needed),
`output_pdf_v2.dart`, `output_xlsx_v2.dart`, `bilingual_output.dart`,
`authorized_output.dart`. Also updated `app/test/report_workspace_test.dart` (dashboard
test rewritten for the KPI dashboard).

### 1. KPI-first dashboard (`report_workspace.dart`, dashboard mode)
- Four `KpiCard`s (from Phase 0 `karvaan_patterns.dart`) across the top:
  - **Dispatched now** — filled brand green (live state), count of dispatched trips.
  - **Customer outstanding** — `L10n.customerOutstanding`, monthly-vehicle total, PKR.
  - **Settlements due** — `L10n.settlementsDue`, `owner_due` total, PKR.
  - **Draft trips** — `L10n.draftTrips`, count of draft trips.
- Each card: one headline tabular figure (`KarvaanFigure`, Latin digits) + stacked
  bilingual caption + period tag (live cards: today's date `YYYY-MM-DD`; money cards: the
  report `from — to` range; all Latin digits, language-neutral) + drill-down `onTap`.
- Drill-down opens the records behind the figure (paper-trail rule): dispatched/draft
  cards list the trips (trip number + `TripStatusBadge`); outstanding/settlements cards
  lazily load the `CLAIMS` report for the same filters and show the hero figure plus the
  per-party breakdown rows. Tapping the same card closes the panel; every list has an
  empty state (`L10n.noRecordsInThisPeriodScope`).
- The report builder moved to its own page: a "Reports" button (one tap) pushes
  `ReportWorkspace(dashboard: false)` with the same dependencies. The dashboard answers
  "what needs me right now" on one viewport.
- Non-dashboard (builder) mode keeps its grouped filters (`KarvaanSection`), tabular
  `KarvaanMetric` figures, empty states, and pagination; the old dashboard-only
  kind-switching tap behaviour was removed with the old totals wrap.
- No new catalogue strings were needed: `L10n.dispatchedNow`, `L10n.draftTrips`,
  `L10n.customerOutstanding`, `L10n.settlementsDue`, `L10n.reports`, `L10n.to`,
  `L10n.close`, `L10n.noRecordsInThisPeriodScope` already existed. Nothing appended to
  `phrases.json` / `ui_catalogue.dart` by this phase.

### 2. Output preview (`output_workspace.dart`)
- Totals strip stays summary-first; outstanding / balance-due totals now render on the
  `#EAF4ED` highlight (via the new shared `isBalanceDueKey` helper), matching the app
  and the new PDF/Excel formats. Combined `label: value` text preserved so existing
  assertions keep passing.

### 3. PDF template v2 (`output_pdf_v2.dart`) — newly issued documents
- Page header: Karvaan/کاروان wordmark in brand green `#0E7A3D`, stacked report title,
  document number, scope line (`offices · period`), generated-on timestamp (Latin
  digits), selected-columns frame.
- Tables: hairlines only (`top`/`bottom`/`horizontalInside`), no zebra, no header fill.
  Column headers are stacked bilingual labels; amounts right-aligned Latin digits.
- Totals moved to a strip at the END of the last band: key totals bold green,
  outstanding / balance-due rows (`isBalanceDueKey`) highlighted `#EAF4ED`; then the
  "Totals are server-calculated for all {n} authorized records." frame and the
  continuation note.
- Footer: page numbers + bilingual "internal use" note + issued/live frame +
  generation metadata (`issuer_name · issued_at/generated_at`).
- Green appears only on totals, status accents, and the wordmark.

### 4. Excel template v2 (`output_xlsx_v2.dart`) — newly issued documents
- Mirrors the PDF: title + scope metadata, frozen bilingual header row (freeze pane +
  print titles kept), identical column order, data rows, then a totals strip at the end.
- Amounts stored as REAL NUMBERS (`<v>95000.00</v>`, never text) so they sum; the
  15-digit precision guard and formula-safety (inline strings, no `<f>`) are unchanged.
- New cell styles: header bold with NO fill (green removed from headers); totals labels
  bold; totals money bold with the PKR number format; outstanding / balance-due totals
  bold with `#EAF4ED` fill (`FFEAF4ED`).
- Wide-money precision note and continuation note retained at the end.

### 5. Frozen presentation (`bilingual_output.dart`, `authorized_output.dart`)
- `bilingual_output.dart`: presentation validation now also accepts an OPTIONAL
  server-supplied `internal_use` frame (unknown keys still rejected); `BilingualOutput`
  exposes non-nullable `internalUse`, falling back to the renderer-side frozen
  `FrozenLabel('Internal use only', 'صرف اندرونی استعمال')`. Never reads the UI
  catalogue. Note: the fallback Urdu wording is provisional — the server can override it
  via the `internal_use` frame, and office review is still pending (flagged, not
  invented into the catalogue).
- `authorized_output.dart`: added the pure-presentation helper
  `isBalanceDueKey(key)` (`contains('outstanding') || endsWith('_due')`), shared by the
  PDF, Excel, and preview totals strips. No parsing, validation, or redaction change.

### 6. Document screens (`document_workspace.dart`)
Read and assessed: issued-documents list already has search, empty state, pagination,
and stacked labels; `IssuedDocumentView` reuses `OutputPreview` (inherits the totals
highlight). No change required; left untouched.

## Verification

### Analyzer
- `flutter analyze --no-pub` (from `app/`): the first run during this phase reported
  28 errors, ALL in files owned by concurrently working agents
  (`lib/app/ui_catalogue.dart` duplicate definitions mid-edit,
  `lib/features/finance/payment_workspace.dart` undefined method + unused import,
  `lib/features/trips/trip_workspace.dart` mid-edit). Zero issues in the seven Phase 7
  files (verified by grepping the analyzer output for `reports/` paths — no hits).
- Final run after the sibling agents settled: **1 warning, in the sibling-owned
  `test/expense_phase5_test.dart` (unused import)**. All of `lib/` is clean; nothing in
  Phase 7 files. Left for its owner; recorded here, not fixed here.

### Tests
- `flutter test --no-pub test/output_export_test.dart` — 5/5 PASS (legacy v1
  renderers untouched; `authorized_output.dart` change safe).
- Combined Phase 7 suite
  `flutter test --no-pub --dart-define=use_arabic=true test/report_workspace_test.dart test/output_workspace_test.dart test/output_service_test.dart test/output_export_test.dart test/bilingual_output_test.dart test/document_workspace_test.dart`
  — first full run: 18 pass / 1 fail (see failure below).
- Scratch renderer verification (temporary `test/phase7_scratch_verify_test.dart`,
  deleted after the run; built v2 payloads without the UI catalogue so the sibling's
  mid-edit `ui_catalogue.dart` could not block it):
  - owner-statement v2 PDF renders (`%PDF-` header, >1000 bytes) and XLSX keeps amounts
    as real numbers with the totals strip at the end (label cells `s="5"`, money totals
    `s="7"`),
  - customer-statement v2 highlights the outstanding row (`s="9"`, `FFEAF4ED` fill
    present in `styles.xml`, frozen pane intact),
  - optional `internal_use` presentation frame overrides the frozen fallback; without
    it the fallback `Internal use only / صرف اندرونی استعمال` is used,
  - 4/4 PASS. Sample files written to `tools/.local/karvaan-documents-phase7/`
    (`phase7_owner_statement.pdf/.xlsx`, `phase7_customer_statement.pdf/.xlsx`).
- XLSX structure spot-checked with Python `zipfile`: title row, scope rows, frozen
  header row (bold, no fill), data row with `<v>95000.00</v>` real numbers, totals
  caption, totals strip (bold; outstanding highlighted), continuation note.
- PDF spot-checked with `pdftotext`: wordmark + stacked title + scope line
  (`Synthetic office zero · 2026-10-01 to 2026-10-31`) + generated-on timestamp in the
  header; hairline table; totals strip (`Authoritative summary` + three totals) at the
  end; footer with `Page 1 of 2`, `Internal use only / صرف اندرونی استعمال`,
  `Current authorized records`, `Synthetic issuer · 2026-10-19T12:00:00Z`.

### Failure and fixes (all in the new dashboard widget test)
1. First failure: after tapping a KPI card, `find.text('T14-DRAFT-1')` found nothing.
   Root cause was a TEST harness issue: the 800×600 test viewport left the fourth KPI
   card below the fold, so `t.tap` missed (hit-test warning) — no app bug. Fixed by
   scrolling to the target before tapping (`ensureVisible`).
2. Second failure: `RenderFlex overflowed by 15px` — a REAL app bug found by the test:
   `TripStatusBadge` (stacked bilingual, ~47px tall) was used as `trailing:` in a dense
   `BilingualListTile`, whose trailing slot is capped at 32px. Fixed in
   `report_workspace.dart` by moving the badge into the title `Row` (unconstrained
   slot) instead of `trailing`.
3. Third failure: `Bad state: No element` on `ensureVisible(englishTextContaining('Reports'))`
   after a drill-down opened. Root cause was another TEST harness issue, not an app
   bug: `ensureVisible` scrolled the ListView, and the scrolling sliver unmounted the
   far-offscreen 'Reports' button, so the finder legitimately matched nothing.
   Fixed by giving the test a tall viewport (800×1400, with tearDown reset) so all
   cards and the button stay mounted, and dropping `ensureVisible`.
   Debug probe file `test/zz_debug_probe_test.dart` was deleted after use.
4. During the runs, two standalone reruns failed to COMPILE because sibling agents
   were mid-edit in `lib/features/trips/trip_workspace.dart` (`accountPurposeLabel`
   used before definition) and `lib/app/ui_catalogue.dart` (duplicate definitions).
   Not Phase 7 files; not touched. Reran after they settled.

### Final test run
`flutter test --no-pub --dart-define=use_arabic=true test/report_workspace_test.dart test/output_workspace_test.dart test/output_service_test.dart test/output_export_test.dart test/bilingual_output_test.dart test/document_workspace_test.dart`
→ **20/20 PASS** (report_workspace 2, output_workspace 6, output_service 1,
output_export 5, bilingual_output 4, document_workspace 3), ~85s. The v2 PDF/XLSX
render paths, frozen-label guards, redaction, formula-safety, and reprint flows all
green — no logic-side movement.

## Intentionally left out
- No new template_version bump: the backend assigns `template_version`; v2 remains the
  "new template version" for newly issued documents vs the untouched v1 legacy
  renderers. Caveat: any v2 documents issued during local QA BEFORE this restyle would
  reprint in the new format (test-only synthetic documents; no production issuance
  exists on this branch).
- No catalogue additions: all needed strings already existed; the two Latin-digit
  period tags need no translation.
- `document_workspace.dart`: assessed, no change needed (list + reprint view already
  pattern-conformant; reprint inherits the preview totals highlight).
- No visual screenshot QA claimed: verification is widget/unit tests plus text-level
  inspection of generated PDF/XLSX (`pdftotext`, `zipfile`). The typography evidence
  convention's screenshot suites belong to Phase 10.
- Backend-dependent improvement NOT attempted: a server-supplied `internal_use` frame
  is supported optionally, but wiring it needs a backend presentation change — flagged
  for the backend owner, not improvised here.

## Files changed (uncommitted, per instructions)
- `app/lib/features/reports/report_workspace.dart` — KPI-first dashboard + builder page
- `app/lib/features/reports/output_workspace.dart` — preview totals highlight
- `app/lib/features/reports/output_pdf_v2.dart` — report-format restyle
- `app/lib/features/reports/output_xlsx_v2.dart` — report-format restyle
- `app/lib/features/reports/bilingual_output.dart` — optional `internal_use` frame
- `app/lib/features/reports/authorized_output.dart` — `isBalanceDueKey` helper
- `app/test/report_workspace_test.dart` — dashboard test rewritten for KPI cards
- `docs/karvaan-restructure-phase7.md` — this file
- `tools/.local/karvaan-documents-phase7/` — generated samples (local only)
