# Isolated hosted Karvaan testing preview

Authorized 2026-10-15 for a separate synthetic-only hosted TEST environment. This narrowly overrides the previous local-only rule for this deployment only. Production remains prohibited: no target changes to carrier-records.pages.dev, tuasxnfwrepbcelnrlgb, zuoaxtjfylfuwsxfbgzl, main, installed applications or scheduling. T20 remains unstarted.

## Current testing preview — 0.2.0+19 (2026-10-19)

Existing https://karvaan-test.pages.dev/ now serves typography source2994aaa6e59f9e0fcf835b089bdd6ed2948211e0 as distinct QA web0.2.0+19. Deployment e8b7ecf4-d2b5-4788-92f7-bf775e3692a2, immutable https://e8b7ecf4.karvaan-test.pages.dev/. Only existing synthetic TEST backend/configuration used; no backend/account changes. Source is the stacked-label typography update, not a language-toggle implementation. Artifact audit and local browser passed; live canonical/immutable version/five asset hashes match, but fresh Chrome startup checks failed with QUIC/reset/timeouts. Live login/permissions/exports remain unverified. Previous QA18 retained; no claim that known performance/pagination/account/device issues are resolved.

GitHub backup resumed after owner clarification that GitHub has never performed automation; fresh privacy/no-workflow/no-webhook/direct-upload checks confirmed. Installed-app API403 remains an API limitation, not an invented successful inspection. See preview19 evidence for the source-only backup sequence. Full results and exact hashes: [preview19 evidence](karvaan-preview19-evidence.md). T19 dispositions retained/T20 unstarted.

## Previous testing preview — 0.2.0+18 (2026-10-17)

Updated ONLY existing karvaan-test/qa-preview. URL https://karvaan-test.pages.dev/; immutable https://7a706a39.karvaan-test.pages.dev; deployment7a706a39-9bb6-4148-a42a-078fdc709c1a. Compiled verified sourcef1f492639e931d799831e1e16e2c0315a73f6d29, app tree identical to local candidate17; distinct QA-configured build18, not the localhost artifact. Public configuration/identity/allowlist/session prefix and bilingual banner preserved. No migrations/functions/configuration/password resets/reseed/delete. Previous4af214ed QA13 remains for rollback.

Analyzer/54affected regressions/artifact credential audit passed. Fresh live version/five asset hashes/TEST-only traffic, visible bilingual login/error screens and both staff login/assigned-office/first-password gates passed. Administrator current credential unavailable; staff require initial password setup. Ready-state permissions, authenticated trip formatting and new live PDF/Excel download/privacy checks remain PENDING, not inferred from deployment/local tests. Existing passwords were not changed/reset. Use only current known/saved credentials in the TEST app; if unavailable, recovery needs a separate authorization. Do not run the historical admin password-printing example below as part of this verification.

Full actual evidence/failures/hashes/next steps: [preview18 evidence](karvaan-preview18-evidence.md). Artifact tools/.local/qa-preview/artifacts/0.2.0+18/web, mainJS SHA256c45b835c64067fa89d973676c18a7117a4e4785e5f2cf368c19ed4895a450a69. Prior sections below are retained initial13 history and must not be misread as completed18authenticated checks. Known performance/pagination/terminology/native/device gates remain unresolved; T19 dispositions preserved/T20TODO.

## Verified provisioning

Created new Supabase karvaan-test project nxyjjjxvgibehovlyycx in the verified Free organization ninsjeitbhvymnaoqtcx, Singapore. Pre-migration Auth users0/public tables0. Existing active pilot and inactive project left unchanged. All28 tracked update-branch migrations applied transactionally with source hashes and migration history. Separate private qa_preview ledger marks this new environment. All28 application tables have RLS; receipts bucket private/5MB/PNG,JPEG,PDF. No production users, records, receipts, keys or recovery material copied.

