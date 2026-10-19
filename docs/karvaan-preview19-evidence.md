# Karvaan testing preview 19 — typography publication

2026-10-19 user authorization: update the existing testing link and back up the update branch. Production is protected. This is a work-in-progress testing preview, not production acceptance.

## Verified preparation

App source 2994aaa6e59f9e0fcf835b089bdd6ed2948211e0 on update/karvaan-bilingual, initially clean. App tree unchanged during preparation. Earlier source-pinned verification: analyzer zero issues97.8s, full Flutter224PASS/2m14s, no warnings; details in karvaan-typography-evidence.md. No new claim of native/device coverage.

Distinct QA web0.2.0+19 built successfully283.5s using existing public-only QA defines, Arabic enabled, no web resources CDN and no pubspec change. Existing candidate12/17 and QA13 hashes verified by prepare_qa_artifact; QA18 retained for rollback. Artifact tools/.local/qa-preview/artifacts/0.2.0+19/web;50files/46487991bytes. main.dart.js SHA25611efc3d7bad16d89ac36698908c261c7c2555bfd5a82883b90150adc702fc7d9. Artifact audit no findings; only compiled backend https://nxyjjjxvgibehovlyycx.supabase.co. Exact QA flags/identity/business/session isolation retained. No backend changes, passwords reset, migrations, functions, reseeding or deletions.

Fresh local Chromium on loopback8773: version and five served hashes match; TEST identity check succeeds; obscured wrong-password submission rejected safely with visible bilingual feedback. Narrow screenshot visually inspected: testing banner, Urdu joining/wrapping, error and button text readable. No browser errors, unexpected origins or business writes. Runner now accepts explicit version-matching evidence names and separate8773; write/backend guards retained; Node syntax check passes. Raw evidence under tools/.local/qa-preview/local19-public.

## Source backup checks

Fresh GitHub API confirms naeemhck/carrier-records PRIVATE, defaultmain, zero workflows and zero webhooks. Cloudflare both existing Pages projects have Git ProviderNo. Installed-app API returns403; fresh installed-app review requested from user. Push remains blocked pending this deployment-isolation verification. No main push/merge/release authorized.

Source/history scan reuses existing audit signature/filename rules and compares actual saved tester credentials only in memory:424current files/1082historical blobs/0findings. Full local-runtime-key comparison NOT RUN because local Docker/Supabase status fails; no full runtime-audit pass claimed. Ignored artifacts/config/passwords/data remain local, SQL source migrations/tests preserved. Raw sanitized report tools/.local/qa-preview/source19-audit.json.

## Deployment and remaining gates

Upload and fresh live verification PENDING at this preparation commit. Target only existing karvaan-test, branchqa-preview, pinned Wrangler4.149.0; preserve QA18 deployment7a706a39-9bb6-4148-a42a-078fdc709c1a for rollback.

Known account-access and unverified ready-user workflows/exports remain pending. Performance failures (last recorded screenp953.977s, summaryp957.453s and2summary57014errors), frozen-pagination defects, provisional terminology, native OS-input and Android-device limits remain unresolved. Preserve T19 acceptance/exceptions/waivers; T20 unstarted. No production installation, backend modification or scheduling changes.
