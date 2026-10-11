# T06 lifecycle: implementation and executed evidence

Date: 2026-10-11. Local Windows and loopback Supabase only. The acceptance harness requires an empty Auth/business database, creates synthetic fixtures, and removes them in `finally`. No production accounts, journeys or receipts are used.

## Implemented behavior

Migration `20261011000800_trip_lifecycle.sql` implements authenticated `dispatch_trip`, `arrive_trip`, `correct_trip_operation` and `get_trip_history`. It uses the existing live account/office authorization and RLS, empty definer search paths, account-before-vehicle advisory locks, row locks, expected versions and private actor-bound UUID retry records. Permissions are checked before serving cached results and again under locks.

Origin staff may first dispatch a draft created by another origin colleague; destination staff may first record arrival. Trip metadata corrections require the trip creator plus current origin permission, or administrator. Dispatch/arrival date corrections require that operation's creator and its current origin/destination permission, or administrator. Backend permission flags control the client actions. Client actor, office, state, fare, owner and unsupported financial fields cannot extend the operational command contract.

Actual dates are ISO business dates, separate from planned dates. Authorized backdating is audited with server actor, UTC timestamp, reason and before/after values. Arrival cannot precede dispatch. Arrival changes only the trip and active consignment operational state; cancelled consignments retain their state, fares, counts and optional identifiers. It creates no receipts, allocations, transfers or owner settlements. Cancelled load evidence is also protected from removal or rewriting by a subsequent aggregate draft save.

Unposted trip/consignment cancellation retains evidence and is creator/origin-controlled. A whole draft with an active linked return cannot be cancelled. Dispatched/arrived cancellation is blocked pending the explicit financial adjustment workflow; it cannot quietly erase money or expenses. Operational notes/driver corrections use versions and audit records. Fare, owner and confirmed financial corrections remain outside the operational editor.

The dispatch review shows canonical decimal-string amounts and the actual date. Current vehicle overlap requires a fresh actor-bound server review, confirmation and reason; an old draft warning does not authorize dispatch. Network retries preserve the exact request and payload. An explicit new review creates a new request. Conflict errors retain entered values and require closing/refreshing. Buttons remain disabled during the request. Success appears only after the committed RPC response.

Scoped history is paginated and includes permitted changed values, action, actor display name, server time and reason. It strips Auth/business/request IDs, hidden return references and raw snapshots. Raw audit records remain private to trusted backend history.

## Dispatch earnings boundary

T06 connects to a real narrow `private.post_dispatch_earnings(uuid,date,text)` interface, rather than returning success from a stub. Its separate `carrier_earnings` owner is NOLOGIN/NOINHERIT/NOBYPASSRLS, has no schema CREATE permission and can only append financial events/journal lines. Clients cannot invoke it or assume its role. The general account/master/operational owner still has no direct financial-event/journal write privilege. Migration administrative membership does not grant SET or inheritance after migration.

For each active consignment, the same dispatch transaction debits customer receivable and credits the historical owner entitlement and broker commission, using saved server-calculated exact amounts. Zero lines are omitted; an empty trip records its recognition marker with no financial events. Deferred balance constraints apply at transaction commit. All trip, journal, audit and retry changes either commit together or roll back.

A dependency-free dispatch-date correction appends one linked reversal and replacement per current recognized event; original events/journals remain immutable. Monthly earnings move to the corrected effective date while lifetime owner debt is unchanged. Receipts or allocations block reposting until a later explicit dependency plan exists. Issued document dependencies also block date reposting and their snapshots are never overwritten.

T07 must extend the financial engine with reviewed receipts, custody separation, locked claims/allocations, advance applications and generalized idempotent financial commands. T08 implements transfers/settlements/funding/credits, T09 actual expenses, T10 dependent correction/cancellation plans, and T11 reports. Dispatch currently rejects `advance_applications` rather than silently applying them. This task does not implement a financial Paid/Settled status.

## Acceptance scope