Minimal hosted Auth configuration sets disabled signup, disabled anonymous sign-in, minimum password12, siteURLhttps://karvaan-test.pages.dev and the existing staff_access_token_hook. Remote undeclared options remain unchanged, including MFA defaults and pooler sizing. Existing staff-accounts and expense-receipts deployed with their documented explicit Auth/live-session checks, not unauthenticated operations. No paid addons or billing upgrades requested.

qa_preview.py is pinned to the new ref/name/organization and branch. It never links a project or reads installed client configuration. qa_seed.py creates labelled synthetic data and administrator-managed accounts via existing contracts. TEST service key exists only in trusted setup memory; public defines contain the publishable key only. Generated passwords and database password are Windows-DPAPI encrypted under ignored tools/.local/qa-preview/. They are not in evidence/Git/client files.

## Separate client boundary

Opt in using KARVAAN_QA_PREVIEW=true, while preserving KARVAAN_LOCAL_ONLY=true and all LocalCandidatePolicy checks. QA uses exact HTTPS project and business allowlist plus a synthetic identity probe before opening session storage. A separate karvaan.qa.preview.session prefix and project/business namespace prevent local/production session reuse. QA startup is web-only and bypasses installed configuration loading. Actual public names: APP_ENV=test, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, APP_BUSINESS_ID. New bilingual Testing — synthetic data only banner remains visible on authentication and nested screens. One append-only catalogue entry, original820 preserved.

Production targets, other hosted/local endpoints, wrong business/environment, malformed identity and secret keys are rejected in tests. LocalCandidatePolicy still rejects this hosted TEST target. No changes to repositories, accounting, RLS contracts or frozen renderers.

## Executed checks before build

Full Flutter135 tests PASS195s; app analyzer clean27.3s. Affected QA/local policy5 tests rerun after replacing a synthetic secret-shaped test literal that triggered source audit. Original root analyzer included unrelated AST-tool deprecations and was interrupted; app-scoped analyzer is the recorded result. Formatting only after initial suite, affected tests rerun.

Actual TEST direct-call checks: signup denied; three account logins; ready staff/one assigned office; forbidden administration and complete balance; assigned balance explicitly incomplete; origin fare/dispatch versus destination arrival permissions; direct trip-table writes denied; Karachi cannot read or list ISB/LHR trip. Synthetic draft identical retries and dispatch identical retry return one result; report owner earnings95000.00 exact. All28 public tables RLS, no public buckets, private5MB receipts confirmed. Probe sessions logged out. Raw sanitized checks under tools/.local/qa-preview/backend-verification.json.

## Setup failures retained

CLI db query first required --linked together with explicit --project-ref; corrected without linking the worktree. Metadata inspection with --reveal was rejected by automatic approval review; metadata-only inspection replaced it. Account setup uses only the necessary TEST legacy service key in trusted memory, never logs/persistence. Initial Windows PowerShell5 security-module autoload failed before account creation; guessed system PowerShell7 path absent. Resolved using existing bundled pwsh discovered from PATH; nonsecret DPAPI protect/unprotect roundtrip passed before seed. No software installed.

Cloudflare cachedWrangler4.149.0 first new-project delegation failed before creation (no static-directory detection). Explicit legacyPages fallback created only karvaan-test with production-branch qa-preview; no Git provider. This fallback selector was not a Git force-push, and is not needed for upload. Existing encrypted/keyring OAuth has pages:write; missing unrelated optional scopes were not added. Cached/offline package mode only; no package installation.

## Initial preview13 publication and artifact (retained history)

Verified shareable URL: https://karvaan-test.pages.dev/
Immutable upload URL: https://4af214ed.karvaan-test.pages.dev/
Cloudflare project karvaan-test, direct upload, default branch qa-preview, no Git provider. Existing carrier-records project not targeted. No Git push/merge, install or scheduling change.

