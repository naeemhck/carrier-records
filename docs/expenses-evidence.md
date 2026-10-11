# T09 expense evidence

Executed 2026-10-11 in the existing Windows workspace, Flutter 3.47.4 / Dart 3.13.3 and loopback Supabase/Docker. Starting local commit: `b6a7cc342e2ad4f138c12d0d9764bfbee4e59f03`. Migration: `20261011001100_expenses.sql`; eleven migrations total. All records and receipt bytes below are synthetic. No hosted deployment or GitHub push occurred.

## Implemented boundary

Confirmed expenses record vehicle, optional trip, recording office, category, expense date, exact amount, actual payer, cost bearer, funding source and notes. They append one immutable expense and balanced financial event with audit/idempotency in a transaction. Self-funded owner costs change profit, never owner settlement. Other personally paid owner-borne trip costs explicitly consume reviewed earned owner claims and create separate expense reimbursement. Held spending additionally consumes identified custody without a personal reimbursement. A trip-wide cost does not change customer agreements.

Expense owner classification is captured from the historical trip owner or the vehicle owner at standalone entry; later master changes do not relabel earlier costs. Maintenance remains unlinked. Different bearers, pre-dispatch advances and costs exceeding available earned entitlement have separate cost-recovery claims. Original-expense recovery, reimbursement and later non-cash owner offsets consume explicit source/target claims once, with exact aggregate validation, ordered locks, revisions, UUID retries and live authorization before cached responses. Standalone settlement cannot change the original expense office or expose journal metadata to another office. Reimbursement/recovery/offset semantic commands use the existing REIMBURSEMENT event family with distinct journal purposes and allocation components; they create no cost or brokerage.

Scoped `list_expenses`, `get_expense_claims` and `get_expense_totals` enumerate permitted records, stringify money and preserve expense-date versus lifetime-trip bases. Cost totals derive from effective confirmed expense records, not editable counters or reimbursement amounts. Existing dispatch is reused, with no extra recognition. Draft identity/cancellation guards now protect incurred costs even without an allocation; arrival remains independent. T10 retains reversal/replacement, dependent settlements and cancellation plans; T11 retains complete report presentation.

The app's **Expenses and reimbursements** workspace supports standalone/trip entry, reviewed cash and owner-offset allocations, original-expense claims/reimbursement/recovery, optional private evidence and administrator abandoned-upload cleanup. Ambiguous posting retries retain their request/body; claim conflicts require reload/review; a definite validation rejection preserves fields for correction. Financial success follows committed RPC response. Upload retry is separate and keeps its own request/bytes. Permission guards cover forms and open selectors. See [entry guide](expenses-setup.md).

Private evidence uses actual byte length, supported PNG/JPEG/PDF signatures, matching MIME, a 5 MB limit and server SHA-256. Auth plus live SQL office/expense checks precede trusted upload/finalization; SQL confirms the Storage object before appending a link. No direct ordinary upload or finalization is available, and confirmed expenses are never updated for attachment. Authenticated downloads recheck RLS and persistent signed URLs are denied. Cleanup removes only unreferenced opaque objects older than 24 hours, with shared attachment locks and reserved expired paths; referenced receipts remain. Failed/ambiguous upload does not retry or reverse the financial posting.

## Executed checks

| Check | Actual result |
|---|---|
| Final clean local reset, no seed | PASS: all eleven migrations, including final standalone-office hardening |
| Database tests / lint | PASS: 148 assertions in eight files; no schema errors |
| Flutter analyzer / tests | PASS: no issues; 50 Dart/widget tests |
| Combined real backend/native suite: `python tools/tests/t03_api.py --trips --lifecycle --finance --payments --expenses --native-expenses` | PASS: 890 assertions; T03/T05/T06/T07/T08 regression checks plus real T09 posting, evidence and Windows UI |
| Final focused suite after standalone journal-office hardening: `python tools/tests/t03_api.py --expenses` | PASS: 309 assertions, including administrator attempts to reassign standalone recovery/reimbursement office and destination-only direct journal reads |
| Windows native expense test | PASS: 52.2s build / 13s test; real managed login, reviewed standalone expense 1234.56, separate private upload, authenticated byte download and independent persisted expense/link verification |
| Ordinary Windows debug | PASS: exit 0, 45.2s including command overhead |
| Ordinary Android debug APK | PASS: exit 0, 144.6s including command overhead |
| Actual privileged-value audit | PASS: ordinary APK entries, Windows files and staged project source; no local service/secret/JWT-signing/S3 secret values. Initial code audit scanned 715 entries/files; final staged source/documentation audit scanned 716 entries/files and passed. |
| Final local health | PASS: Auth/REST/Storage HTTP 200; PostgreSQL ready; eleven migrations; all synthetic identities, sessions, business/master/trip/expense/financial/audit/idempotency/private retry/evidence/Storage/abandoned-upload counts zero; triggers enabled; no finance/security/earnings SET privilege; temporary native configuration absent |

