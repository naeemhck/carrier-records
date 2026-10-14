# Karvaan candidate verification — local only

Worktree: `update/karvaan-bilingual`, based on main `a0bd553b6de18352f587cb1cc6fc662443f9178b`. Document checkpoint: `884fe0f7f872b909d20dcf37d3032c7a2f80061e`. Candidate source version is provisionally `0.2.0+8`; paths and hashes will be recorded only after successful builds. No candidate installer has been installed, and no hosted backend, deployment, main merge or push is authorized.

## Current-source checks

Fresh analyzer: no issues, 327.5 seconds (`karvaan-candidate-analyzer-final.log`). Full Flutter regression: 111 tests passed, exit 0, 6:21 (`karvaan-candidate-flutter-final.log`). Both Arabic font weights cover all 100 catalogue glyphs and contain joining features. The original three legacy parser/renderers and both Latin fonts remain identical to base main (`karvaan-font-final.log`, `karvaan-legacy-final.log`). Original 554 catalogue entries and their English wording remain preserved; terminology is provisional pending office review.

Current financial/backend regression passed 1,466 assertions, exit 0, with successful synthetic identity/business cleanup (karvaan-current-api-retry.log). An earlier retry failed creating the fourth synthetic staff account. Actual isolated Auth logs showed successful setup around 21:16 UTC, then the next operation around 00:16 UTC, and HTTP 403 `bad_jwt` with expired claims. This observed three-hour gap explains the expired one-hour fixture token; its cause outside the harness is not established. A fresh run has passed the same account-creation stage without changing token expiry, security checks or account behavior. Failed runs cleaned their synthetic records.

Native template-2 export generation itself passed (Windows build 120.9 seconds; integration test 10 seconds). The parent run subsequently failed the old English-only independent heading inspector. Its version-aware comparison now separates English font runs while retaining full-text privacy checks and exact selected order. A deliberately reordered synthetic payload is rejected. A subsequent positive inspection exposed a scope-text assertion: every document retained the full scope but PDF line wrapping split the extraction. The inspector now compares all non-whitespace characters. Fresh three-test regression passes in84.172s: all eight native PDF/XLSX pairs (77 pages) pass contents/privacy inspection; altered selected order and altered authoritative scope are rejected. Three configuration-boundary tests also pass. Physical printing and Android device execution are not established by these tests.

The web artifact auditor previously treated `.local` in the directory containing an artifact as packaged private content. It now checks only paths relative to the artifact root. Two regressions pass: a clean artifact beneath an ignored parent is permitted, a nested private file remains denied, and a synthetic privileged key is rejected without printing its value. This changes the inspector, not client authorization.

## Annual performance recheck — outstanding gate

Isolated synthetic dataset: 12,000 trips, 1,000/month for twelve months, twenty vehicles and five genuinely authenticated restricted users. Fifty summary and fifty ordinary paginated-screen requests. HTTP loopback to API 60321, active dedicated Docker backend; both pre-existing and isolated local stacks remained running. Windows 10 build 19045; Intel i5-6200U 2.30GHz, four logical CPUs; Docker four CPUs and 8,262,008,832 bytes memory. No hosted records or services were used. Dataset size is benchmark volume, not a business forecast.

Initial concurrent-build and idle trials timed out; neither establishes a passing p95. Diagnostics captured actual nested plans using the isolated container (the diagnostic originally contained an old hard-coded container name, corrected before executing it). Full ancestry cardinality estimates were excessive and temporary I/O was observed. Changes remain restricted to report implementation; office/source predicates, exact arithmetic, owner/ACL/definer/search-path protections, date bases and immutable history are retained.

Recorded isolated migrations retain trial history: custom-plan/linked-root trials, restoration of the original plan, bounded function-local 8MB working memory, then linked-root traversal with function-local 16MB. No global timeout, authentication or resource/security settings were relaxed. Provider concurrency/memory limits remain a deployment consideration; these local trials establish no hosted guarantee.

Final measured trial (`karvaan-performance-memory16-roots.log`, raw `t11-performance.json`): all 100 requests succeeded, no errors. Monthly summary p50 5.0385s, p95 **5.8802s**, maximum 6.4315s: **FAIL** against five seconds. Ordinary screen p50 0.1338s, p95 **0.4696s**, maximum 0.7912s: **PASS** against two seconds. Nearest-rank percentile `ceil(0.95*N)`. Fixture setup 30.902s, database 111,892,147 bytes. Earlier 8MB trial: summary p95 6.8693s, screen 0.6046s, zero errors. This does not replace the earlier recorded T18 evidence or mark U06 DONE.

## Pending candidate checks

Source/history audit and local source commit; Windows/web/Android candidate builds and installer compilation; artifact hashes/credential audits; ordinary candidate smoke tests with separate synthetic configuration/session storage; screenshots and authorized PDF/XLSX review samples. No completed artifact or candidate-readiness claim yet.

T19's recorded owner acceptance, exceptions and waivers remain intact, without relabeling skipped checks PASS. T20 remains TODO. Production backup scheduling is unchanged.

Source/history audit before staging:342 tracked files,14 intended untracked files,689 historical blobs,2195 ignored local files; no findings (karvaan-candidate-source-audit.log). Generated exports, fixtures, credentials, configurations and build artifacts remain ignored.
