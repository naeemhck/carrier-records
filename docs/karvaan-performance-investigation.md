# Karvaan timeout and performance investigation

2026-10-14 (America/Los_Angeles); service logs use explicit UTC, including2026-10-15. Worktree update/karvaan-bilingual, backed-up starting commit76dcf71394b3b595b7e1fc331963f229a44adb4b. Local synthetic backend karvaan_bilingual_u20261013/API60321/DB60322 only. Main and hosted services were not used or changed. No push, merge, installation, deployment, scheduling change or T20 start.

**Gate remains unresolved. No new candidate was built.** Candidate0.2.0+10 is preserved: all84 compiled-manifest files and64 review-manifest files independently SHA256-verified unchanged. Existing native-input/device limitations remain separate pending checks.

## Actual failure classification before optimization

The original22:30-22:33UTC failure window has exactly21 PostgREST SQLSTATE57014 statement-timeout errors and21 get_scoped_report HTTP500 lines, matching the21 failed benchmark summaries. There are zero bad_jwt/42501/PGRST301 lines in that window. PostgreSQL global timeout0 is unchanged; authenticated and authenticator roles both retain8s, anon3s. No timeout was raised to hide failures.

Health evidence karvaan-health-20261014-221032.json: intended database/Kong healthy, no OOM kills or restarts, seventeen database connections versus max100, ample memory/free disk. Idle authenticator connections awaited ClientRead. CPU cgroup has no configured quota and nr_throttled0. VM CPU pressure avg10=19.42%; memory pressure0. Host reported96%CPU at800MHz, later100%CPU and800MHz while measured work was running; several Windows services and vmmem consumed CPU. Balanced processor maximum100% on AC/DC, unchanged. ProcessorPerformance112% and reported800MHz counters are not sufficient to establish thermal throttling or an exact clock-limiting cause. No power, security, process or Docker-resource setting was changed. Earlier failure-window CPU measurements do not exist, so do not retroactively claim its exact resource state.

Five new sessions are five distinct actual staff principals/sessions, with exactly the intended office and about3597-3599 JWT seconds remaining. Observed baseline:17 read-only samples, peak5 active report calls, no blocked connections or lock waits; active waits were null (CPU/runnable), not reported I/O/lock waits. PostgREST previously reports a10-connection pool. These observations do not measure exact pool-acquisition milliseconds. They support execution/CPU demand rather than authentication, deadlock or pool exhaustion as the demonstrated path to the8s deadline. Shared-resource variance is a remaining contributor, not a proven thermal diagnosis.

## Evidence loss fixed in the benchmark

The earlier helper discarded safe error codes after HTTP errors and could abort/drop transport failures. It now retains recognized SQL/PostgREST/Auth codes, allowlisted messages, timing/UTC/status and Kong latency headers. Transport failures and malformed HTTP200 responses remain counted samples. Arbitrary error text, passwords, tokens, headers containing credentials and unrestricted payloads are never evidence. It records every measured sample, separate success-only distributions, warm-ups/errors, distinct-session/office checks and optional wait observations. Final gate fails for any measured or warm-up error, wrong money/pagination assertion, or target miss. Six actual regressions pass, including HTTP50057014, transport timeout, invalid JSON and sensitive-error redaction; nearest-rank tests retain slow samples.

## Demonstrated query work and guarded fix

Restricted-role nested EXPLAIN showed nine metric candidates tested per period line,12000 trip-to-expense index probes to find1000 monthly expenses, and reversal index lookups without the leading business key. New migration20261015052509_karvaan_period_and_expense_projection.sql projects the applicable metric and explicitly preserves the second credit metric for an ADJUSTMENT of CUSTOMER_ADVANCE_CREDIT; it materializes business/date/state-bounded expense candidates before existing office/trip/correction predicates and supplies business_id to the existing composite reversal index. Composite foreign keys already enforce matching business IDs. No new index, permission bypass, editable balance or stored total was introduced.

