# T07 immutable financial engine

2026-10-11; local Windows, loopback Supabase and synthetic fixtures only. No hosted deployment or GitHub push.

## Contracts and scope

Migration `20261011000900_financial_engine.sql` adds the restricted NOLOGIN/NOINHERIT/NOBYPASSRLS `carrier_finance` owner. It can select the required source records and append events, journals, allocations, audit and idempotency records. It cannot update/delete confirmed financial history, create schema objects, or be assumed by clients. Empty definer search paths and closed private helper execution prevent direct kernel calls. The ordinary account/master/operational owner still has no direct financial table writes.

The eight purposes remain distinct: CUSTOMER_RECEIVABLE, CUSTODY_RECEIVABLE, OWNER_PAYABLE, BROKER_COMMISSION_PAYABLE, CUSTOMER_ADVANCE_CREDIT, EXPENSE_REIMBURSEMENT_PAYABLE, TRIP_FUNDING_PAYABLE and PARTY_COST_RECOVERY. Signed journal balances use debit-positive/credit-negative convention. They are not profit, revenue or a Paid badge.

`post_financial_event(event_kind, request_id, expected_version, payload)` exposes only CUSTOMER_RECEIPT in T07. Creation requires expected_version zero. Payload contains actual payer, recipient, recording office, ISO effective date, positive decimal-string amount, reason and explicit allocations. Each target has immutable line ID, derived claim revision and positive decimal-string amount. Every allocation must belong to the payer's customer claim, be accessible to the actor, and fit its remaining amount. Allocations sum exactly to the receipt amount. No client journal lines, actor/business metadata, financial state, arbitrary signed amounts or automatic excess credit are accepted.

Receipt debits recipient custody and credits only allocated customer receivables. Customer payment to an owner still leaves owner entitlement and brokerage unsettled. Payer identification is preserved; choosing a recipient cannot turn custody into owner settlement. Receipt before earning must use the later advance workflow. New receipts require active recipients/offices; committed identical retries remain available after recipient archiving, subject to current office/trip access.

The private `post_claim_event` supplies shared owner/commission settlement, funding recovery, expense reimbursement and advance-application primitives for later trusted workflows. These are unavailable through the client RPC. Custody/credit sources must match payer, trip and relevant customer/consignment; reimbursement targets require confirmed expense references. These primitives consume both identified source and target claims and identify CASH versus CREDIT_APPLICATION. T08/T09 still implement their full entry/review flows, creation of funding/advance/expense claims, transfers, offsets, excess credits and refunds. No later workflow is marked DONE by testing its kernel.

`claim_state` derives remaining claim from immutable source amount and signed allocation/reversal history. Reversed source events are closed. Revision is one plus allocation history count, not an editable balance counter. Commands take the account lock used by T06, recheck live authorization, then ordered claim advisory locks. The account lock serializes competing financial/lifecycle commands; aggregate source consumption is checked before any write. No UPDATE privilege on immutable journals is needed for locking.

Exact events, matched journal lines, allocations, server actor/date audit and payload-digested idempotency results commit together. Identical same-actor retries return the original result; conflicting payload/actor/request IDs fail. Current access to every referenced trip is rechecked before returning a cached bulk result. Balance is checked before constructing success and again by the existing deferred commit constraint. Exceptions roll back all effects.

`get_trip_financials` returns only the permitted trip's party/account balances and open claim references/revisions. It excludes global event amounts, actor/Auth/business/request metadata and other trips. Its label explicitly limits completeness to this trip. The existing invoker/RLS `get_balance_summary` now uses wider exact aggregate numerics, retaining assigned/global authorization. Balances sum immutable effective postings, including linked reversal/replacement effects; no mutable summary totals are stored. Full period/profit reports remain T11.

T06's dispatch hook is retained unchanged: saved server-calculated historical fare/owner/broker snapshots post once in the original atomic transaction. T07 reads/consumes those same journal claims; it does not recognize fare a second time. T06 date corrections continue to block dependent allocations, including receipts whose bulk event header has no trip ID. Arrival remains operational only.

The Flutter adapter provides typed account purposes, UUIDs, actual dates, customer allocations and receipt requests. Single transactions use integer paisa; wider aggregate balances use BigInt. Decimal strings are the only monetary JSON interface. Payment/expense entry UI is intentionally left to the documented later tasks.

