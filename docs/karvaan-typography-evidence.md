# Local typography hierarchy evidence — 2026-10-17; final verification 2026-10-19

Current disposition: groups 1–3 implemented and verified at the Flutter framework level. Final source-pinned analyzer has zero issues; all224Flutter tests pass. Review constraints below remain explicit; no new native/browser release build or deployment is claimed. Earlier failed attempts and their repairs are retained chronologically.

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

## Group 3 — remaining headings, forms and final regression
Remaining24px authentication headings now use shared22px screen role; sidebar branding/preview section title use16px section role; duplicated list heading demoted below the app-bar title. Tables/list rows/dialogs/tooltips share the central scale. Expense entry emphasizes the explicit amount input, with unchanged validation/review/upload behavior. Lists have no fabricated aggregate hero; individual entries remain supporting figures when no authoritative screen total exists.

Added36actual-screen rendering cases (nine screens × two widths × two scales), both stacked runs. First combined root-directory analyzer invocation used an incorrect relative wrapper path and DID NOT RUN; no pass inferred from its shell exit code. Correct app-directory analyzer then reported one test-only curly-braces lint (17.4s), corrected without suppression; final rerun pending. Existing synthetic unit PDF/XLSX/widget samples copied locally before the full regression so its generated output cannot erase previous review evidence. Immutable candidate artifacts remain untouched.

First final full-suite attempt retained under typography-final-tests.log. Command omitted the documented `--dart-define=use_arabic=true`; frozen v2 correctly rejected PDF generation with “Arabic shaping must be enabled for template 2.” Renderer/font guards remain unchanged; rerun must set the existing required build flag. Old control-layout test at320/200 queried a New expense button before its lazy body built it; now scrolls to the actual control. Old disabled-backup test attempted its tap before the post-scroll layout settled (y628 outside600px root); now pumps and explicitly asserts the target lies inside the viewport. No tap-warning suppression or application helper restriction change. Full final rerun pending.

The first full run also reproduced a real67px trip-editor Column overflow at320px/200% after required-journey validation. Bounded the existing action area to40% of available Scaffold height with vertical scroll; the existing step-header area now flexes/scrolls rather than taking unbounded height from the body. All fields, labels, step/review/save callbacks and error guards retained. No font-size/validation reduction. This is a limited presentation layout repair, not a new workflow. New36-case natural-metric test initially failed its200% cases because it recreated paragraphs with the outer scale and resulting text-box width rather than each actual RenderParagraph configuration/layout constraint. It now measures the actual span, text scaler, locale/strut/height behavior and parent max width; natural-height assertion remains. The failed run is retained, not promoted to a pass.

Final layout scope narrowed to the bounded/scrollable action area only; the original step header remains unchanged. No additional header scroll surface or navigation change is retained. The validation-overflow regression will determine whether this minimal repair suffices at the documented narrow200% size; no unexecuted short-window pass is claimed. First complete suite ended201passes/21failures in4m44s (18new metric-test configuration failures, missing Arabic flag, one lazy control and one real validation overflow); all failures retained.

Focused diagnosis (typography-diagnostic-tests.log): all4trip creator width/scale validation cases PASS after the minimal final footer repair; output360/200 still failed. Actual offending text was the Urdu Outputs and presets title, inherited toolbar softWrap=false, maxLines=null, maxWidth328 and effective text scale1.34. This was a real title wrapping defect, not removed from assertions. Shared BilingualText now defaults to wrapping/clip rather than inheriting toolbar no-wrap/ellipsis (explicit caller choices retained). Added an inherited-no-wrap regression. The Flutter toolbar's existing1.34 scale clamp is retained and recorded: these are screens requested at200% with body scaling2, not a claim that the framework toolbar itself reaches2. No typography or layout rule is relaxed to hide this distinction. Focused run before that fix:4pass/1failure12s; preceding temporary header experiment run53pass/4fail37s is superseded, not a pass for final source.

Visual color follow-up: new caption role initially inherited Theme bodySmall foreground instead of the action foreground, making primary-button captions dark on green. Changed only the default caption role to the color-free central typography token, preserving the surrounding button/disabled/danger foreground. Added an actual RenderParagraph color regression for both languages on a FilledButton. This source follow-up requires fresh verification; no older screen pass is substituted.

## Final stable-source verification — 2026-10-19

No app/test source changed during this last run. SHA-256 comparison of all106app/test/package files before and after passed; tools/.local/typography-final-source.json and typography-final-verification.json preserve the exact file identities.