- AT-07: actual January dispatch, February arrival, dispatch-date reversal/replacement and exact monthly/lifetime earnings bases are tested through real RPCs and SQL. The March receipt dependency case uses a trusted zero-amount metadata fixture to test blocking and its independent effective date. It is not a completed receipt workflow. February expense posting, March payment posting, full lifetime profit and report UI remain NOT RUN until T07–T11.
- AT-08: multiple customer prices/counts/identifiers/stops, arrival delivering every active consignment, cancelled evidence retention and cancellation propagation are tested. Arrival leaves financial event/journal contents byte-equivalent.
- AT-12: origin dispatch/fare controls, destination arrival, administrator access, unrelated/anonymous denial, denied destination fare edits, revoked creator permissions and direct client write attacks are exercised on the backend.
- AT-15: creator versus colleague permissions, server audit attribution, idempotent retries, concurrent edits/arrivals (one commit and one conflict), immutable linked correction and blocked dependencies are exercised. The complete dependent allocation unwind/refund workflow remains T10.

## Verification corrections

The first migration attempt used the wrong identity for the default-argument `current_staff(boolean)` grant. An added detail query initially had an ambiguous `trip_id`; both were corrected. The monthly assertion initially used reserved SQL alias `month`; the test now uses `period_key`. Draft fixtures created after another dispatch initially lacked their own overlap review; the fixture now obtains one. SQL lint identified an implicit text-to-UUID-array initializer; it now uses a typed empty array. A privilege assertion initially treated the migration administrator's non-SET/non-inheriting administrative grant as a runtime role; it now checks actual SET capability. Analyzer brace notices were fixed. Final diff review repaired display separator encoding and a PowerShell encoding issue in progress notes before committing UTF-8 source. These failed attempts are not successful checks.

The Windows native test signs in as origin staff, dispatches with reviewed actual date/earnings/overlap, then signs in as destination staff, records arrival, checks persisted delivery/cancellation and opens history. Its temporary public configuration and synthetic password file are ignored and removed in `finally`. Ordinary debug builds replace the test binary before the package audit.

Final results are recorded below. Logs and generated artifacts remain ignored. No hosted deployment, Android device execution, release distribution or restoration is claimed. This task commits locally only and makes no GitHub push.


## Final executed checks

- Final clean local reset: all eight migrations PASS.
- `supabase test db`: five files, 110 assertions PASS. `supabase db lint --local`: no issues.
- `flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 32 tests PASS, including pending commit/no premature success, disabled duplicate submission, exact lost-response retry, new UUID on changed input, retained concurrent-conflict input and explicit fresh review replacing an old ticket.
- Final `python tools/tests/t03_api.py --trips --lifecycle`: 465 HTTP/SQL-backed assertions PASS, including final cancelled-load protection. The preceding combined `--lifecycle-native` run passed 467 assertions and the Windows native lifecycle test (57.7s build, 8s test); cancelled-load protection was added afterward and verified in the final backend run. After native verification, only display separator encoding was cleaned up in client code; final ordinary builds use that source. Analyzer-required braces were also added to a unit test.
- Ordinary Windows debug build exit 0 (42.7s); Android debug APK exit 0 (44.2s). Java 25 TLS 1.2/IPv4 flags retained. No Android device run or release signing claimed.
- `python tools/tests/t03_package_audit.py`: 686 APK entries, Windows files and tracked source files PASS, no actual local service/secret/JWT-signing/S3 values found. Build files, logs and private configuration remain ignored.
- Auth/REST/Storage health HTTP 200; PostgreSQL ready. Auth users, businesses, password operations, master/trip/lifecycle retries, recognition batches, trip sequences/reviews and storage objects: zero. Eight applied migrations; no disabled public triggers; temporary native credential configurations absent.
- All scoped T06 completion checks pass. Full financial acceptance boundaries above remain pending, not falsely marked passed. Work committed locally; no GitHub push.

SHA-256 for ignored ordinary debug artifacts:

- Windows runner `app/build/windows/x64/runner/Debug/carrier_records.exe`: `7040A70DFC5FB01749CA31AF9FE25585A3D1A3DB83BF858A39F2E3104B18BEC2` (the native runner itself is unchanged).
- Windows Dart code `app/build/windows/x64/runner/Debug/data/flutter_assets/kernel_blob.bin`: `97255015CB5868C1D77C79F1236F67DFEC2997514B6095469914E545B8C25A29`.
- Android `app/build/app/outputs/flutter-apk/app-debug.apk`: `F71A63FE9761718D0C22BAEF4010415F5198354F5C2320ECDA313A95DDDDA5D2`.
