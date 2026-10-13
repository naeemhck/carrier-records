# Karvaan local update verification — 2026-10-13

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