| Check | Actual result |
|---|---|
| `tools/flutter.ps1 analyze --no-pub`, from app/ | PASS, zero issues,97.8s; typography-final-20261019-analyze.log |
| `tools/flutter.ps1 test --no-pub --dart-define=use_arabic=true --dart-define=TEXT_QA_PHASE=typography-final-20261019`, from app/ | PASS,224tests,2m14s; typography-final-20261019-tests.log;0test warnings/errors |
| New rendered coverage |36form/list cases across9screens, widths360/1280, scales1/2; hierarchy suite includes12report/trip/Money matrix cases plus shared-scale, no-wrap and foreground tests |
| Earlier independent foreground/no-wrap run |2PASS,1s; typography-foreground-tests.log |
| Protected source diff from58bcb28 | Empty for catalogue, interpolation/formatters, fonts/assets, domain/money, repositories, Auth implementation, Supabase, frozen PDF/XLSX/authorized export services |
| Preserved artifact hashes | Candidate12:84files; candidate17:88; QA13:49; QA18:50; all size/SHA-256 checks PASS |
| Previous synthetic samples |51original files restored byte-for-byte after copying fresh regression output separately |
| Main | Remains a0bd553b6de18352f587cb1cc6fc662443f9178b |

The preceding full run ended223passes/1failure in3m50s, at the newly added foreground test while caption source was being finalized. It is retained as a failed run (typography-verified-tests.log), not counted as verification of final source. The fresh source-pinned run above is the final result. SDK printed a newer-version notice; no SDK upgrade or package change was performed.

Screenshots at tools/.local/text-qa/widgets/typography-final-20261019/. Fresh actual visual inspection: monthly-hierarchy-1280.0-1.0.png, form-output-configuration-360.0-2.0.png (complete wrapping title), money-hierarchy-1280.0-1.0.png (white action captions), form-expense-entry-1280.0-1.0.png (one explicit input total), auth-error-360.0-2.0.png and expense-ui.whatSection-320.0-2.0.png. Scroll-state captures can show content above/below the viewport; this is not presented as a clipped glyph or a one-viewport fit.

Local review pack: tools/.local/typography-review-20261019/,65hashed files including12representative screenshots,51fresh synthetic regression/sample files, source-file hashes and review README. No compiled candidate was produced; existing versions/artifacts and installed apps remain intact. Files and manifest stay ignored/local.

Helper audit found only the shared wrapping Urdu translation helper, not an English label-restatement helper. It is retained under the user's stacked-label clarification. No catalogue strings were rewritten or removed. No money is recomputed for hierarchy, and no unauthorized aggregate is invented for list views without an authoritative total.

## Review limitations and handoff

- User explicitly retained stacked labels, globalLTR and UrduRTL runs. A language toggle/full page mirror is outside this follow-up.
- At narrow200%, long canonical hero figures require horizontal scroll and content requires vertical scroll. Long route-name wrapping is flagged; no broad redesign or wording change is hidden in this task. Shorter native windows require actual review rather than an invented pass.
- Flutter's existing toolbar scaling clamp is1.34; body requested scale2 is tested, not falsely described as a fully2x toolbar. The wrapping fix removes actual title truncation at the tested viewport.
- Verification is actual real-font Flutter widgets with synthetic repositories. Native OS-input, installation, Android-device and physical equipment checks were not executed by this typography task. No new Windows/web/Android build or candidate runtime claim.
- Existing account-access/live-workflow blockers, performance/timeouts, frozen-template pagination, provisional terminology and device limits remain open. No performance rerun or target relaxation; T19 dispositions preserved and T20 unstarted.
- No push, merge, production installation, deployment or hosted-backend access. Local source commits:295a816(group1),3b15a23(group2), and the final group3 commit containing this record.

Final supplemental credential check: the existing runtime-backed `source_backup_audit.py --karvaan-local` FAILED before scanning because local CLI status returned1. Sanitized diagnosis confirms the CLI exists and reports Docker named-pipe/connection errors; no container stop/reset/restart or hosted fallback was attempted. This is not recorded as a fresh full audit pass. An independent read-only static scan using the existing auditor's exact signature and sensitive-filename rules scanned424current intended files and1,065reachable historical blobs, with0findings. Its exact-local-key comparison remains NOT RUN. Prior complete audit evidence stays historical. Details: tools/.local/typography-static-source-audit.json. No push is authorized or performed.

The typography remains source-only: pubspec/version and all prior artifacts unchanged. Existing installed/native candidates and QA18 do not contain these new source changes; no old artifact is relabelled or promoted. Any future build must reserve a new unused candidate version under its own authorization/review.
