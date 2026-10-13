# Karvaan local update verification — 2026-10-13

## UI checkpoint continuation — 2026-10-13

The append-only catalogue now has785 entries, retaining the original554 semantic keys and English wording. Added source-owned code labels, validation and dynamic frames are provisional; user identities/notes and financial values remain opaque. Reports wording (رپورٹیں versus رپورٹس), print کنسائنمنٹ versus مال, offsets/recovery terminology, and car versus carrier vehicle remain office-review items.

Actual pre-checkpoint failures: an early broad widget run was stopped after63 passes/25 failures caused by intrinsic-size/layout failures; it was not a pass. BilingualText now uses intrinsic-safe Wrap and form labels use a native English floating label plus wrapped Urdu helper. Table labels receive bounded widths, narrow tiles place actions below titles, and dialogs scroll. Fresh focused screen/report run12 PASS checked320/1280 widths, scales1/2, joined Urdu, unchanged mixed user names, dropdown/Escape, invalid dispatch/review/acknowledgement, selected-field order and revoked scope. Actual320/1280 font-loaded screenshots were visually inspected.

First full run for this continuation: analyzer0/no issues169.0s; Flutter98 PASS/7 FAIL214s. Failures were lazy controls/status messages below the viewport after taller bilingual labels and one exact English-only tooltip selector. Tests now scroll to controls and select bilingual tooltips while keeping accounting, retry, conflict and permission assertions. First focused rerun11 PASS/1 FAIL; the remaining backup status assertion needed scrolling back to the message. Fresh full rerun105 PASS/exit0 in266s. Formatting exposed5 curly-brace lint infos; fixed without changing behavior. Fresh analyzer no issues/exit0 in29.9s.

The candidate refuses the installed administrator backup helper before environment/file/process access; a regression verifies this fail-closed restriction. Native sign-in/logout checks pin the distinct backend identity before Supabase initialization and use unique protected test namespaces. Actual Windows sign-in/office home/protected logout PASS; native build538.7s, one integration test8s. Draft/lifecycle native verification is still pending at this checkpoint entry; fixture cleanup will be recorded when finished.

Read-only source/history credential audit with guarded local configuration:289 tracked files,38 intended untracked files,572 historical blobs, no findings/exit0. No staging/commit claim yet. Existing PDF/XLSX renderer files remain unchanged. No candidate installation, hosted calls, push, merge or deployment; T19 owner observations/waivers are preserved and T20 is not started.

Checkpoint native completion: actual draft list/detail/edit/overlap-review/save PASS (Windows build149.4s/test18s), with server-persisted correction verified. First lifecycle attempt built95.9s but failed before posting: the harness entered the reason and clicked Review before settling the new enabled frame, leaving no review acknowledgement; Cancel/Escape had preserved DRAFT. Added explicit unfocus/settle and enabled-button assertion; no product/backend rule relaxation. Fresh guarded lifecycle run exits0, Windows build73.2s/test14s PASS: impossible date disables Review, Escape and Cancel preserve server DRAFT, server review exposes joined Urdu acknowledgement, checked dispatch commits, destination staff arrives, exactly2 active consignments delivered and1 cancelled preserved, audit reason retained. Both harness runs remove synthetic Auth/business fixtures successfully. All three representative native workflows PASS; no development-PC result is labelled a clean-PC gate.

New original554-key/English SHA256 regression PASS; focused catalogue/screens12 PASS/exit0 in18s after that addition. Fingerprint1097229ad60e19dea0873f36dc35f8dc5ff74e73846c54be6a20776c7bc7cb33. Fonts Regular/Bold each cover100 catalogue glyphs and include init/medi/fina/rlig. NotoSansMath is bundled under its OFL license to cover the route arrow; original Latin assets are unchanged. Current AST review finds38 remaining plain Text/tooltip nodes, principally unchanged names/notes/codes and already bilingual tooltip expressions; import diagnostics and dynamic date-basis wording require further review. This is a verified UI checkpoint, not U04/U05/U06 completion.

Base main: a0bd553b6de18352f587cb1cc6fc662443f9178b. Separate managed worktree C:/Users/Naeem/.codex/worktrees/karvaan-bilingual/transport_project, branch update/karvaan-bilingual. Planning commit5f66707. No push, merge, deployment, candidate installation or hosted backend contact. T19 IN PROGRESS/T20 TODO remain unchanged.

## Isolation foundation

