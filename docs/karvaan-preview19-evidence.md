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

Preparation originally recorded upload/live verification as pending; actual post-upload results follow below. Target only existing karvaan-test, branchqa-preview, pinned Wrangler4.149.0; preserve QA18 deployment7a706a39-9bb6-4148-a42a-078fdc709c1a for rollback.

Known account-access and unverified ready-user workflows/exports remain pending. Performance failures (last recorded screenp953.977s, summaryp957.453s and2summary57014errors), frozen-pagination defects, provisional terminology, native OS-input and Android-device limits remain unresolved. Preserve T19 acceptance/exceptions/waivers; T20 unstarted. No production installation, backend modification or scheduling changes.

## Actual publication and verification

Pinned Wrangler4.149.0 uploaded only karvaan-test/qa-preview:4new assets/44reused, headers/redirects uploaded, success. Deployment e8b7ecf4-d2b5-4788-92f7-bf775e3692a2; canonical https://karvaan-test.pages.dev/; immutable https://e8b7ecf4.karvaan-test.pages.dev/. Deployment metadata reports source2994aaa and branchqa-preview. EnvironmentProduction here means the default alias of the TEST project, not carrier-records. Manifest SHA256019270f59072c50a3dd9b9c3604dcd5181617222ebd44b7e3deb07f8e013e3a9. QA13/QA18 all49/50file hashes freshly checked unchanged after upload.

Fresh Node HTTPS fetches on both canonical and immutable sites: version0.2.0+19 and five asset SHA256 values match the audited artifact. Browser end-to-end checks did NOT pass: first canonical run hit ERR_QUIC_PROTOCOL_ERROR/TypeError and120s startup wait; staff run timed out navigating after30s. Diagnostic retry with Chrome QUIC disabled hit ERR_CONNECTION_RESET; immutable TCP retry also timed out navigating. All retained under live19-public, live19-staff, live19-public-tcp, live19-immutable-tcp. No observed non-TEST backend request or financial write; failed live browser startups observed only the TEST frontend origin. These attempts do not establish authenticated behavior or zero traffic outside the observed sessions. Local served browser did load and verify TEST identity/login feedback; that does not substitute for live authenticated acceptance. No app/backend configuration or security checks changed to mask failures.

Staff helper initially failed locally with KeyError temporary before any browser/login call: encrypted credential records now use handoff_temporary. Corrected helper reads that existing field only in memory; no reset/password disclosure. Its subsequent browser navigation failed before staff-login verification. Administrator, ready staff permissions/workflows and live exports remain unverified. Existing account-access caveats remain recorded; do not infer current credential validity from earlier runs.

GitHub backup NOT PUSHED. User reports installed apps ChatGPT Codex Connector and Muse AI, then answers Yes, or I am not sure about Muse push-triggered automation. API installed-app inspection403; guessed public app identifiers returned404 and did not establish identity/configuration. Deployment isolation therefore unresolved, despite private visibility, zero workflows/hooks and Cloudflare direct uploads. Do not push until Muse automation is verified disabled/unrelated. No integration permissions changed. Remote main a0bd553b6de18352f587cb1cc6fc662443f9178b and update branch76dcf71394b3b595b7e1fc331963f229a44adb4b freshly read unchanged. Local commits preserve all intended source/evidence. No GitHub backup success or remote equality claimed.

Follow-up: inspect Muse AI repository automation or temporarily suspend its repository access yourself, then confirm no push-triggered deployment; rerun privacy/isolation/audits before pushing only update/karvaan-bilingual. Open the testing link and manually confirm login/layout; retain failures until fresh live checks pass. No automatic rollback was applied because artifact hashes match and failures are transport-level, not a demonstrated app regression; QA18 remains available if needed.

## GitHub backup resumed — 2026-10-19

Owner clarification: GitHub has never performed automation. This supersedes the preceding uncertainty/hold; installed-app configuration is owner-reported, not falsely claimed API-inspected. Fresh checks confirm PRIVATE naeemhck/carrier-records, no workflows/webhooks, both Pages projects Git ProviderNo. Existing source-only branch push authorization remains in effect; no deployment, release or backend operation is part of this backup.

Fresh scan425source files/1091reachable historical blobs/0findings, including exact saved TEST credentials in memory. Full exact local-runtime-key comparison remains unavailable because Docker/Supabase is down; no full-runtime-audit pass claimed. Sensitive local data/artifacts remain ignored; reviewed SQL source retained. Prior main remote a0bd553b6de18352f587cb1cc6fc662443f9178b. Push only HEAD:refs/heads/update/karvaan-bilingual without force, then verify full remote equality. Actual push outcome will be retained in a separate ignored verification record and the user handoff. This source checkpoint remains WIP with performance/timeouts, frozen-pagination, account/live-workflow, terminology and device limitations unresolved; T19 dispositions intact/T20 unstarted.
