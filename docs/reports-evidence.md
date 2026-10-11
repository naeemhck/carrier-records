# T11 report verification

The existing local SDK and Docker/Supabase backend were used on 2026-10-11. All business/accounts/costs/receipts below are isolated synthetic fixtures on an empty loopback database, not production records. The annual fixture generator and tests are committed; fixture rows, credentials, raw logs and build artifacts are excluded.

## Accounting and scope

Real draft/dispatch/arrival, receipt, expense and correction RPCs establish the golden cases. January 30 dispatch recognizes customer fare 100,000, owner earnings 95,000 and brokerage 5,000. February 2 arrival changes no earnings or settlement. Owner-paid February diesel 10,000 on that January trip plus standalone maintenance 2,000 appear as February costs 12,000. February owner profit is -12,000, while owner settlement remains 95,000. Lifetime trip owner profit is 85,000 and excludes standalone maintenance.

March receipt 100,000 changes customer debt to zero and intermediary custody to 100,000, leaving owner settlement 95,000. A reviewed replacement moves that receipt to February; March receipt total becomes zero. Replacing February diesel with April cost 11,000 leaves February maintenance 2,000, April costs 11,000 and lifetime trip owner profit 84,000. The original evidence/events remain; costs are counted once. A second trip's authorized dispatch-date reversal/repost moves its earnings from January to February once. Updating the current vehicle owner leaves original trip earnings and recorded expense costs with the historical owner.

AT-07/19 pass at the report boundary. AT-22 checks current assigned-office totals, explicit incomplete labels, administrator completeness, selected-office filters, no inaccessible trip facts, denied direct outside-office/trip requests, invalid scope-spoof fields and no raw facts endpoint. Canonical totals cover the entire authorized filter even when only fifty grouped rows are returned. Two pages contain fifty and thirty-two disjoint groups with identical summary values. Profit, customer debt, credits, held money, unpaid entitlement, recovery, reimbursements and funding liabilities remain separate.

## Annual benchmark

Twenty synthetic vehicles and 12,000 dispatched/arrived trips represent twelve months with 1,000 trips/month. Each has a balanced 100,000 fare / 95,000 owner / 5,000 brokerage event and a real-cost fixture 100. December summary validates 1,000 dispatches, owner earnings 95,000,000 and expenses 100,000 before measurements. Five distinct managed staff sessions issue ten summaries and ten fifty-row trip list requests each, concurrently. Nearest-rank p95 is measured from fifty requests per category.

Environment: Windows 10 build 19045, Intel Core i5-6200U at 2.30 GHz, four logical processors. Network is HTTP loopback `127.0.0.1:54321`, active local Docker backend. This is not a hosted Supabase or remote-network benchmark.

| HTTP category | Requests | p50 seconds | p95 seconds | Max seconds | Target |
|---|---:|---:|---:|---:|---|
| Monthly vehicle summary | 50 | 3.1250 | 4.2047 | 5.0491 | p95 ≤ 5s: PASS |
| Fifty-row trip screen | 50 | 0.2402 | 0.4207 | 0.6949 | p95 ≤ 2s: PASS |

The first concurrent attempt failed its HTTP success assertion before producing measurements; it is not counted as a passing benchmark. Missing expense/event/claim-context indexes and per-row live office checks were corrected. `list_trips` now captures currently assigned active offices once, preserving admin/all-office and staff/origin-or-destination scope. Final measured requests all succeeded. No calculated totals are cached or editable.

## Executed checks and fixes

- Clean thirteen-migration reset applied successfully. Seven additional SQL access-contract assertions bring the suite to 170 passing assertions; database lint at error level reports no errors.
- Final analyzer reports no issues. Full Flutter suite passes 54 tests, including report filter-preserving pagination, distinct server profit/settlement display and dashboard navigation. The initial picker layout overflow was fixed with expanded dropdowns; focused report tests pass.
- Harness fixes use the actual dispatch response `version`, current allocation versions on replacement, explicit benchmark date aliases and nonempty owner snapshots. An initial Edge warm-up 502 was followed by complete fixture cleanup and a fresh run; no duplicate services were started. SQL helper tests respect the production revoked function privileges; exact totals are verified through real managed-staff HTTP calls.

The real Windows report UI test passes (55.1s build / 7s test), using managed staff login, production repositories, January date/search selection and exact server owner earnings 95,000 with the scoped label. Native configuration is removed and logout revokes the session. The annual/native combined run reached 1,146 passing checks, but a prematurely started final reset interrupted its still-running cleanup; that process's completion is not claimed successful. After the final clean thirteen-migration reset, the complete backend suite was rerun with `python tools/tests/t03_api.py --trips --lifecycle --finance --payments --expenses --corrections --reports --reports-functional`: exit 0, 1,143 PASS checks, including final archived-office and old-JWT revocation checks, and successful zero-fixture cleanup. Benchmark timings above come from the separately executed full annual run; functional-only execution explicitly does not claim another performance test.

Ordinary Windows and Android debug builds exit 0 (47.0s / 45.2s reported build times), replacing the native fixture build. Ordinary kernel assets exclude the native report fixture marker. SHA-256: Windows runner `44ac3d7ed404dbac7ff50f34440f029c87c9b6c10bae23f1e70923c7e090dd87`; Android APK `fc404ad74f2e57e40dd23eb1235d63b8b753efb58a2a639d9ad2f2b8730cf7b9`. The runner is unchanged because Dart application code lives in its kernel asset.

Staged source/ordinary package privileged-value audit passes 735 entries/files. Source/history audit reports no sensitive findings and no intended untracked files. Local Auth/REST/Storage return HTTP 200; PostgreSQL ready; all public/private/Auth/Storage synthetic rows zero, thirteen migrations, no disabled triggers, no temporary role SET access and no native credential config. No administrator action, production deployment, Android device/release/export/restore execution or GitHub push is claimed. T11 completion checks pass. See [report use and date bases](reports-setup.md).
