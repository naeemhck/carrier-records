# T10 corrections and cancellation evidence

Executed against the existing local Flutter SDK and local Supabase stack on 2026-10-11. No production accounts, hosted deployment, operational backup restoration, release signing or Android device execution is claimed.

## Verification

- Clean `tools/supabase.ps1 db reset --local --no-seed`: all twelve migrations applied.
- `tools/supabase.ps1 test db`: nine files, 163 assertions, PASS. Database lint has no errors; the cancellation wrapper reports unused-variable warnings.
- `tools/flutter.ps1 analyze --no-pub`: no issues (final run 11.6s).
- `tools/flutter.ps1 test --no-pub`: 52 tests PASS. Two focused correction widget tests also pass after the final progress indicator change: ambiguous-response retries preserve the UUID/body, success waits for committed RPC results, exact fee review and stale-version blocking work.
- `python tools/tests/t03_api.py --trips --lifecycle --finance --payments --expenses --corrections --native-corrections`: 1,062 PASS checks, including existing account, draft, lifecycle, finance, payment and expense regressions. Synthetic identities, business fixtures and private receipt objects are removed afterwards.
- Real Windows integration test `app/integration_test/corrections_test.dart`: PASS (59.7s build, 8s test). Managed staff logs in, reviews and submits an expense replacement through the production correction form. Independent backend verification confirms the linked replacement amount 3,600.13; native logout revokes the session.

Command output is retained locally under ignored `tools/.local/t10-*.log`; credentials and synthetic private receipt content are not committed.

## Financial and permission results

AT-07 passes at the implemented financial boundary: January dispatch earnings remain distinct from arrival; reversal uses the original event date, replacement uses its explicitly corrected date. A March receipt replaced with a February receipt yields February custody 55,000 and customer debt 45,000, retaining the March source and inverse. A February expense replacement counts one effective cost and preserves the historical owner. Full report presentation remains T11.

AT-15 passes: current creator/origin permission or administrator authority is required. Destination fare changes, unrelated-office calls, revoked-office cached retries, forged transaction capabilities and direct financial/evidence writes are denied. Reasons, reviewed dependencies and versions are enforced server-side. Distinct competing commands produce one success and one conflict; identical retries produce one event. Deferred commit failure rolls back journals, allocations, audit, retry results and operational state before the original UUID succeeds on retry.

AT-21 passes: settled fare 100,000, owner payment 95,000 and brokerage payment 5,000, followed by a cancellation fee 10,000 (owner 9,000 / brokerage 1,000), produce customer credit 90,000, owner recovery 86,000 and broker recovery 4,000. Actual diesel expense 10,000 remains intact. Cancellation creates no cash refund. Actual recovery receipts and the separate customer refund close their respective claims. Partial collection 20,000 produces credit 10,000 with unpaid owner 9,000 and brokerage 1,000. Fee replacement 15,000 changes those effective claims through linked reversal/replacement, retaining source records.

Dependent settlements must be explicitly enumerated and unwound before source replacement; a receipt cannot silently erase an actual dependent expense. Double reversal, repeated claim consumption and stale review plans fail. Cancelling a fully settled trip with zero fee produces credit 100,000 and recoveries 95,000/5,000. Personal refund funding creates custody and a separate funding liability without consuming customer credit; actual refund and subsequent funding repayment are separate events. Every event balances exactly, and no correction transaction capability remains after commit.

Original expenses, private receipt bytes, fare/owner snapshots, dispatch/arrival dates and audit records survive corrections/cancellation. Expense replacement 2,500 to 3,500 counts only the replacement while the original attachment remains downloadable by an eligible user. Issued-document immutability remains enforced by existing constraints; actual document issuance is T13.

## Failures found and corrected

- A generic insert trigger referred to an event-only field on expense rows; nested table-specific branches now select the applicable record fields.
- An ambiguous PL/pgSQL request identifier was qualified. Expense totals now use a narrowly scoped effective-expense helper rather than requiring client journal metadata access.
- T08 detected an overly broad recognition-update grant. It was removed in favor of an earnings-owned, validated replacement interface; finance still cannot directly update recognition or financial history.
- The exact claim payload regression whitelist now admits only the new NORMAL/RECOVERY discriminator, retaining all metadata restrictions.
- The first native attempt failed in its test scrolling helper before opening the form. The helper now scrolls only when a scrollable exists; the form shows its pending transaction indicator. The final native run passed.
- One recovery fixture used a receipt date preceding cancellation; its actual recovery date was corrected. Source auditing now anchors database dump signatures to actual dump headers instead of matching its own detector literals. Windows Python encoding was made explicit while restoring affected display punctuation.

See [correction entry and security](corrections-setup.md) for the implemented workflows.

## Ordinary builds and cleanup

Ordinary `build windows --debug --no-pub` and `build apk --debug --no-pub` both exit 0 (Flutter reports 37.7s Windows and 50.3s Android). They replace the native fixture build. Ordinary kernel assets contain no T09/T10 native fixture marker. Android uses the existing documented TLS environment; Gradle's Java native-access warning does not fail the build.

SHA-256:

| Local ignored artifact | Hash |
|---|---|
| Windows carrier_records.exe | 44ac3d7ed404dbac7ff50f34440f029c87c9b6c10bae23f1e70923c7e090dd87 |
| Android app-debug.apk | cf35ad410aa4a8231e5f4af6b61f4d3704ed4fee344d47e1b06e7e2b937f1d60 |

`python tools/tests/t03_package_audit.py` passes across 726 APK entries, Windows files and tracked source files with no actual local privileged service/secret/signing/S3 value. Auth, REST and Storage health return HTTP 200; PostgreSQL is ready. All 27 public tables, all nine private fixture/cache tables, Auth users/sessions/identities and Storage objects have zero rows after cleanup. Twelve migrations remain, no disabled application/private/storage triggers or temporary role SET access remains, and the temporary native credential config is absent. No administrator action is required.

## Source checkpoint preparation

The read-only source audit passes across 157 tracked files, no intended untracked files and 246 reachable historical blobs at preparation. It checks credential signatures and actual local key bytes, signing material, dump/archive/receipt/private-data paths and all reachable history. Ignored logs, builds, local configuration and other local files are retained, excluded from the source push. Synthetic fixture generators are source code, not exported operational records. No production data or receipt files are intended for the backup.

Origin is `https://github.com/naeemhck/carrier-records.git`; authenticated GitHub API verification confirms account `naeemhck`, intended repository `naeemhck/carrier-records`, `private=true` and visibility `private`. Existing Git Credential Manager credentials remain in process memory and are never printed or committed. Only main exists; there are no additional project branches or tags. T10 completion checks pass; push verification is recorded separately after the local commit and non-force push.

## Executed private checkpoint

Implementation commit `18428a0829275f3aaa49f5bbc4f3bec4b873f2ba` was created locally. The post-commit source/history audit passes 157 tracked files and 253 historical blobs, with zero findings and no intended untracked files. `git -C "D:\portfolio\transport_project" push -u origin main` exits 0, fast-forwarding `d260f08` to `18428a0` without force and preserving the T05-T10 local history. `git ls-remote origin refs/heads/main` matches the full local commit above. Authenticated GitHub API verification after pushing again confirms PRIVATE visibility. Working tree was clean and no additional branches/tags were present.

This verification record is committed and pushed as a follow-up source-only checkpoint; its final remote/local hash is verified and reported at completion. Local ignored secrets/configuration, receipts, operational database files, logs, caches and build artifacts remain excluded and are not deleted. No intended project work is left unpushed after final verification; operational recovery is not supplied by a Git source backup.
