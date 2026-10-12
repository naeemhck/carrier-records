# T19 guided field checks

Status: IN PROGRESS. Use this with windows-installation.md and windows-release-evidence.md. A prepared checklist is not a passed check. Keep completed records, names, receipts and signed sheets privately outside Git; source evidence records only the gate status and a private evidence reference.

## Current resources and next step

The user will initially use the development PC and act as the pilot operator. No physical printer is available. This PC is not a clean-machine substitute. Hyper-V inventory was denied by Windows permissions, so an available clean guest has not been verified. The installed release is 0.1.0+4. A new free `carrier-records-pilot` project has been created separately from the pre-existing project. Existing administrator mapping, completed password change, user-observed dashboard login, public configuration, company setup and two offices/administrator assignments are now verified. Session, restricted-role, network and actual pilot checks remain to be executed; setup does not imply these checks passed.

Use the verified project identity from the current session and windows-backend-prerequisites.md. Finish migration application, token hook, private Storage and Edge Functions, first administrator mapping, public client configuration and actual company/issuer/office setup. Never copy service keys or database credentials into client.json. Never run the empty-database fixture harness against a real pilot.

## 1. Clean Windows installation and visible login

1. Use a separate spare Windows x64 PC or an existing clean Windows guest. A fresh user account on this development PC does not satisfy the gate. If using Hyper-V here, an administrator must open Hyper-V Manager and identify a separate clean Windows guest; the agent's inventory permission failure does not prove that no VM exists. Do not use the Docker/WSL development VM, reset an existing machine or change host networking to make the check pass.
2. Copy the build-4 installer and this supplemental checklist through your trusted transfer method. Compare `Get-FileHash -Algorithm SHA256 -LiteralPath '<copied installer>'` against `c77439b6d4e6ac8e5f0ea781ad8b6229ced242609a47d16c503d217454d3dfc8`. Record OS/build, runtime, ordinary Windows user, version/hash, date and tester privately.
3. Install as that ordinary user. If the VC runtime is missing, follow the exact Microsoft administrator installation steps in windows-installation.md. Do not install development tools to make the app launch.
4. Open **Carrier Records** from Start, visibly. Before public configuration, expect setup refusal. Configure the public file using windows-installation.md; restart and sign in using the administrator-issued account. Complete its required password change locally. Record the actual home screen and role; omit passwords/tokens from screenshots.
5. If this is performed on the development PC first, label every result **development-PC pilot**, not clean-PC PASS. A hidden window/process, installation exit code, or compiled EXE alone does not pass visible launch/login.

## 2. Permissions, protected sessions and logout

Use one administrator and two administrator-controlled staff accounts assigned to different actual offices. A sole pilot operator may exercise these roles sequentially; record that one person performed the tests, not invented staff participants. Avoid disabling the only administrator.

| Attempt | Required result |
|---|---|
| Admin maintains company, accounts, assignments and shared presets | Allowed with audit/version behavior |
| Staff performs those admin actions | Denied, including direct requests |
| Origin-only staff edits agreed draft fare / dispatches | Allowed with normal review/version rules |
| Destination-only staff edits origin fare / dispatches | Denied unless also assigned origin |
| Destination staff marks actual arrival | Allowed; no receipt or owner settlement is created |
| Origin-only staff marks arrival at an unassigned destination | Denied |
| Staff searches/opens a trip involving neither assigned office | Denied or safely absent |
| Staff requests complete global balances | Denied; scoped reports remain clearly labelled |
| Staff uses an old preset/link after office removal | Access revalidated and denied where revoked |

A trip from office A to B is legitimately visible to staff of either office. Do not call that an office leak. Use an actually unrelated record for the unrelated-trip case; use an isolated security-test backend if real records cannot provide that case.

1. Sign in, close the installed app fully, reopen it and verify restored authorized access. Restart Windows and repeat. Compare public config fields: no password/token may be present. Do not extract protected-store contents into evidence.
2. Sign out, close/reopen and confirm fresh sign-in is required. Repeat for another staff role and verify the first role's session/data is not reused.
3. As admin, disable a designated staff account while its app session is open. Attempt refresh/read/save/export through the old session; all privileged access must fail without hidden data or a success toast. Re-enable via normal administration and require fresh authentication.
4. Remove one staff office assignment, retry the old trip/report/preset/receipt link, and check revoked access. Record real request status and scope separately from a hidden UI button.
5. For direct requests, use only public project keys plus the tested user's freshly authenticated bearer token, held locally in memory. Never use a service key. Known read-only permission probes: `authorize_trip_operation` with `{trip_id:<actual trip UUID>,operation:"EDIT_FARE"|"DISPATCH"|"ARRIVAL"}`, and `get_balance_summary` with `{scope:"ALL"}` (staff must receive FORBIDDEN) versus `{scope:"ASSIGNED"}`. The destination fare probe should use a trip whose origin it is not assigned to. Have the trusted tester retain only status/SQLSTATE and allowed boolean results, not tokens or unrestricted payloads. Unknown parameters/invalid UUID errors alone are not authorization evidence. Hosted probes are NOT RUN until executed as the actual roles.

