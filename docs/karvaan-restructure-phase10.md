# Karvaan UI restructure — Phase 10 evidence (verification)

Date: 2026-10-19. Branch: update/karvaan-restructure @ 193f886 (Phase 9).

## Gate results (all green)
- `flutter analyze --no-pub` (full app tree): **No issues found** (12.7s).
- Full Flutter suite `flutter test --no-pub --dart-define=use_arabic=true`: **235/235 PASS** (~4.5 min). The `use_arabic` define is the documented required build flag (docs/karvaan-gui-evidence.md, karvaan-typography-evidence.md): template-2 PDF generation refuses without it by design ("Arabic shaping must be enabled for template 2"), which is the single failure seen when the flag is omitted — not a renderer defect.
- `flutter build web --no-pub` (no dart-defines, compile check): **✓ Built build/web** (238.8s).
- Financial regression: `financial_contract_test.dart` (18 tests incl. AT-17 exact-paisa allocations, overconsumption/invalid-precision rejections), `payment_model_test.dart`, `expense_model_test.dart`, `web_money_test.dart` — all green inside the 235. **No logic-side movement.**
- Backend suites: no Python/SQL suite run — by construction there is nothing for them to cover. `git diff 01c6568..HEAD --name-only` shows changes ONLY in `app/lib/**` (presentation), `app/test/**`, `docs/**`, and `tools/karvaan/phrases.json`. Zero changes to `supabase/`, repositories, RPC surfaces, migrations, RLS, or calculations.

## Failures encountered during verification (all resolved)
1. Full-suite run without `--dart-define=use_arabic=true`: 234/235, single failure `bilingual_output_test.dart` "render actual compact, hidden and wide bilingual synthetic files" with the expected shaping-flag refusal. Resolved by using the documented required flag; rerun 235/235.
2. `test/expense_phase5_test.dart` unused import (`package:carrier_records/app/bilingual.dart`): removed; analyze clean.
3. Earlier in the phase work: two Phase 5 test bugs fixed (wrong `rows.last` expectation; offstage finder needing `skipOffstage: false`) — app code correct in both cases, verified via widget-tree dump. Recorded in docs/karvaan-restructure-phase5.md.

## Not claimed
- No visual QA on Windows/Android devices in this phase (widget tests at 320/360/800/1280px × 100%/200% text scale are the layout evidence; the parent handles the QA-preview build and visual verification).
- No PDF/Excel visual inspection beyond the structural checks recorded in Phase 7 (pdftotext header/scope/totals/footer, zipfile real-number amounts, frozen panes).
- Aging bands remain unimplemented (needs backend due-date aging — flagged in Phase 6, not improvised). Inline per-trip expense listing needs a trip-scoped expense query (flagged in Phase 4).

## Deliverable state
Branch `update/karvaan-restructure` contains Phases 0–10, each committed separately (see git log). Ready to push to origin. NEVER merge into main (per standing instruction).
