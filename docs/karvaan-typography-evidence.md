# Local typography hierarchy evidence — 2026-10-17

Baseline: update/karvaan-bilingual at 58bcb28dffe9950d69c21e73de1668a9ddc94825, clean worktree. Existing candidate 12/17/QA18 artifacts retained. No backend, repository, RPC, migration, financial, document renderer/snapshot or hosted configuration change is authorized.

## Scope clarification
The prompt assumed a language toggle/full Urdu page mirror and density/label-economy specifications. Repository inventory found none: the actual branch uses stacked English/Urdu, global LTR with RTL Urdu runs. User explicitly selected **Typography only; retain stacked labels for now**. This task therefore verifies both text runs at 100%/200%, not a nonexistent locale-toggle/whole-page RTL implementation. No catalogue/glossary wording is changed. Existing explanatory financial/scope/security text remains; Urdu helpers are translations, not redundant label restatements.

## Group 1 — shared scale and monthly reports
One KarvaanTypography scale feeds TextTheme: hero 30, headline 22 (supporting figure 20), section 16/15, body/field label 13, caption 12, metadata 11 logical pixels. Numeric roles use tabular figures. Urdu uses bundled NotoSansArabic natural ascent/descent and a floor of 44/3 logical pixels (11pt at 96 logical pixels/inch), with user text scaling unrestricted. No compressed line height or fitted text scaling.

Report summary cards show the existing canonical figure first and the unchanged date-basis label underneath. One primary metric leads: vehicle/dashboard operating profit, owner/lifetime owner profit, claims customer outstanding. Other authorized totals remain separately labelled, never summed from page rows. Row values are compact and server pagination/filter calls unchanged.

First analyzer run FAILED: one unused test import, 75.1s. Removed that import; final rerun pending. Real-font hierarchy/screen tests and screenshots running; no pass claimed yet.

## Outstanding gates
Separate summary performance/timeouts, frozen pagination, unresolved terminology, native OS-input and Android-device checks remain unresolved. T19 acceptance/waivers unchanged; T20 unstarted. No build, native run, push, merge, installation, deployment or hosted backend access is claimed by this task.

Group 1 final commands/results:
- `tools/flutter.ps1 analyze --no-pub`: PASS, no issues, 31.4s (after removing the unused test import). Logs: tools/.local/typography-g1-analyze.log and typography-g1-analyze-fixed.log.
- `tools/flutter.ps1 test --no-pub --dart-define=TEXT_QA_PHASE=typography-g1 test/typography_hierarchy_test.dart test/report_workspace_test.dart test/bilingual_widget_test.dart test/text_layout_qa_test.dart test/gui_foundation_test.dart`: PASS, 25 tests, 36s. Actual synthetic widgets exercise report pagination/filter preservation, separate profit/due values, one hero, Latin figures, both language labels and natural Urdu metrics, authentication and role-aware navigation. No backend connection.
- Captures: tools/.local/text-qa/widgets/typography-g1/. Visually inspected monthly-hierarchy-1280.0-1.0.png and monthly-hierarchy-360.0-2.0.png: hero above captions, no clipped Urdu descenders/overlap. Large text requires vertical scrolling; no one-viewport fit is claimed at 200% or by hiding labels. Existing report period/scope/financial explanations are retained.

## Group 2 — trip totals and Money entry
Trip detail/review reuse TripTotalsStrip: customer charge is the sole optional hero, with brokerage and owner entitlement as separate supporting figures. Detail totals move above long metadata; existing lifecycle/settlement notices stay visible in the scroll flow. Money promotes only its explicit total amount input; authorized party balances remain separate. No new sums, queries, permissions, acknowledgement, concurrency, request or posting behavior.

Group 2 analyzer PASS: zero issues, 28.8s. First relevant test run exposed a harness error at 360px/200%: Money total TextField had not yet been lazily built below the fold, causing singleWhere/No element. Corrected the test to scroll the existing list until the real control is built and visible; no app size/label/permission restriction was weakened. Final affected rerun pending. One initial edit command did not execute because automatic approval review timed out; its single permitted retry succeeded, no safety rejection or partial edit.

First group 2 run completed with 38 passes / 3 failures (94s): two new Money tests queried lazy offscreen fields; the existing conflict test tapped Confirm after re-review without re-revealing it (hit test at y=1525 outside its viewport), then completed an unattached conflict future. Updated tests to reveal the actual control and pump layout before each tap; retained all retry UUID/body equality, no-false-success and conflict-disabled assertions. Product confirmation/state logic unchanged.

Visual failure found before group 2 commit: the 360px/200% trip hero wrapped the final decimal digit onto a third line. Corrected the shared figure presentation to one nonwrapping LTR value in a bounded horizontal scroll area with visible scrollbar when content exceeds width. No fitted/shrunken text, omitted digits or amount changes. Full value remains available to semantics; narrow views can scroll figures. Fresh rendered/test verification required after this source change.

Group 2 final verification:
- Corrected full affected group: 41 PASS in 58s (`typography-g2-tests-fixed.log`), including actual widget save/review/retry/conflict and dispatch-dismissal interactions. Source was subsequently finalized for nonwrapping figures; this earlier run alone does not verify that last change.
- Final stable-source analyzer: no issues, 22.8s (`typography-g2-analyze-final.log`).
- Final stable-source hierarchy screen suite: 13 PASS in 13s (`typography-g2-tests-final.log`), after the figure source and test-format changes. Monthly, trip and Money at360/1280 and100%/200% with both text runs; canonical values100000/5000/95000 retained, no posting, one hero, horizontal scroll reachable without changing font scale.
- Visually inspected trip desktop/narrow and Money desktop captures; fresh final360/200 trip capture confirms decimal digits stay on one line with an actual scrollbar (captured after horizontal scroll). At narrow200%, the full hero cannot fit simultaneously; users scroll horizontally, and the view vertically. This is an explicit review limitation, not a claim of one-viewport fit. Existing long route-name wrapping at this size is flagged for a future layout review; no wording or route order changed.
- Screenshots: tools/.local/text-qa/widgets/typography-g2-final/. Full final regression after the remaining presentation sweep is still required.
