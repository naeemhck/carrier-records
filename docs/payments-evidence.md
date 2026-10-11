# T08 payment evidence

Executed 2026-10-11 on the existing Windows workspace, Flutter 3.47.4 / Dart 3.13.3 and loopback Supabase/Docker only. Starting local commit: `f3f5679994bab69b9be312b4da973ebde075717d`. Migration: `20261011001000_payments.sql`, ten migrations in total. All data used below is synthetic; no hosted deployment or GitHub push occurred.

## Implemented boundary

The public financial command now supports owner settlement, actual commission retention/payment, held-funds transfer, personally funded owner payment, funding recovery, customer advances, identified excess receipts, explicit credit application and funded refunds. Ordinary receipts retain the existing T07 contract. Excess receipts add an explicit `credits` array; its amounts plus the selected customer-claim allocations must equal the actual receipt total. Each credit identifies its customer through the payer and a permitted trip, optionally a consignment.

Custody transfers consume positive held-funds source lines and create new custody for the actual recipient, without changing earnings or liabilities. Owner/commission settlement consumes both the earned target and same-trip custody. Retention can have the same payer/recipient; transfers require different custodians. Personal owner funding consumes an earned owner claim and creates TRIP_FUNDING_PAYABLE for the funder, without writing customer debt or negative custody. Recovery uses an explicit funding claim and held source. Refunds consume unused customer credit and actual payer custody on the same trip. Applications are separately labelled non-cash, restricted to the same customer/trip and any original consignment restriction.

The restricted finance role appends balanced immutable events, journal lines, allocations, audit and retry records. It cannot update/delete them or create earnings recognition. Current staff/session/office and every trip/source/target relationship are checked before cached results; active receiving parties/offices are required for new postings. Ordered locks, exact aggregate source AND target consumption, and claim revisions prevent overdraft and repeated consumption, including several sources paying one target. Client journal/actor fields, wrong claim purposes/signs, unrelated customer credits, cross-trip sources, invalid money and mismatched totals are rejected. The general command role still cannot directly insert journals/events, and private helpers remain inaccessible to clients.

Funded draft vehicle/owner/offices/load identities and customer/consignment references cannot be changed or deleted, and cancellation is blocked until T10's explicit financial plan. Arrival delivery is still allowed. The existing atomic dispatch hook remains the sole recognition path. Trip-level credit application correctly attributes its customer-debt change to the selected target consignment; custody reductions retain source context.

The real app exposes **Trips → Trip details → Payments and allocations**, with permitted trip/party selectors, partial/bulk allocations, source and target remaining/resulting balances, cash versus non-cash components and identified credit remainder. Exact paisa/BigInt review validates sums independently of presentation. Every payment requires review. Pending confirmations disable edits/duplicate clicks; ambiguous retries retain the same request/body, conflicts require reload/review, and posting success is distinguished from a subsequent balance reload failure. Session/office guards also cover open selectors. See [entry guide](payments-setup.md).

## Actual checks

| Check | Executed result |
|---|---|
| Clean local reset, no seed | PASS: ten migrations applied |
| `tools/supabase.ps1 test db` | PASS: 132 assertions in seven files |
| `tools/supabase.ps1 db lint --local` | PASS: no schema errors |
| `python tools/tests/t03_api.py --trips --lifecycle --finance --payments` | PASS: 726 assertions, including T03/T05/T06/T07 regressions and T08 |
| `python tools/tests/t03_api.py --payments` after adding explicit source/credit-attribution attacks | PASS: 291 assertions; final T08 test source executed |
| `python tools/tests/t03_api.py --payments --native-payments` | PASS: 287 harness assertions; actual Windows receipt/retention/remittance UI and independent RPC persistence verification |
| Windows native integration | PASS: 86.1s build, 35s test; committed 60,000 receipt, 5,000 retention and 55,000 remittance |
| `tools/flutter.ps1 analyze --no-pub` in app | PASS: no issues, 15.7s |
| `tools/flutter.ps1 test --no-pub` in app | PASS: 42 tests, including exact cash/offset totals, ambiguous retry, commit waiting, conflict review and hiding a form/open selector after scope loss |
| Ordinary Windows debug build | PASS: exit 0, 67.4s |
| Ordinary Android debug build | PASS: exit 0, 110.7s; no device/release test claimed |
| Actual privileged-value source/package audit | PASS against ordinary Windows/Android artifacts and intended tracked source; no local service/secret/JWT-signing/S3 secret found |