Exact585-scenario old/new SQL comparison:13 root kinds x9 purposes x5 signed/zero/paisa/extreme numeric amounts,72 old/new emitted rows, zero differences. Deliberately omitting the second adjustment metric fails, restored projection passes. Three permanent SQL assertions retain this matrix and the two-metric1.01/-1.01 example. Owner/ACL/SECURITY DEFINER/STABLE/search_path/work_mem are unchanged and checked before/after. Expenses/cost bearer/reimbursement, effective dates, office/recipient eligibility and original immutable records are unchanged.

Actual plan after rewrite: expense candidates1000 via existing date index, no12000 expense PK probes, reversal index uses business+reversal key, shared hits for scoped aggregate11620 versus66547 in the earlier failed plan. Period projection now emits one applicable branch per ordinary line. Wall-clock query timing still varies with shared host load; these reduced operations do not by themselves prove the latency target.

Nine complete authorized vehicle/owner/claim payloads for January/June/December match exactly (only generated_at excluded). Aggregate fingerprints of all original trips, consignments, expenses, events, journal lines, allocations and issued-document rows match before/after the rewrite. Two initial comparison attempts hit57014 (one diagnosed specifically at CLAIMS12); neither is marked PASS. A later complete nine-report comparison passes, with original records unchanged. This confirms exact output correctness but leaves intermittent timeout susceptibility under load unresolved.

Local migration up applied two previously unrecorded but already tested report migrations plus the new migration, without reset/data deletion; final body is the verified rewrite. Financial regression fixture history remains preserved.

## Unchanged representative workload and all measured results

Same12,000 BENCH trips,1000/month for twelve months,20 vehicles, five genuine restricted users. Fifty December summaries and fifty50-row trip-list calls, alternating10 of each/user. Exact summary assertions include1000 dispatches, owner earnings95000000.00, expenses100000.00 and20 rows. The seed AST matches the backed-up checkpoint; independent monthly counts confirm twelve1000-trip/20-vehicle months. Existing synthetic review/correction records remain present, not reset or deleted. Volume is a benchmark, not a forecast.

Cache conditions: active local backend, existing OS/Postgres caches retained; no eviction. One unmeasured nested diagnostic call and one unmeasured December warm-up/user precede measurement. Latest5 warm-ups succeed. Observation mode samples waits every2s; final confirmation disables it. No browser, test suite, audit or build ran beside the final measured workload. This remains a shared Windows/Docker machine, not a dedicated host or production/device forecast.

Nearest-rank p95=ceil(.95*N). All requests/errors remain in raw samples; failed-response timing is not a successful-summary latency claim. Each row has50 attempts.

| Run | Operation | N | Errors | p50 seconds | p95 seconds | Max seconds |
|---|---|---:|---:|---:|---:|---:|
| Backed-up failure | summary | 50 | 21 | 7.224794 | 8.395284 | 8.568857 |
| Backed-up failure | screen | 50 | 0 | 1.820863 | 3.239297 | 4.483339 |
| Observed baseline | summary | 50 | 0 | 4.377660 | 7.143005 | 7.611687 |
| Observed baseline | screen | 50 | 0 | 0.844563 | 1.453815 | 1.706596 |
| Observed rewrite | summary | 50 | 0 | 5.012696 | 6.913347 | 7.329969 |
| Observed rewrite | screen | 50 | 0 | 1.223350 | 2.137715 | 2.403350 |
| Unobserved confirmation | summary | 50 | 0 | 3.028056 | 5.871856 | 6.820141 |
| Unobserved confirmation | screen | 50 | 0 | 0.775295 | 1.790964 | 2.315311 |

The latest run has0 measured errors/100 and0 warm-up errors/5. Screenp951.790964s passes2s; summaryp955.871856s fails5s. Three new measured runs have no errors, but historical21 failures and comparison timeouts are retained; do not call intermittent timeout risk eliminated. No benchmark retry was used to overwrite a failed result.

## Execution, queue/transfer, client and rendering decomposition

