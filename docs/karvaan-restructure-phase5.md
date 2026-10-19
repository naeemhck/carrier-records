# Karvaan UI restructure — Phase 5 evidence (expense entry + expense list)

Date: 2026-10-19. Branch: update/karvaan-restructure @ 5b9d8cb. No commit made (per task); changes uncommitted.

## Baseline / audit result
The branch already had the four ExpenseEntry cards (What / Whose money / Where / Proof as
KarvaanSection with L10n.whatSection etc.), searchable pickers (server-side search on submit),
the receipt upload flow, and review/confirm with idempotent request UUIDs. Phase 5 therefore
implemented only the gaps below; no validation rule, posting logic, settlement/reimbursement
logic, repository, RPC, or financial calculation was touched.

## Scope — app/lib/features/expenses/expense_workspace.dart (only file edited)

1. ExpenseEntry form
   - Four-card grouping verified complete: What (category, date, amount, notes), Whose money
     (payer, cost bearer, funding source, agreed checkbox, allocation inputs), Where (vehicle,
     trip link, office), Proof (receipt picker + status). No regrouping was needed.
   - Figure leads on money: the amount input already used displaySmall (30px, tabular, LTR).
     Added a small live caption beneath it (`amountFigure()`) showing the typed value formatted
     via displayMoney(Money.parse(...)) (e.g. "PKR 10,000.00"). Shown only while the text parses
     as money; invalid input shows nothing and is still reported by review validation exactly
     as before. Label economy kept: one stacked label per field, no echoing helper text.
2. Pickers — _MasterPicker and _TripPicker
   - Already searchable; extended (not replaced) with most-used-first: new public
     `PickerUsage` helper keeps a session-local pick-count map per master kind (`<code>:<id>`)
     and per trip id. `promoteMasters`/`promoteTrips` reorder the loaded page so the 5 most-used
     items (count descending) lead, the rest keep server order. No repository/RPC change and no
     extra requests — impossible to order by true server-side usage without a backend change,
     so session-local usage is the honest presentation-only approximation (flagged, not hidden).
   - A "Most used" caption header (L10n.mostUsed) leads the promoted rows; a divider separates
     them from the rest.
   - Both pickers now have an empty state: one guidance line (L10n.noRecordsFound) plus a
     "Clear search" action (L10n.clearSearch) that clears the query and reloads.
   - Usage is recorded on select in both pickers (so ExpenseSettlement's party picker, which
     reuses `chooseExpenseMaster`, also benefits).