## Acceptance evidence boundaries

AT-01/02/04 exercise real draft/dispatch/customer-receipt RPCs and the authorized private settlement kernel: deducted 100000/95000/5000, added 105000/100000/5000, and receipt 60000 followed by actual kernel retention 5000/remittance 55000. Customer and owner outstanding become 40000, custody zero. Full examples reach zero claims/custody while earnings remain separate. The private kernel tests do not claim completed T08 entry screens or client settlement commands.

AT-16 tests identical/conflicting and concurrent retries, one financial event/audit/idempotency record, competing customer and custody consumption, stale revisions and insufficient funds. AT-17 tests decimal type/precision/range/sign, exact paisa balances, mismatched/duplicate allocations and aggregate sums wider than a transaction.

Trusted balanced metadata fixtures seed future funding, advance, expense/reimbursement and cost-recovery claims solely to test the shared kernel and all eight purposes. They are not actual T08/T09 workflows, receipt uploads, profit reports or production records. The real receipt paths supply the tested custody sources.

## Verification corrections

Initial checks found a local-variable qualification error in the posting function and missing EXECUTE grants for exact-money/date parsers. Both were corrected. A destination-staff fixture used the origin recording office and was correctly denied; it now uses the destination office. Test-only administrative role membership is granted inside a transaction, reset/revoked on success, and rolls back on failed operations. The first combined functional run passed but fixture cleanup hit the confirmed-expense immutability guard. Synthetic-only cleanup now disables/re-enables that guard in its transaction, and the complete suite is rerun to verify removal and restored triggers. Failed attempts are not counted as successful verification.

Final results are recorded below. Synthetic Auth/business data, protected-history cleanup operations, temporary configurations, packages and logs are local only and excluded from Git. The harness refuses non-empty or non-loopback databases.


## Final executed verification

- Clean local reset applies all nine migrations: PASS.
- `supabase test db`: six files, 121 assertions PASS. Database lint: no issues.
- `flutter analyze --no-pub`: no issues. `flutter test --no-pub`: 36 tests PASS, including eight purpose types, exact wide aggregates, decimal-only receipt payloads, matched amounts, duplicate-target rejection and invalid claim/precision rejection.
- `python tools/tests/t03_api.py --trips --lifecycle --finance`: 602 assertions PASS, including the final synthetic cleanup. All AT-01/02/04/16/17 engine scenarios described above pass. T06 dispatch/arrival, creator/office/version rules, immutable date reversal/replacement and deferred commit failure regressions remain passing. Cash/custody/owner figures are derived from executed postings, not hard-coded expected totals in application state.
- Ordinary Windows debug build exit 0 (36.8s); Android debug build exit 0 (16.7s). No new native UI integration test was needed or executed for these backend/domain contracts. Existing T06 native evidence remains in docs/lifecycle-evidence.md. No Android device execution or release signing/distribution claimed.
- Package/source privileged-value audit: 692 APK entries, ordinary Windows files and tracked source files PASS. No actual local service/secret/JWT-signing/S3 values found.
- Auth/REST/Storage health HTTP 200; PostgreSQL accepts connections. Auth/business/events/journals/allocations/idempotency/private lifecycle/recognition/password/master/trip requests/reviews/sequences/storage counts: zero. Nine migrations; no disabled public triggers; postgres cannot SET carrier_finance or carrier_security after test cleanup.
- T07 completion checks pass at the documented engine boundary. All source work committed locally only. No push; backup checkpoint remains after T10.

Ordinary ignored debug artifacts, SHA-256:

- Windows Dart kernel `app/build/windows/x64/runner/Debug/data/flutter_assets/kernel_blob.bin`: `97255015CB5868C1D77C79F1236F67DFEC2997514B6095469914E545B8C25A29`.
- Android `app/build/app/outputs/flutter-apk/app-debug.apk`: `F71A63FE9761718D0C22BAEF4010415F5198354F5C2320ECDA313A95DDDDA5D2`.

T07 adds backend and reusable domain contracts; these files are not yet wired to a new client entry screen, so ordinary application artifact hashes are unchanged from T06. The financial contract tests execute the new Dart types directly.