Final matching pg_stat_statements delta:50 successful summaries, mean3245.349708ms SQL execution. Mean request-header wait3319.060062ms; their difference73.710354ms includes API/pool/proxy/loopback/scheduling overhead and is not exact pool wait. Mean Kong upstream3287.9ms, proxylatency3.46ms; summary proxy p9513ms. Header-waitp955871.1788ms versus transferp95.3554ms and Python JSONp95.6517ms. No subtraction of unrelated p95 values. The dominant remaining delay is backend execution, not payload transfer or JSON parsing.

Preserved candidate10 release web artifact, one fresh local scoped browser, five real reports: readiness p503612.3721ms/p954819.8909ms; browser JSON parsep95.8ms; body-received to visible semantics plus two framesp95391.081ms. CDP post-body per-event p95 FunctionCall295.334ms, Layout15.926ms, Paint7.225ms. Nested/overlapping trace event durations are not additive and not isolated GPU timing. Raw trace arguments are discarded; only durations/counts remain. This diagnostic ran separately from the five-user gate; it does not establish five-user UI readiness. No browser errors or nonlocal requests; intentional read-failure/recovery check passes. All output is outside candidate10 at tools/.local/karvaan-client-profile-current.

## Verification, failed tooling attempts and disposition

- 74 affected backend checks PASS: current financial/date/history/owner and office/recipient authorization behavior, including removed office access with old JWT. Initial run stopped after56 PASS on a retained T11-ARCHIVE office-code collision (actual23505). Fixture code now uses its unique generated identifier; no existing office/history deleted; complete rerun74 PASS.
- 223 SQL assertions across16 transactional files PASS, including the new3 assertions. Every test rolls back.
- Six error/percentile helper regressions PASS; JS syntax and whitespace checks PASS.
- Local advisors exit0, noERROR; existing receipt_files multiple-permissive INSERT policy WARN remains unchanged.
- First rewrite helper had a Python quoting SyntaxError before any SQL ran; corrected. First independent workload query used reserved alias month without AS and failed42601; corrected to business_month. Neither was an app/accounting defect.
- Application/legacy renderer/font/catalogue sources are unchanged. No fresh Flutter-suite/build claim is made for this backend-only phase; previous114-test evidence remains historical. New candidate11 is deliberately NOT built because the required monthly gate has not passed.

Remaining work: reduce or otherwise resolve demonstrated execution/CPU tail latency on the unchanged workload, obtain a stable passing zero-error/two-second/five-second run, then final regressions/analyzer/current Flutter verification and a new unused candidate. Native input/device checks remain pending as previously documented. Do not disable security, change unrelated workloads, increase application timeouts, bypass permissions, shrink the fixture or silently change targets to make this pass. T19 acceptance/exceptions intact; T20 TODO.

Raw evidence remains ignored locally: karvaan-error-investigation.log; health/host snapshots; three new karvaan-report-profile JSONs; nested plan logs; snapshot before/after logs; karvaan-period-report-regressions[-retry].log; karvaan-period-sql-regressions.log; karvaan-period-client-profile.log; karvaan-period-advisors.log; workload-verification JSON. Credentials, raw private payloads, backups and artifacts are not committed.

Official references consulted before investigation: [Supabase observability](https://supabase.com/docs/guides/observability), [PostgreSQL17 statistics/wait events](https://www.postgresql.org/docs/17/monitoring-stats.html), [Supabase changelog](https://supabase.com/changelog). Markdown fetches initially failed unsupported content-type; HTML pages succeeded. Current hosted TLS notice does not apply to this local HTTP investigation; SDK/CLI versions were not upgraded.


Precommit verification: current live function SHA matches the final raw benchmark report; owner/ACL/security/config still exactly match the pretrial snapshot. Source/history audit368 tracked+7 intended new files/753 historical blobs/no findings. Main remains clean at a0bd553b6de18352f587cb1cc6fc662443f9178b. Whitespace and JavaScript syntax checks pass. Latest safe-code redaction changes affect only failure evidence, were checked by six regressions afterward, and do not change the recorded successful requests or database source. Local checkpoints retain the unresolved monthly gate; no new artifact or automatic push.