AT-04 passes through public commands and native UI: customer/owner outstanding are both 40,000 and custody is zero. AT-06 passes actual draft advances without earnings, explicit applications with single consumption, identified excess credit, partial/full refunds, duplicate retries and competing refund requests. Trip-level credit is attributed to the selected consignment; spoofed application recipients and cross-trip custody are rejected. AT-18 passes personal owner payment with unchanged customer debt, separate funding recovery and custody transfer without new earnings. Actual commission payment from another custodian and owner retention are distinct, explicitly consumed events.

Partial and bulk remittances/funding exactly match entered totals; several sources can pay one target. Current-version overdrafts fail and competing transfers/refunds produce one commit and one conflict. Unauthorized, anonymous and unrelated-office direct backend attempts fail; ordinary direct table writes remain denied in the T03 regression suite. Each created event balances. An injected deferred ADVANCE commit failure returns failure, leaves no event/allocation/audit/retry/balance changes, and permits the identical request to succeed after removal. T06 and T07 deferred rollback/dependency checks remain passing.

**Deferred, not passed:** AT-05's owner/broker/held-funds diesel creation, profit and expense reimbursement/mixed-offset checks require T09. T08 verifies the non-expense owner-remittance/funding primitives; it does not claim the complete AT-05 case. Public expense/reimbursement workflows remain unavailable. Expense evidence/storage stays T09; dependent correction/cancellation plans stay T10; full profit/monthly reports stay T11. Receiving money or arrival does not automatically mean Paid or Settled.

## Verification corrections

- Initial funded-draft trigger used a shared-record CASE that referenced a nonexistent trip field. Replaced with table-specific branches; clean reset and actual draft/lifecycle/funded-cancellation checks pass.
- A destination-staff refund fixture initially chose an unassigned origin recording office. The backend correctly denied it. The test now records in the assigned destination office; permissions were not loosened.
- The test balance helper initially overwrote same-purpose balances for different custodians. It now adds exact Decimal values; transfer conservation is verified across parties.
- Removed an unsupported cancellation action from the fixture and asserted the real CANCEL_DRAFT dependency rejection.
- Initial widget test awaited a void view reset; corrected the test. Analyzer flow-control findings were fixed.
- Native tests initially missed a partly offscreen Confirm button, then an Action selector disposed outside the scroll cache. Added layout waits and directional scrolling; the real three-step native test passes. Ordinary main-entry builds then replaced the integration binaries before package audit.

## Final environment and artifacts

Auth/REST/Storage health: HTTP 200. PostgreSQL ready. Auth users/sessions, business/trip/expense/event/journal/allocation/audit/idempotency/receipt/storage records and all private operational/password/master retry fixtures: zero after cleanup. Public triggers enabled, ten migrations present, no remaining finance/security/earnings SET privilege for postgres, temporary native credential configuration absent.

Ordinary artifact SHA-256:

- Windows `data/flutter_assets/kernel_blob.bin`: `BE00B6EB2644A05375283EC5A9DDFFB8197D8A2E4DB053046312545B6AE7BB1E`
- Android `app-debug.apk`: `8E51F79ADE0C2B08A853FFBCDF46A8944B4DD64701122AE5BE70A62EE5EBD1F4`

Runtime logs/configuration and generated artifacts remain ignored. No production identities/data/credentials, signing material, receipts or backup archives are committed. No elevated administrator action is needed. This is a local source commit; the private source-backup checkpoint remains after verified T10 completion.