## 3. Connection loss, recovery and retries

### Existing pilot staff: direct backend permission checks

The existing `pilot_khi` and `pilot_isb` accounts must finish their mandatory password changes in the installed app first. Sign out fully between users. Confirm each dashboard lists only its assigned office and does not offer company/account administration. Report UI outcomes separately from backend probes.

In your own interactive PowerShell terminal, run one command at a time:

```powershell
Set-Location -LiteralPath 'D:\portfolio\transport_project'
python tools/pilot_permissions.py pilot_khi
python tools/pilot_permissions.py pilot_isb
```

Enter each current staff password only at the local hidden prompt. No token/password is requested in chat. The helper reads the existing public-only installed config, requires the intended pilot HTTPS project, rejects privileged keys, authenticates the actual existing staff user, and holds its short-lived token only in memory. It checks ready role/one expected office, denied account administration and complete-business balances (HTTP403/SQLSTATE42501), allowed scoped balances and draft lists. Its own probe session is signed out with local scope; it does not globally log the app out. Sanitized check labels/statuses go to ignored `tools/.local/t19-permissions-<username>.json`; no response data, identifiers, balances, passwords or tokens are written. An unconfirmed probe logout remains a failure to resolve.

Trip-operation checks require one new, valid Karachi-to-Islamabad pilot draft, created through normal administrator/origin workflows with real pilot master records. Do not invent an actual dispatch/arrival or post test money into the pilot to manufacture a permission result. The current zero-vehicle/zero-trip state cannot pass this matrix. Once the draft exists, use:

```powershell
python tools/pilot_permissions.py pilot_khi --trip-checks
python tools/pilot_permissions.py pilot_isb --trip-checks
```

The helper requires exactly one matching draft on an untruncated first page. It calls the non-mutating `authorize_trip_operation` directly. Expected Karachi: EDIT_FARE/DISPATCH allowed, ARRIVAL denied; expected Islamabad: EDIT_FARE/DISPATCH denied, ARRIVAL allowed; both POST_MONEY/EXPENSE permissions allowed. These are operation-permission probes, not executed dispatch/arrival/payment/expense acceptance. Actual UI fare-save denial and lifecycle behavior still need the separately guided new-record pilot. With only two offices, a trip involving both is visible to both legitimately; unrelated-trip exclusion needs a genuine unrelated case or isolated fixtures, not a manufactured hidden business office.

Use a designated new pilot draft/transaction and keep its reference privately. Record starting state, exact amount and existing event/receipt IDs before the test. Never intentionally interrupt unrelated office work.

1. Open and fill a draft form while connected. Turn off this test PC's Wi-Fi or unplug its network cable using normal Windows controls. Click Save once. Expect an explicit failure/uncertain status, no success message and preserved form input. Do not close/recreate the form or replace its retry identity.
2. Restore the connection, verify backend readiness, retry the same reviewed operation, then refresh the trip/details/history. Verify one record/event, one amount and one canonical reference. Compare the event count/IDs with the baseline, not only the displayed balance.
3. Repeat for a reviewed payment on a designated new pilot record. Confirm no false payment success while disconnected and exactly one effective posting after retry; allocation and source-claim consumption must occur once.
4. A connection lost after clicking Save can leave a committed result with no reply. Treat it as uncertain: retain the same request, inspect permitted server history and retry canonically. Do not submit a new form to resolve uncertainty. Controlled deterministic lost-reply injection belongs on an isolated test backend using the T18 fault procedure, not arbitrary disruption of real pilot data. Prior T18 results do not count as an installed hosted test here.
5. Test logout/session refresh during connection loss; restored connectivity must not revive a signed-out or disabled account. Record any failure without declaring a saved action lost or successful without checking server state.

## 4. Physical printing and recipient privacy

No printer is currently available. Obtain access to a trusted physical office printer; Windows Print to PDF, PDF rendering and a queued spool job are not paper-output evidence. Add the printer through Windows Settings → Devices → Printers & scanners → Add a printer; use its manufacturer's official driver and have an administrator approve installation only if requested. Record model/driver/paper/orientation and inspect the actual pages.

1. In **Reports and outputs**, select report/output type, recipient template and the actual recipient, period, office and record filters. Use grouped attributes, select permitted fields, reorder them and Preview. Keep required company/issuer/document identity, applicable totals and period/scope.
2. Prepare each recipient below separately. Use new authorized records that yield multiple pages. For layout stress requiring invented names/car counts, use clearly synthetic isolated records rather than fake operational entries in the real ledger.

| Output | Paper/file must include | Must exclude |
|---|---|---|
| Customer | This customer's consignments/charges/receipts, selected eligible details and required total | Other customers' data; owner/broker internal settlement/profit information not in its catalogue |
| Owner | Historical owner earnings, owner-borne expenses and settlement details | Gross customer fares and brokerage |
| Broker | Permitted commission and relevant settlements | Owner profitability |
| Internal | Only data permitted by the logged-in role and office scope | Unassigned-office/global data for staff; credentials/Auth metadata |