AT-05: both real dispatches earned owner entitlement 95,000. Owner personally paid 10,000 diesel: actual owner cost 10,000, profit 85,000, due and actual cash remittance 95,000. Broker personally advanced 10,000 with reviewed owner offset: profit 85,000, owner cash remittance 85,000, separate reimbursement 10,000 and commission 5,000. After recovery/remittance/retention all claims/custody are zero and each expense exists once. Held-funds diesel reduces owner due and custody directly with no personal reimbursement. Customer debt and agreed prices remain distinct.

AT-19: standalone maintenance 2,500 and another bearer's personally funded cost 3,000 stay outside lifetime trip cost. Actual cost-recovery receipt and reimbursement close the original expense claims without adding cost or income. At that checkpoint monthly vehicle cost is 45,500 and owner-borne cost 42,500. A January draft cost remains in January's expense-date totals and its trip's lifetime cost after later dispatch/offset. Costs above earned entitlement, concurrent offsets, full-consumption identical retries, competing reimbursements and later vehicle-owner changes pass. The final ownership change leaves every earlier owner-cost classification unchanged.

AT-20: anonymous/outside uploads, unsupported/mismatched MIME, oversized bytes, direct trusted finalization and persistent signed URLs are denied. Real Storage trigger failure returns an attachment failure while the 10,000 expense remains posted and unlinked; retry attaches the original evidence. Matching concurrent attachment retries create one reference; competing requests create one link and a conflict. Destination-only staff cannot retrieve standalone-office receipts. Revoked old JWTs cannot retrieve prior receipt URLs, metadata or cached financial results. Cleanup retains an older referenced receipt, removes its older unlinked alternative, and rejects expired-path finalization.

Deferred expense commit failure rolls back expense, journals, allocations, audit, idempotency and owner claim consumption; the original UUID succeeds after remediation. The combined suite retains T06 dispatch/receipt rollback, creator/office/version checks, pending delivery and earnings separation, plus T07/T08 exact balance/idempotency/custody/credit attacks. Every posted journal is balanced. Widget tests show no success before financial completion, identical posting retry, upload-only retry after financial success, and hiding of an open form/selector after permission loss.

## Actual failures and fixes

- Migration drafting caught PL/pgSQL CASE parentheses, temporary schema-owner privileges and an ambiguous SQL parameter name. Clean resets verified the corrected migration. The new evidence-link table required updating the schema assertion from 27 to 28 public RLS tables; old reimbursement-unavailable tests were replaced with live-session/expense-claim checks. An explicit JSONB initializer removed the lint warning.
- A fully consumed owner offset initially failed dynamic amount validation before cached-result/version handling. Dynamic validation now follows current-access checks, cached retry return and locked claim revisions. Full identical retries and competing offsets pass.
- Final review identified possible reassignment of standalone journal scope through the recording-office parameter. Standalone recovery/reimbursement now requires its original office. Administrator direct-call spoofing and destination-only journal reads are tested and denied. Final clean reset/lint/database tests verify this source.
- New form drafting exposed a nonconstant dropdown decoration and brace lint findings; compilation/analyzer/widget tests pass after fixes.
- Native UI itself passed, but its global logout correctly invalidated the harness's earlier staff token. The harness now obtains a fresh managed session before subsequent revocation checks; the full 890-assertion run passes.

## Artifacts and limits

SHA-256 Windows ordinary `data/flutter_assets/kernel_blob.bin`: `dd9ef1ff04ae3d21a35c60957b966c79a10ad9dcc1d33cc213bf36149fd145f5`.

SHA-256 Android ordinary `app-debug.apk`: `6c2cd5376c5ddc0cbe3c17d9fa97d877b5776bedc03e6c0f442cddec18238b9d`.

Ordinary rebuilds replace integration binaries; the native-only synthetic expense marker is absent from the ordinary artifacts. Builds, logs, synthetic native config and private operational directories remain ignored. No credentials, signing keys, actual receipts, database dumps or backup archives are committed.

Native file selection uses injected synthetic PNG bytes in the integration test; real Auth, database transactions, Storage upload and authenticated download are exercised. An actual operating-system file dialog, Android device execution, PDF rendering/printing, release installer/signing, production deployment, full report UI, dependent financial corrections/cancellation and restore are NOT RUN in T09. Images have a private guarded preview; PDF evidence is downloaded in memory with its size displayed, with full document viewing/export left to later document tasks. No Windows administrator action was needed. Local Git only; retain the source-backup checkpoint after verified T10.
