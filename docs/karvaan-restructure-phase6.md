# Karvaan UI restructure — Phase 6 evidence (Money workspace)

Date: 2026-10-19. Branch: update/karvaan-restructure. Files touched (ONLY):
- app/lib/features/finance/payment_workspace.dart
- app/lib/features/finance/correction_workspace.dart
- app/lib/app/ui_catalogue.dart (additive only; duplicate removed, see below)
- tools/karvaan/phrases.json (origins merged; duplicate key removed)
- app/test/payment_workspace_test.dart (test-robustness only, see below)
No repository, RPC, migration, RLS, financial-calculation, or authorization
change. No commit; changes left uncommitted. No push/merge.

## Audit result: gaps found and filled
The Money section (TripWorkspace moneyMode → PaymentWorkspace) already had
per-trip paid-vs-outstanding. Implemented the Phase 6 gaps:

1. **Balances & custody view (QA fix).** New "Party claims and held money"
   KarvaanSection at the top of PaymentWorkspace (summary-first):
   - Hero figure: total intermediary-held money (CUSTODY_RECEIVABLE) across
     all loaded trips — KarvaanMetric hero (display size), tabular figures.
   - Per-party balance rows beneath: money-state chip + party · trip number +
     PaperTrailAmount. Each figure deep-links to its source trip (tapping
     re-scopes the workspace to that trip via _focusTrip; the trip's balances
     card below is the record). Rows sorted held → outstanding → credit →
     payables. Zero balances skipped. Empty state when no ledger loaded.
   - Aggregation is presentation-only sums of already-fetched
     get_trip_financials ledgers (_heldPaisa/_balanceLines); posting,
     allocation, and correction logic untouched.
2. **Money-state chips (stacked bilingual).** New MoneyStateChip widget +
   accountPurposeLabel(): the old English-only accountLabel() is replaced by a
   bilingual switch over the branch catalogue/glossary terms (Held funds /
   رقم زیرِ تحویل, Customer outstanding, Owner settlement, Commission due,
   Personal funding due, Customer credit, Expense reimbursement due, Cost
   recovery). Money-green family only (held = filled accent; others on the
   #EAF4ED outstanding highlight) — blue stays reserved for movement.
   Used in the summary rows, the per-trip balance cards, and the claim-picker
   dropdown items.
3. **Paper-trail amounts.** Summary rows → source trip (see 1). Correction
   history rows: the recorded amount is now a PaperTrailAmount (tabular,
   money-green) tapping into that record's correction review form
   (_historyCard); the event label + date stay as the title. No dead-end
   money figures remain in these two files.
4. **Empty states.** _PartyPicker, _TripPicker (payment workspace) and
   _CorrectionTripPicker now show L10n.noRecordsFound on zero results.
   Correction history already had one; balances summary has one.
5. **Physical-vs-financial separation.** Both existing disclaimers retained
   verbatim (permitted-trips scope; collections/held/settlement/earnings
   separate; arrival ≠ payment on the review step).

## Catalogue changes
- ui_catalogue.dart: hand-appended expenseReimbursementDue,
  personalFundingDue, costRecovery (+ Accessibility consts + values entries).
  commissionDue already existed (presentation.commissionDue, identical
  wording) — my duplicate removed; the other three were consolidated by the
  concurrent Phase 5 worker with identical wording; verified each name now
  appears exactly once (Bilingual + Accessibility). generate_catalogue.py NOT
  run.
- phrases.json: merged a duplicate commissionDue key (kept the HEAD entry,
  unioned origins); 867 unique keys, valid JSON.

## Deliberately NOT implemented (flagged, need backend)
1. **Aging bands.** STOP per spec: get_trip_financials exposes claims with
   effective_date only — no due dates, no credit terms, no aging buckets
   anywhere in the repository/RPC surface. Building bands from effective_date
   would invent the calculation. The AgingBand/AgingBandStrip pattern widgets
   (Phase 0) and catalogue strings (agingNotYetDue…agingOver90Days) are ready
   for when the backend exposes due-date aging.
2. **Most-used-first pickers.** list_master_records returns name-ordered
   pages with no usage counts; a "most used" ordering needs a backend change.
   Pickers stay searchable (existing pattern); code comment + this note flag it.
3. **released/settled money states.** The ledger exposes open claims
   (remaining > 0) and balances; no released/settled states exist in the data
   model. Chips cover the states the data carries (held, outstanding, due,
   credit).
4. **Deep-link to the trip detail's Money tab.** TripDetail (owned by the
   trips worker) has no initial-tab parameter and requires onEdit — not
   constructible from these files. Paper-trail targets the in-scope record
   instead (source trip's balances; correction review form). NOTE for
   coordination: trip_workspace.dart (concurrent worker, mid-edit at time of
   writing) calls accountPurposeLabel() expecting it in scope — the top-level
   function in payment_workspace.dart is intentionally kept public and
   name-stable for that import.

## Verification (actual outputs)
- `flutter analyze --no-pub` on the four touched files: **No issues found.**
  (Whole-app analyze shows 6 issues, all in other workers' in-progress files:
  trip_workspace.dart undefined named params, expense_phase5_test unused
  import, phase7 scratch test await error — none in Phase 6 scope.)
- Tests (all 6 suites, 19 tests): **All tests passed.**
  - payment_workspace_test, payment_model_test, correction_workspace_test,
    web_money_test, display_format_qa_test, financial_contract_test —
    financial contract suite green (no logic moved).

## Failures encountered and fixed
1. Duplicate `commissionDue` consts (mine vs pre-existing) broke compilation
   of the test suite (3 files failed to load). Fixed by deleting my duplicate;
   verified each catalogue name appears exactly once.
2. After adding the summary section, 2 payment_workspace tests failed: the
   taller screen pushed the payer button / Confirm button below the test
   viewport fold (finders default skipOffstage=true), and the lingering
   "Payment confirmed" snackbar covered the Review button on the second
   prepare. Fixed in the TEST file only (no production change): scroll
   below-fold targets into view with skipOffstage:false finders before
   tapping; let the confirmation snackbar time out before re-preparing.
   Test intent unchanged.
3. phrases.json duplicate commissionDue key (pre-existing in working tree
   from concurrent edits) merged; JSON validity verified.

## Open / intentionally left out
- Totals strip: the balances summary IS the totals strip; per-trip cards keep
  individual balances (no per-card totals strip — would duplicate the summary).
- Correction history: no totals strip (heterogeneous event kinds — a sum would
  mislead); no money-state chips (events carry kind/reversed, not money states).
- Review-step and form-input amounts stay plain text (computed from inputs,
  not record figures — not paper-trail candidates).
- 200% text-scale / RTL visual QA of the new section is a Phase 10 item.