- Dedicated local Supabase project karvaan_bilingual_u20261013; bind preflight covers60320–60329 and18083. API60321/database60322/shadow60320; all19 existing migrations replay during first start. Existing transport_project containers/data are preserved; no reset command.
- Candidate default is local-only. Runtime checks APP_ENV=test, exact HTTP loopback/emulator host and60321 port, no alternative path/query/credentials, then requires project/purpose/port identity before session access. It does not load installed client.json. Candidate protected-store prefix differs from unchanged carrier.session production prefix.
- Guarded launcher requires ignored local defines with exactly APP_ENV, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, APP_BUSINESS_ID. Checks CLI/container/project identity, matching public key and synthetic business. Real fixture/config/launcher integration is pending; no app launch claimed yet.
- Two Dart policy tests PASS, including wrong hosted/local URLs, environment and forged identity. Three Python launcher tests PASS under `python -O`, proving validation is not dependent on assert statements and bad endpoints are rejected before network/status calls.
- Fresh guarded T03/trips/lifecycle/finance suite on this distinct empty local project exits0 with633 PASS checks and successful fixture cleanup. Includes authorization/direct requests, exact posting/concurrency and ten deferred commit failures/unchanged database snapshots. No hosted calls or native integration in that run.
- Analyzer before the bilingual-widget changes passes/no issues (217.8s). After widget implementation, nine focused Flutter tests PASS: narrow320/wide1280 layouts, typed opaque values/Latin digits, policy checks, production/candidate store separation and fail-closed storage errors. Full post-extraction analyzer/regressions/builds remain pending.

## Early typography prototype

Google official Noto Sans Arabic variable font downloaded with SIL OFL1.1 license; fontTools4.66.1 creates static width100 weights400/700. Source SHA63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e. Bundled font provenance records per-file hashes; original Latin assets retained. Prototype glyph coverage, including Urdu presentation forms, passes.

Actual Dart/pdf synthetic A4 prototype generated/rendered with bundled Poppler. Default bidi mode visibly changes mixed ISO date2026-10-13 into13-10-2026, so it is not acceptable for the new template. Explicit `use_arabic=true` prototype visually retains Latin date2026-10-13, amount125,000.00 and TRP-000001, joined Urdu accounting terms, and wrapped text. New-template layout must keep financial values in their own LTR runs and undergo full multi-page visual verification. Legacy renderer and Latin assets are untouched. This is an early prototype, not the completed export gate or hardware printing.

Prototype files/PNGs/logs remain ignored under tools/.local. No real records or identifying screenshots are included. System-font-free/physical-print/device checks are not claimed. Fonts/license are intended source assets; test credentials/configurations are not.

## Coverage and actual failures

- Initial presentation inventory:819 surfaces across32 files, including517 Text,70 InputDecoration/70 labelText,5 tooltips,98 FormatException and other containers/status surfaces. Direct first-argument literal inventory293 unique messages; dynamic/owned-field labels require separate extraction and data exemptions.
- Initial new-directory patch stopped at missing tooling parent directory; existing partial edits inspected, directory created only in worktree, remaining files applied.
- Two command-path mistakes (root tools path while cwd app) failed; corrected before dependency/test execution. Inventory sandbox write and Python stdout encoding failed once; authorized worktree write/UTF-8 corrected. No pass inferred from failed attempts.
- CLI completion emits local test credentials; safe logging now removes credential-bearing JSON/lines and original ignored progress log was sanitized. No production credentials/settings were read.
- Previous focused-test execution was rejected because automatic approval review hit a usage limit, not because the action was unsafe; no test executed then. After user continuation, the same authorized command executes and all9 focused tests pass.
- Optional pdffonts tool unavailable at bundled path; full PDF font-object inspection pending with local inspection dependencies. Never infer embedded/shaped success solely from glyph coverage.

U01 integrated launcher/config, U02 full branding/compatibility audit, U03 full catalogue/font/render tests, U04 UI extraction, U05 immutable bilingual exports, U06 builds/regressions and U07 handoff remain unfinished. No local review-ready candidate or completion claim yet.

## Catalogue checkpoint — 2026-10-13

All554 inventoried source-owned phrases now have provisional Urdu drafts, including dispatch acknowledgements, accounts, expenses, corrections, payments, imports and reports/documents. Generator emits typed constants with stable semantic keys; user-entered values remain opaque. This is catalogue coverage, not completed screen extraction or office terminology approval.

Actual validation: translation application reports554/554 and checks placeholder parity/Latin digits. Fresh focused Flutter run exits0 with10 tests PASS: all554 entries' unique semantic keys, placeholder parity and Latin digits;320/1280 layouts; opaque values; endpoint/identity policy; separated protected stores and logout/storage failures. `git diff --check` exits0. Full analyzer, screen extraction, snapshot/export regressions and candidate builds remain pending.

Failed attempts: inline Python split failed PowerShell quoting before any split; moved logic into generator and reran. Initial generated Dart used`return` as a symbol, causing formatter exit1 and focused-test compile failure (six unrelated tests passed). Generator now suffixes reserved symbols while preserving semantic key`ui.return`; formatting and fresh10-test run pass. Initial combined documentation patch failed a memory heading match and changed no files; corrected patch applied. Failed runs are not counted as successful verification.

Owner-supplied build6 QA/waivers are separate in docs/t19-owner-qa-20261013.md. No hosted revalidation/cleanup, push, merge, deployment, installation or production scheduling occurred. T19 IN PROGRESS under original gate; T20 TODO while local-only update continues.