Web-only build0.2.0+13; compiled application source11e8de115841fcfac15dc4f8f15b9c073587871e. Build command used existing SDK, --release --no-pub --build-name=0.2.0 --build-number=13 and ignored public-only QA defines, with distinct --output. Compiler346.9s/exit0. Initial PowerShell output-path expression failed before compilation; corrected to explicit absolute path. pubspec remains0.2.0+12; this preview's version override consumes build13. Do not reuse13 for future candidates. No Windows/Android build or installation in this task.

Artifact: tools/.local/qa-preview/artifacts/0.2.0+13/web/; manifest in its parent.49 files/46305140bytes; main.dart.js4388262bytes SHA-256 bc43ff40f1f1b803327dc006a19bec0a3523a9b30afa817e06defbb4914cde2d. Audit finds no privileged keys, passwords, signing material, dumps or forbidden backend targets. Only compiled Supabase origin https://nxyjjjxvgibehovlyycx.supabase.co. Existing candidate12 compiled and91 review-pack file hashes rechecked unchanged. All820 original catalogue entries exact; one appended testing label. Repositories, database migrations/functions, local guards, financial code, fonts and frozen renderers unchanged from34ec2d1.

Testing-specific static title/description, noindex/nofollow, no-referrer and nosniff headers, exact SPA fallback prepared only in this new artifact. Upload47assets plus headers/redirects succeeded. Manifest records each artifact hash and public-configuration hash, not the key value. Artifact source11e8de1 is distinct from later verification/documentation commits.

## Fresh browser and API verification

Local served release http://127.0.0.1:8770 local5 and actual HTTPS live1 both pass seven grouped browser checks in new Chromium contexts per account. Actual login for allthree users; administrator controls only forqa_admin, each staff home shows its assigned office only. Journey/Consignments/Review typed mixed text and exact95000.00 owner preview; mandatory edit reason supplied. Deliberately abort first save: no false success, retry retains identical request UUID and commits once. Dispatch invalid date blocks review; review/ack required before Confirm; Cancel/Escape dismiss without a dispatch request. Actual authorized INTERNAL October PDF/XLSX downloads, narrow desktop-browser screenshots, no unexpected console/network errors in final runs.

Every observed Supabase request targets TEST. Additional asset origins https://www.gstatic.com and https://fonts.gstatic.com serve Flutter rendering/fallback fonts; these are not backend calls and received no app authentication headers from the test harness. They are explicitly permitted by the QA-only harness. Existing local harness allowlists unchanged.

TEST API evidence:26 setup/security/workflow checks plus6 recipient/privacy checks. OWNER_STATEMENT server payload excludes internal-only keys; adding a known forbidden field rejected42501. Karachi staff altered office filter rejected42501. Both staff direct financial insert attempts rejected42501. Public Auth settings disable_signup=true and actual signup_disabled rejection confirmed. No test public account created. Owner earnings remain95000.00 after the single synthetic dispatch; customer payment/held/owner settlement distinctions retained.

HTTPS Node probe: root/trips200text/html; flutter.js/main.dart.js200application/javascript; version.json200application/json, version0.2.0/build13; deployed main.js hash matches audited artifact; noindex header present. Independent Python-agent root probe returned403; retained as a failed/runtime-dependent probe, no server security change. Fresh Chrome and Node verification succeed. HTTP200 alone is not the acceptance evidence.

Live files: PDF40319bytes/sixpages SHA9b5c73cfd782213169fbfeeb2298185dd00d404f1973acdfba91df9e04458353; XLSX5609bytes/38rows10columns SHA f415b1678c5161833930e6195180e1990b047bc912e24d966b11cc1b7c0ad5dc. Actual font/content/XML/metadata/hidden/formula inspection passes. Embedded NotoSans regular/bold and NotoSansArabic; one visible sheet, no hidden/formula content. Fresh local and live PDF pages1/6 visually inspected for joining, Latin amounts and labels. Live workbook creatorKarvaan/lastModifiedBynull, freezeA38,33numeric cells,0formulas/hiddenrows/hiddencolumns; actual metadata inspected. This sample does not resolve the earlier frozen wide/broker orphan-page defects.

