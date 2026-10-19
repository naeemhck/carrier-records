# Karvaan UI restructure — Phase 3 evidence (trip creator / draft wizard)

Date: 2026-10-19. Branch: update/karvaan-restructure. No commit, push, merge, or branch switch. Only `app/lib/features/trips/trip_workspace.dart` touched (presentation only). `TripDraft` model and `TripStrings` API untouched; every validation rule, the overlap-review flow, and the fare-suggestion review behave exactly as before — only layout changed.

## Baseline & scope
The branch already had the 3-step editor with the custom step indicator. Phase 3 filled the QA gaps: end-to-end completability audit, floating action bar, searchable most-used pickers, keyboard support.

## What changed (TripEditor)
- **QA fix — wizard completable end-to-end**: audited step 1 (Journey) against `TripDraft.toJson()` validation — vehicle, driver, offices, route, schedule, and load kind are all present and reachable; no dead-ends at the presentation level. All validation rules carried unchanged.
- **Custom stepper kept** (not the Material default). The floating frosted action bar (`KarvaanGlass`) now holds **Cancel + Continue**, sticky while the form scrolls. Cancel pops the editor with no save attempt (verified by test: `repository.requests` stays empty).
- **Route defaults** remain reviewed suggestions, never silent replacements (existing behavior preserved).
- **_MasterChoice pickers**: extended, not replaced — now searchable, with the 5 most-used items first. Usage frequency is session-scoped (`static _usage` keyed by kind+role), most-used first then alphabetical; recorded on selection.
- **Keyboard**: `CallbackShortcuts` wraps the editor — Enter (incl. numpad Enter) advances steps 0→1→2, Esc goes back. Single-line text fields consume Enter themselves, so typing never advances mid-field. Step 2 keeps save as an explicit tap (Enter does not save).
- **Focus**: visible focus indicators via the theme; `moveStep` unfocuses on step change (dismisses the soft keyboard on Android — pre-existing behavior, retained).
- Layouts keep the existing scroll structure; no new overflow introduced (text-scaling survival verified by the existing trip_steps tests).

## Verification
- `flutter analyze --no-pub`: zero issues in touched files.
- New test "editor cancel pops without saving; keyboard steps move": Cancel pops with no save; `advanceKeyboard`/`backKeyboard` move 0→1→2→2 (clamped)→1; Esc from a focused text field bubbles through the editor shortcuts back to step 0. PASS.
- Full required suite: 33/33 PASS (incl. the pre-existing `trip_steps_test.dart`, `trip_draft_test.dart`, `trip_lifecycle_test.dart` — all validation/overlap/fare flows unchanged).
- Test-harness fixes (no app change): `moveStep` unfocuses on every step change, so the Esc test focuses a real text field first via `tester.showKeyboard` (a bare `tap` did not reliably focus it in the harness); shortcut bindings verified end-to-end through the actual key-event path, not just the handler methods.

## Intentionally left out / flagged
- Nothing in the validation, overlap-review, or fare-suggestion logic was altered. Any future request to change what the wizard *requires* (as opposed to how it lays out) is a product/backend decision, not presentation.
- The spec's `<language-toggle>` block is superseded (user decision 2026-10-19): stacked bilingual retained, no toggle.