3. Expense list (Phase 6 patterns applied to this file's ExpenseWorkspace)
   - Status chips per row via new `ExpenseStatusChip` (mirrors TripStatusBadge): Active
     (L10n.expenseActive, money green #0B5C2E on #EAF4ED) vs Historical — voided or replaced
     (L10n.expenseHistorical, neutral). Blue=movement/green=money rule: expenses are money, so
     active expenses use the money-green family, never blue.
   - Summary-first: a solid (non-glass) totals strip Card sits above the rows showing the
     current-page subtotal as a hero figure (KarvaanMetric, tabular, LTR) with its caption
     beneath (L10n.pageExpensesTotal = "Expenses total · this page") plus the "{n} records ·
     Page {p}" count (reused L10n.recordsPage). The label deliberately says "this page" — it
     is a client-side sum of the displayed rows (exact BigInt paisa arithmetic via
     AllocationTotals.sum, formatted with displayMoney), never an authoritative ledger total.
     Hidden when rows are empty or any shown row is unparseable.
   - Tabular numerals: all amounts already flow through KarvaanAmount/KarvaanMetric →
     KarvaanFigure with the shared tabular text theme; verified unchanged.
   - Empty state: the bare noRecordsFound line is now guidance + a "Record expense" action
     (L10n.recordExpense) opening the same ExpenseEntry as the primary New expense button.

## Catalogue — 5 new strings
Appended to tools/karvaan/phrases.json (origins ["ui-restructure-phase5"]) and hand-appended to
app/lib/app/ui_catalogue.dart (Bilingual const + Accessibility const + values-list entry);
generate_catalogue.py NOT run (it destroys hand-maintained Accessibility constants):
mostUsed, clearSearch, expenseActive, expenseHistorical, pageExpensesTotal.
Terminology grounding: expenseActive "فعال" is glossary-approved (Active → فعال);
expenseHistorical "پرانا" reuses the catalogue's own "پرانا خرچ" wording for voided/replaced
expenses. mostUsed "سب سے زیادہ استعمال شدہ", clearSearch "تلاش صاف کریں" and
pageExpensesTotal "اس صفحے کے اخراجات کا کل" are PROVISIONAL (no glossary term) and need
office review — the Urdu wording is marked provisional here, not presented as approved.

## Verification — BLOCKED by concurrent-agent overlap (see below)
- `flutter analyze --no-pub` (186.1s): 17 issues, ZERO in Phase 5 files. All 16 errors are
  duplicate_definition in app/lib/app/ui_catalogue.dart:5360–5386 — a concurrent Phase 6
  (Money workspace) agent re-added `commissionDue`, `expenseReimbursementDue`,
  `personalFundingDue`, `costRecovery`, which already existed (e.g. `expenseReimbursementDue`
  at line 4426, `commissionDue` at 4757, predating my edits); their block is marked
  "// Phase 6 (Money workspace)". The 17th issue (unused import in
  lib/features/finance/payment_workspace.dart) is also in that agent's scope. My five new
  strings are each defined exactly once; my files are analyze-clean.
- `flutter test --no-pub test/expense_phase5_test.dart`: FAILS TO COMPILE — same
  ui_catalogue.dart duplicates ("'commissionDue' is already declared in this scope"). New test
  file written (6 cases: amount figure caption show/hide, master promotion order, trip
  promotion order + 5-cap, picker dialog most-used section + ordering, list page total/chips/
  page count, empty-state guidance + action) but NOT RUN — no pass is claimed.
- Required existing suites NOT RUN for the same reason:
  test/expense_workspace_test.dart, test/gui_expense_groups_test.dart,
  test/expense_model_test.dart, test/display_format_qa_test.dart.
- No test was marked passed that did not run.

## Intentionally left out
- TimestampFooter on expense rows: list_expenses returns no created/updated stamps and no
  backend change is allowed — nothing to show.
- Receipt-attachment state chip: not derivable from the list rows without a download attempt;
  the existing per-row receipt button behavior is unchanged.
- True server-side usage ordering for pickers: would need an RPC/migration change — out of
  scope; session-local counts are the documented approximation.
- Funding-source key display (`BilingualOwnedText(row['funding_source'])` shows the raw key):
  pre-existing presentation, left untouched as out of Phase 5 scope.
- The old bare `L10n.noRecordsFound` in pickers/workspace was replaced by the empty states
  above; no other behavioral changes.

## Action needed (parent)
Resolve the ui_catalogue.dart duplicate definitions from the concurrent Phase 6 work
(delete or rename their re-added block at ~5360–5386), then re-run:
`flutter analyze --no-pub` and
`flutter test --no-pub test/expense_phase5_test.dart test/expense_workspace_test.dart test/gui_expense_groups_test.dart test/expense_model_test.dart test/display_format_qa_test.dart`.
Phase 5 implementation is complete and uncommitted; verification is pending that fix.

## Post-handoff verification (parent, 2026-10-19)
The `commissionDue` duplicate blocking compilation was removed by the Phase 8 worker. Re-ran the 5 suites: `flutter test --no-pub test/expense_phase5_test.dart test/expense_workspace_test.dart test/gui_expense_groups_test.dart test/expense_model_test.dart test/display_format_qa_test.dart` — 21/21 PASS (was 19/21).

Two failures were test bugs, not app bugs (app code unchanged):
1. `trip picker promotes the most-used trip first, capped at five`: expected `rows.last == 'cap-0'`; correct per the documented contract ("everything else in server order") is `'cap-2'` — after promoting [cap-7..cap-3], the remainder in server order is [cap-0, cap-1, cap-2]. Fixed the expectation.
2. `expense list shows page total, status chips and page count`: `find.text('Historical')` found nothing because e2's card renders below the 800x600 test viewport fold and the default finder skips offstage widgets (verified via tree dump: the card and chip render correctly). Fixed with `skipOffstage: false`.
