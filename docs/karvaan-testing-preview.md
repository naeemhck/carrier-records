# Isolated hosted Karvaan testing preview

Authorized 2026-10-15 for a separate synthetic-only hosted TEST environment. This narrowly overrides the previous local-only rule for this deployment only. Production remains prohibited: no target changes to carrier-records.pages.dev, tuasxnfwrepbcelnrlgb, zuoaxtjfylfuwsxfbgzl, main, installed applications or scheduling. T20 remains unstarted.

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

## Pending build and live verification

Distinct web preview0.2.0+13 reserved, candidate12 and its91-file review pack preserved. Artifact/audit/deployment details will be appended after execution. No HTTP200-only acceptance: fresh browser role/office/workflow/export/network checks required.

## Tester handoff (pending credential reset and live checks)

Usernames qa_admin (synthetic all-office admin), qa_khi (Karachi staff), qa_isb (Islamabad staff). Share each password privately outside Git/evidence/chat; use the local protected-credential helper. Reset to fresh temporary passwords requiring the normal first-login password change before handoff. Do not add real business data. Preview is not production acceptance.

Review checklist: bilingual navigation/forms/readability; Journey/Consignments/Review and back-navigation; explicit dispatch review/ack; Cancel/Escape; permitted save and retry; cross-office denial; report recipient/selected fields; PDF/Excel samples. Report screen, expected behavior, actual behavior, synthetic trip number and screenshot with credentials removed.

Known unresolved: local five-user summaryp957.453s with2/50 summary57014 errors and screenp953.977s; frozenv2 orphan-note last pages; native OS-input and Android-device checks, missing supplied mockups and provisional glossary terms. Small hosted preview smoke cannot clear representative performance gates. T19 recorded acceptance/exceptions/waivers retained and skipped checks are not converted to passes. T20 TODO.
