# Build 0.1.0+6 verification continuation — 2026-10-12

Starting source: 235c65ed1b3a613dead6c81c88e699aedc96d8d5. Installed configuration and release artifacts preserved; no product code, migration, installation or rebuild in this continuation. T19 remains IN PROGRESS; T20 TODO. Windows restart, clean-PC installation, physical printing, office pilot and recovery sign-off remain pending.

## Rollback investigation and correction

The earlier combined regression failed positional equality of get_trip_financials before/after a deliberately deferred commit failure. Original snapshots were not retained, so that historical instance cannot be independently reconstructed. The corrections migration's replacement RPC aggregates balances without ORDER BY; claims explicitly order by line ID. Positional balance-array comparison therefore tests an unspecified order.

Fresh combined synthetic regression reproduced the same comparison failure mechanism in attempts 1–5: raw RPC snapshots differed, but canonical balance values matched and exact ordered full-row snapshots of financial_events, journal_lines, allocations, audit_events, idempotency_records, trips and consignments were unchanged. Attempts 6–10 also passed unchanged-state checks. Every failed request returned T07_COMMIT_FAILURE and left zero event/idempotency request rows. The same request subsequently succeeded. Balanced-event and single-dispatch checks passed.

Fix is confined to tests: sort only balances for comparison, preserving every field, value and duplicate; leave claims and metadata exact. Add whole-business database snapshots across the seven tables. No backend validation, transaction, authorization or accounting behavior changed. Two unit tests (including ten rejecting subcases) pass: balance permutation accepted; changed amounts, missing/extra/duplicate rows, claim amount/version/order, scope, label and completeness rejected. The permutation test demonstrates the old equality would fail on identical balance values.

First fresh run stopped before lifecycle/finance at synthetic receipt upload. Local Storage logged HTTP 544 DatabaseTimeout / connection terminated; fixture cleanup passed. Verified zero local businesses/Auth users, normal database activity, then restarted only supabase_storage_transport_project. No reset or hosted change. Rerun `python tools/tests/t03_api.py --trips --lifecycle --finance` exited 0 with 633 PASS assertions, including all ten rollback attempts and cleanup. Raw logs remain ignored in tools/.local/browser-resume-rollback*.log. The previous unresolved rollback gate is resolved by reproduced comparison sensitivity and fresh authoritative unchanged-state verification; no financial rollback defect found.

## Executed UI checks

| ID | Environment / source | Actual result |
| --- | --- | --- |
| R32 | Installed Windows, Computer Use | Launch returned installed Carrier Records window; capture timed out twice after fresh inventory recovery. No blind native input; capture issue is not an app failure. |
| R33 | Installed Windows, user observation | User reports logged in and dispatched labelled TRP-000002; confirms review acknowledgement before dispatch. |
| R34 | Installed Windows, user observation | User confirms second-draft Islamabad label and Cancel/Escape without dispatch. No independently observed saved second draft exists in refreshed list; do not infer its identifier or database writes. |
| R35 | Local release web / hosted backend | Existing protected session restored dashboard. Single clicks Trips, trip row, History and Payments work. TRP-000002 is DISPATCHED, Islamabad label, one DISPATCH audit transition, unchanged 50000.00 quote/owner entitlement, outstanding customer and owner claims 50000.00. No receipt or settlement entered by agent. Audit actor display name alone does not establish its role. |
| R36 | Local release web | Origin dropdown opens once, Karachi selection dismisses normally. Destination directory Islamabad selection renders Islamabad, not UUID. |
| R37 | Local release web | Created labelled TRP-000003 on second pilot vehicle, one car, exact quote 1.00, commission 0.00, owner 1.00. Server review and saved result agree. Reopening Edit retains Islamabad. |
| R38 | Local release web | Idle Dispatch Cancel and Escape both dismiss; DRAFT / no dispatch date remain. |
| R39 | Local release web | Invalid 2026-02-30 date with reason leaves Review and Confirm disabled. Valid 2026-10-12 enables Review only. During review Cancel remains enabled. Review response exposes unchecked acknowledgement; Confirm still disabled. Checking acknowledgement enables Confirm. |
| R40 | Local release web | One Confirm submits synthetic 1.00 dispatch. During posting all controls disabled and waiting-for-commit message visible; then DISPATCHED with actual date. History contains one DISPATCH and original CREATE_DRAFT. No repeated submit, payment, arrival or settlement performed. |
| R41 | Local release web | Audited zero-fee cancellation submitted for TRP-000003 with QA reason and 2026-10-12 effective date. Correction history retains original dispatch and adds 0.00 adjustment. Further refreshed-state/balance verification recorded below when observed. |
| R42 | Preserved web artifact | Audit passes: 43 files, 45078529 bytes, zero credential findings. main.dart.js SHA-256 3d8fd319e2a2201311f2d5f417a2d818c152e9423de1c2659b1ddb5d0180cb37, unchanged build6. |
| R43 | GitHub read-only verification | Origin exact https://github.com/naeemhck/carrier-records.git; authenticated naeemhck; repository PRIVATE/default main. Source/history audit passes: 277 tracked, 1 intended untracked, 534 historical blobs, zero findings (before evidence update). |

Prior password keyboard/clipboard probes used masked synthetic text, with no credential submission; installed login uses user-entered credentials only. Overlay/repeated-click allegations remain unconfirmed. Do not claim native automation, physical printing, clean-machine testing or pilot approval from these checks.

Delivery status: final documentation commit, ordinary push/equality, deployment and fresh-origin live UI checks pending at this entry. No production scheduling changed. Original/linked financial history must be retained during all QA cleanup.

R41 follow-up: explicit refresh returns CANCELLED, current charge/owner share 0.00, original consignment quote 1.00 retained. Payments overview shows customer outstanding 0.00 and owner settlement due 0.00. No receipt or owner-payment workflow submitted. Parent details initially retained cached DISPATCHED state until explicit refresh; not a failed cancellation transaction.