## Failed attempts and remaining preview limitations

local1 blocked an official fallback-font origin and incorrectly treated missing route accessibility text as an absent visual banner. local2 permitted the official font origin but still failed this semantic assertion. Screenshots prove the bilingual banner is visible; Flutter's active-route semantics omit the outer banner. Banner announcement remains an accessibility limitation, explicitly not passed. No app change or new build concealed it.

local3 omitted mandatory edit reason and was correctly blocked without operation. local4 attempted immediate simulated typing after focus change, but screenshot showed reason remained empty; again no operation posted. local5 waits two rendered frames on focus and asserts actual inputValue, then passes normal single-click workflows. No repeated-click/app-delay workaround. Save retry uses existing retained review/request without asking for a second review dialog. All earlier failure artifacts preserved.

Ad-hoc catalogue check initially used scoped-report MONTHLY_OWNER instead of output contract OWNER_STATEMENT and received22023; corrected using source contract. First privacy run checked numeric GoTrue code422 instead of error_code; public settings already confirmed signup off. Diagnostic normalization fixed with3unit regressions and six actual checks rerun pass. Initial live verification command was not executed when automatic approval review hit its usage limit; user continuation retried through normal review, then live checks passed. No approval bypass.

## Completed secure tester handoff

Usernames qa_admin (synthetic all-office admin), qa_khi (Karachi staff), qa_isb (Islamabad staff). Share each password privately outside Git/evidence/chat; use the local protected-credential helper. Allthree existing TEST accounts reset after live verification to fresh temporary passwords. Each fresh login confirmed must_change_password=true and trip operations denied until changed. Old sessions revoked through the normal audited reset; only final temporary passwords retained, DPAPI encrypted. No duplicate accounts created. Do not add real business data. Preview is not production acceptance.

Review checklist: bilingual navigation/forms/readability; Journey/Consignments/Review and back-navigation; explicit dispatch review/ack; Cancel/Escape; permitted save and retry; cross-office denial; report recipient/selected fields; PDF/Excel samples. Report screen, expected behavior, actual behavior, synthetic trip number and screenshot with credentials removed.

Known unresolved: local five-user summaryp957.453s with2/50 summary57014 errors and screenp953.977s; frozenv2 orphan-note last pages; native OS-input and Android-device checks, missing supplied mockups and provisional glossary terms. Small hosted preview smoke cannot clear representative performance gates. T19 recorded acceptance/exceptions/waivers retained and skipped checks are not converted to passes. T20 TODO.


### Initial preview13 password handoff (historical; not a current administrator credential)

Open a private local PowerShell terminal and run the already-present bundled PowerShell, not a chat tool or transcript. Example for the administrator:

```powershell
& "C:\Users\Naeem\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\powershell\pwsh.exe" -NoProfile -File "C:\Users\Naeem\.codex\worktrees\karvaan-bilingual\transport_project\tools\karvaan\show_qa_password.ps1" -Username qa_admin
```

Replace qa_admin with qa_khi or qa_isb to retrieve only that tester's temporary password. Share individual credentials privately with the intended tester, never in Git/evidence/chat. Sign in only at https://karvaan-test.pages.dev/, complete the required12–128character password change, then sign in again. Do not reuse production passwords. The admin can subsequently manage/reset tester accounts in this TEST app. DPAPI retrieval works only under the creating Windows user; no administrative installation or new service sign-in is required.

Sanitized raw evidence is under tools/.local/qa-preview/: backend-verification.json, privacy-verification.json, handoff-status.json, https-verification.json, artifact-audit.json, local1..local5 and live1. Secrets, public defines, samples and build artifacts remain ignored. Read-only main HEAD remainsa0bd553b6de18352f587cb1cc6fc662443f9178b. Prior accidental installed-app startup traffic uncertainty remains recorded; this task does not retroactively claim zero traffic for that earlier attempt.
