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