3. Hide an optional attribute, reorder the remaining columns, and generate PDF and XLSX again. Canonical amounts and scope must stay identical. Compare selected field order in both actual files. Inspect XLSX for hidden sheets/columns/rows, formulas/external links and metadata; inspect PDF metadata/embedded objects as well as visible text. Do not export a hidden full-data payload.
4. Click **Print**, choose the physical printer and A4/AUTO orientation. Collect every paper page for all four recipient templates. Check required identity/scope, repeated headings, page numbering, row continuations, long-name/car-ID wrapping, selected order, legible money/totals, clipping and blank/missing pages. Verify each summary against the authoritative preview; never reconstruct money by adding continuation rows twice.
5. Print a digest-verified issued reprint after changing company/preset settings; the issued snapshot must remain unchanged. A correction uses a linked superseding document, not an overwritten original.
6. Record physical observations and private file hashes/page counts. Cancelled print, offline printer, pending queue, or PDF-only execution remains NOT PASSED. PDF can be an initial check on this PC, but the latest T19 instruction explicitly requires physical printing.

## 5. New-record office pilot and reconciliation

Start only after real company/issuer setup and backend/account checks. Use genuine new operations; no historical import/opening balances. Keep a private workbook or paper control sheet with record references, dates, original agreements, manual expected amounts, actual app amounts, discrepancy and reviewer. Do not commit it.

1. Create actual owner/broker/customers/driver/vehicle/route/category and offices with stable codes. Enter a new draft with several customer consignments/stops/cars, confirm server fare/brokerage reconciliation and any real overlap warning. Drafts must not recognize earnings.
2. Dispatch with actual date from the origin role, then arrive from destination. Verify consignment delivery and unchanged customer debt/owner settlement on arrival. Review a linked loaded/empty return when applicable.
3. Record actual trip-linked diesel and standalone maintenance once, including payer, cost bearer, funding and private receipt. Distinguish posting success from upload failure. Reimbursements/offsets reference the original expense and must not become brokerage.
4. Record actual partial receipts, retention and remittance with reviewed allocations. Reconcile customer debt, held money, owner due, commission due, credits, personal funding and recovery separately. Personally funded owner payment must not erase customer debt. Bulk allocations must exactly match the payment total.
5. Exercise agreed credit application/refund and creator/admin reasoned correction only where genuinely required; compare original/reversal/replacement history and retained receipts. Use isolated cases for forced dependency/concurrency errors that do not arise in actual pilot work.
6. Compare monthly reports on documented dispatch/expense/payment dates and lifetime trip profit. Reconcile each actual amount against its private control sheet; profit is not settlement. Review all four customized outputs with the intended operator/recipient scope.

Reference arithmetic only, **not observed pilot results**: deducted fare 100,000.00 / brokerage 5,000.00 means owner earnings 95,000.00. Receipt 60,000.00, retention 5,000.00 and remittance 55,000.00 leaves customer/owner due 40,000.00 and custody zero. Owner-paid diesel 10,000.00 gives owner profit 85,000.00 but settlement 95,000.00. Broker-funded diesel with agreed 10,000.00 offset gives cash remittance 85,000.00; cost is counted once. Substitute actual agreements and independently reconcile them.

## 6. Actual pilot and recovery sign-off

Use windows-pilot-checklist.md as the private result sheet. Record every check as PASS, FAIL or NOT RUN, with date, tester, environment and private evidence reference. No signature is collected merely by preparing this document.

The pilot operator must review discrepancies and explicitly approve new-record reconciliation and usable customized outputs. The recovery administrator must read restoration-evidence.md and restoration-setup.md: T17 independently keyed recovery 121.834s; T18 current-schema regression 88.202s, including Auth/staff/office mappings, balances/history, receipt bytes/hashes, issued digests, old-session rejection and fresh role access. Those are isolated local synthetic results, not restoration of this hosted pilot.

Confirm the pilot's applicable encrypted backups/receipt objects/manifests and separately recoverable key/passphrase are protected and available off-PC. Identify who can recover and which destination/runtime assumptions remain unverified. Archive creation does not prove restoration; do not claim hosted/spare-PC recovery from the old local rehearsal. Do not enable a production schedule or overwrite the pilot for a rehearsal. Record actual review/approval and unresolved risks privately. A sole operator may sign in each actual capacity, but do not invent independent reviewers or participants.

Required private statements, to be signed only after actual review:

- **Pilot approval:** I reviewed the referenced new operations, exact reconciliations, permissions, connection handling and customized outputs. Observed failures and unresolved gates: ____. Decision (approved / not approved): ____. Name/capacity/date/signature: ____.
- **Recovery approval:** I reviewed T17/T18's executed technical recovery evidence, the applicable backup/recovery material and documented runtime limits. I understand which pilot-target recovery checks remain unverified. Decision (approved / not approved): ____. Name/capacity/date/signature: ____.

Keep T19 IN PROGRESS until clean-PC, installed behavior, physical output, actual reconciliation and actual sign-off gates pass. A signature cannot substitute for a missing technical check. T20 stays TODO.
