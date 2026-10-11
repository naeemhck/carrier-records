# Implementation tasks and acceptance: Carrier Records

Version: 1.1 | Specification date: 2026-10-11

Current phase: T03 accounts, permissions and secure sessions DONE. T04–T20 remain TODO. Do not interpret a defined acceptance test as an executed test.

## 1. Status convention

Use TODO, IN PROGRESS, BLOCKED or DONE. DONE requires the stated evidence and relevant checks; record actual command/results or review evidence. A source scaffold is not a working feature. A build script is not an installer. A backup file is not a verified restore.

Dependencies refer to task IDs. Work in the sequence below; independent implementation work may overlap only when the required domain/permission contracts are already settled. Do not deploy, invent production identities, or mark tests passed from document examples.

## 2. Milestones

| Milestone | Gate |
|---|---|
| M0 — Specification | Six consistent planning files, customization included, cross-references and examples checked |
| M1 — Secure operational app | Accounts, masters, scoped trip entry and dispatch/arrival workflows work |
| M2 — Financial engine | Canonical journals, allocations, costs, corrections and reconciliation tests pass |
| M3 — Outputs | Recipient-specific customizable PDF/Excel, immutable documents and imports work |
| M4 — Windows pilot | Backup restoration, native installer, permission tests and measured pilot checks pass |
| M5 — Android | Signed APK, touch workflows and parity checks pass against the same backend |

## 3. Task backlog

### T00 — Generate and verify planning documents

Status: DONE — six Markdown documents generated; documentation checks recorded in memory.md.

Dependencies: Agreed requirements and output-customization revision.

Deliver PRD.md, architecture.md, rules.md, design.md, tasks.md and memory.md. Verify scope/counts, money examples, rule references, required customization behavior and honest implementation status. Bundle the six files for portable handoff. Completion does not mean app implementation.

### T01 — Establish Flutter and backend tooling

Status: DONE | Dependencies: T00

Use the existing VS Code Flutter SDK after checking its configured path/version. Inspect flutter doctor; install missing Windows C++ and Android/JDK prerequisites only as needed. Create the Flutter Windows/Android project and local Supabase tooling. Configure local/test environments separately from production. Pin compatible packages and commit lockfiles.

Evidence: Flutter analyzer/test harness works; generated runner files exist; dependency versions and build prerequisites documented. No credentials are committed.

Actual progress (2026-10-11): Read AGENTS.md and all six planning documents. Verified the existing VS Code SDK using `flutter --version` and `flutter doctor -v`: Flutter 3.47.4 stable / Dart 3.13.3. Generated `app/` Windows and Android runners. Added Riverpod/router composition, centralized English strings and a setup-only screen; no business feature or backend success is simulated. Pinned direct core packages and tracked `app/pubspec.lock`. Added SDK/CLI wrappers, ignored local tooling/configuration, and separate local/test public-config examples. Supabase CLI 2.120.0 downloaded from its official release, SHA-256 verified as `0db5224fc5d92ae5f15e675ed65dad376967326921122ab8d9a78e790874c92e`; `--version` and `init` succeeded. Local configuration disables signup and automatic Data API exposure, disables seed loading until T02, and sets a 5 MB storage limit. Docker Desktop 4.90.0 / engine 29.7.2 responds.

Executed checks: Dart formatter completed; `flutter analyze --no-pub` returned no issues; `flutter test --no-pub` passed the one application-route harness test. `flutter pub add` resolved/downloaded packages but returned exit 1 at Windows plugin symlink setup. `flutter build windows --debug --no-pub` failed on missing symlink support. `flutter build apk --debug --no-pub` failed because no Android SDK was found. Developer Mode registry change was denied for this non-administrator session. No AT-01–AT-35 scenario, native release, hosted deployment or restoration has passed. Further prerequisite/startup results are recorded in `docs/tooling-evidence.md`; T01 stays IN PROGRESS until remaining tooling checks are resolved.

Completion (2026-10-11): Existing Visual Studio/Android Studio installers finished without duplicates. Developer Mode enabled by user and verified. Standard latest v143 x86/x64 ATL installed; Windows debug build exits 0 after 126.2 seconds and produces `app/build/windows/x64/runner/Debug/carrier_records.exe`. Android SDK/API 36 and plugin-required API 35, build-tools 36, platform-tools, NDK and CMake installed; licences accepted. `flutter doctor -v` exits 0 with no issues. Android debug build exits 0 after 345.3 seconds and produces `app/build/app/outputs/flutter-apk/app-debug.apk` after verified Gradle download, IPv4 retry and disabling cross-drive Kotlin incremental caches. Supabase Auth/REST/Storage HTTP 200 and PostgreSQL readiness pass after disabling optional local analytics. Analyzer and one widget harness test passed. Exact failures, remedies and debug artifact hashes are in docs/tooling-evidence.md. No packaged installer, device launch, release APK, business acceptance scenario, hosted deployment or restoration is claimed. T01 completion checks pass; local Git only.

### T02 — Migrations and domain types

Status: DONE | Dependencies: T01

Implement architecture.md records, keys, constraints and indexes. Implement exact Money/rate/date/quote types and server pricing functions. Add seeded test fixtures only to isolated test environments. Include business/office context, party roles, owner snapshots and optimistic versions.

Evidence: Migrations apply to a clean database; quote tests AT-01/02/03 and precision AT-17 pass.

Actual completion (2026-10-11): Four migrations applied to a clean local database (reset first three, then pending role-link migration on the empty database). Added 27 application tables, business-scoped keys, party roles, owner/quote snapshots, versions, history guards, indexes and default-deny RLS/client grants. Added decimal-string server pricing and exact Dart Money/Percentage/BusinessDate/Quote plus UUID/context/command types. `flutter analyze --no-pub` passes; six Dart/widget tests pass; formatting check reports no changes. `supabase test db` passes 43 assertions and database lint reports no issues. Fixtures rolled back: business/Auth counts both zero; four migration records present. Post-reset Auth/REST/Storage health returns HTTP 200 and PostgreSQL accepts connections. Tests verify T02 quote/precision portions of AT-01/02/03/17; full dispatch, allocation, permission and financial-command scenarios remain NOT RUN until their tasks. First reset failure, fixture typo and lint corrections are recorded in docs/domain-evidence.md. No credentials or test identities persist; local Git only.

### T03 — Accounts, permissions and secure sessions

Status: DONE | Dependencies: T02

Implement admin-managed username/password accounts, disable signup, office assignments, disabled-user checks, temporary-password changes, secure session storage and admin-only account functions. Implement RLS and restricted function privileges; deny direct financial writes.

Evidence: Staff can sign in only when active and assigned; direct backend permission tests AT-12/13/14 pass. A client package contains no privileged keys.

Actual completion (2026-10-11): Implemented administrator-managed username/password accounts, role/status/office changes, forced temporary-password changes, resets, protected session persistence and logout. Signup remains globally disabled. Edge Functions keep Auth admin credentials server-side; public client configuration rejects privileged keys. Backend authorization checks live sessions, active assignments and credential revisions; RLS scopes trip/expense/receipt/journal reads and all ordinary direct financial writes remain revoked. Trusted local first-admin setup and interrupted-password recovery are documented in docs/accounts-setup.md. No actual business/staff identities were invented.

Executed checks: Final clean local reset applies five migrations; database lint reports no issues; 69 SQL assertions pass. Final HTTP suite passes 156 assertions, including AT-12 operation/office gates, AT-13 direct filtered financial writes (401/403 with PostgreSQL 42501), forged JWTs, privilege/status/assignment/password-flag bypasses, signup/private receipts and revocation; AT-14 denies complete/global or null staff scope and verifies explicitly labelled exact scoped versus admin totals. Pending-password recovery is fail-closed and tested. Ten Dart/widget tests and analyzer pass. Two Windows native integration tests pass (protected store and actual username sign-in/logout UI). Final Windows/Android debug builds exit 0 in 39.1s/42.2s. The final package/source audit scans 658 entries/files and finds no actual local service/secret/signing/S3 keys. Auth/REST/Storage return HTTP 200; PostgreSQL ready; synthetic Auth/business/password-operation/receipt-object counts return zero. Evidence/failures/remedies and artifact hashes: docs/accounts-evidence.md. T03 completion checks pass. AT-12 is verified at the authorization contract; T06 state transitions, T07 financial commands, T09 upload workflow, T11 full report UI, Android device execution and release/restore checks remain NOT RUN. Local Git only; no GitHub publication.


### T04 — Company and master records

Status: TODO | Dependencies: T03

Build company identity, offices, vehicle/owner/driver/customer/broker records, multiple party roles, route defaults and expense categories. Archive used records. Implement required setup before bill issuance. Use editable suggested office labels Karachi and Islamabad; collect real identities instead of invented production records.

Evidence: New/archived record flows work; historical owner and route snapshot checks AT-10/11 pass.

### T05 — Trips, consignments, stops and car records

Status: TODO | Dependencies: T04

Implement desktop-first draft entry, multi-customer consignments, stops, car counts/optional IDs, quoted fare/brokerage preview and server reconciliation. Build trip list/detail and scoped searches. Add linked empty/loaded returns and reviewed overlap warnings.

Evidence: Two offices can view only permitted journeys; multi-customer/return/overlap scenarios AT-08/09 pass. Incorrect client pricing cannot override server results.

### T06 — Dispatch, arrival and audit history

Status: TODO | Dependencies: T05

Implement lifecycle transitions with origin/destination permissions, actual dates, arrival-driven delivery, independent settlement state, audited edits, creator permissions and optimistic conflicts. Couple dispatch to the earnings-posting interface; block fake success until the transaction commits.

Evidence: AT-07/08/12/15 pass; arrival does not post receipts or settle owner debt. Cross-office fare edits are denied.

### T07 — Immutable financial engine

Status: TODO | Dependencies: T02, T03, T06

Implement account purposes and balanced journal events in rules.md. Build locked allocation/claim operations, exact validation, idempotency, dispatch earnings and explicit customer receipt/custody separation. Derive balances from effective events rather than editable summary totals.

Evidence: AT-01/02/04/16/17 pass. Every posting balances, unauthorized operations fail and duplicate retries create one event.

### T08 — Transfers, retention, funding and credits

Status: TODO | Dependencies: T07

Build actual remittances, owner settlement, commission retained/paid, custody transfers, personal funding, trip-linked advances, excess credits, explicit applications and refunds. Implement allocation UI with remaining balances and separate cash/offset components.

Evidence: AT-04/05/06/18 pass, including no custody overdraft and no repeated claim consumption. Owner payment does not erase customer debt when funded personally.

### T09 — Expenses, receipts and reimbursements

Status: TODO | Dependencies: T07, T08

Build expense entry with payer/cost bearer/funding source, private evidence storage, standalone maintenance and linked trip costs. Post owner-borne costs correctly for owner-funded, personally advanced and held-funds cases. Implement reimbursement/offset reference checks.

Evidence: AT-05/19/20 pass, including both diesel examples and no duplicated reimbursement. Receipt upload errors are distinguishable from financial posting.

### T10 — Corrections, cancellation and recovery claims

Status: TODO | Dependencies: T08, T09

Implement creator/admin correction workflows, reasons, operational history and append-only financial reversal/replacement. Unwind dependent settlements explicitly. Implement cancellation adjustments, fees, customer credits/refunds and recovery balances while retaining real expenses.

Evidence: AT-07/15/21 pass. A journal cannot be reversed twice; cancellation cannot quietly delete money or evidence.

### T11 — Reports and dashboard

Status: TODO | Dependencies: T10

Implement server-side aggregation for monthly vehicle/owner earnings, commission, expenses, receipts, credits, custody and claims plus lifetime trip profit. Date bases follow rules.md. Build dashboard/list navigation with 50-row pagination and scoped completeness labels.

Evidence: AT-07/19/22 pass, including expenses on earlier trips and scoped staff totals. Performance fixture is prepared without mixing test and production records.

### T12 — Field catalogue, customization and presets

Status: TODO | Dependencies: T03, T11

Implement server-owned field keys/eligibility/defaults/required flags. Build type/recipient/filter selection, grouped checkboxes, select-all-permitted, reset, ordering, preview and named presets. Implement personal versus admin-shared management. Revalidate presets on every use.

Evidence: AT-23/24/25 pass; selected fields do not alter financial calculations. Revoked access cannot be restored through a saved preset.

### T13 — Immutable document issuance

Status: TODO | Dependencies: T10, T12

Implement transactional numbering, customer-per-trip grouping, company/issuer/recipient snapshots, selected output configuration, template version, content digest and supersession links. Reprint from snapshots, not current source joins.

Evidence: AT-26/27 pass, including simultaneous issuance, changed issuer/company names and changed presets.

### T14 — PDF, print and Excel export

Status: TODO | Dependencies: T12, T13

Generate local files from redacted authorized payloads. Implement A4 automatic orientation, wrapping, repeated headings, pagination and summaries. Implement Excel selected-field order, metadata, formatting and safe text handling. Test actual file contents, including metadata and hidden sheets.

Evidence: AT-24/28/29 pass; Windows print and Android export/share checks are completed at their release gates. Visually inspect rendered multi-page PDFs.

### T15 — Template-based Excel imports

Status: TODO | Dependencies: T04, T05, T09

Define versioned templates for parties, vehicles, routes, trip/consignment/stop/car drafts and expense drafts. Resolve by stable record codes, use unambiguous dates and decimal values, reject formulas and show row-level errors. Repeat validation on the server and commit the reviewed draft batch atomically. Confirmation then follows normal operational/financial workflows.

Evidence: AT-30 passes, including duplicate batch retry, ambiguous references, invalid amounts and no partial commit. No historical/opening-balance import is added.

### T16 — Backup helper, encryption and status

Status: TODO | Dependencies: T03, T09, T13

Implement trusted administrator-only Windows helper and daily Task Scheduler setup. Use OS-protected credentials, database/Auth export, incremental receipt manifests/hashes, AES-GCM archives and a separate recovery key. Add manual action, last verified success, stale/failure indicators and off-PC reminder. Include backup traffic in free-tier monitoring.

Evidence: AT-31 passes for archive creation/failure handling and key protection. No backup secret is included in the distributed staff app.

### T17 — Restoration rehearsal

Status: TODO | Dependencies: T16

Restore a backup into an isolated clean environment. Verify schema, staff identity mappings/office roles, current balances, source/reversal history, receipt hashes and issued-document digests. Revoke obsolete sessions and verify subsequent authentication. Document sequence and measured recovery time.

Evidence: AT-32 passes with actual restored records and files. Do not call a generated archive a successful restore.

### T18 — Security, resilience and performance gate

Status: TODO | Dependencies: T10–T17

Run integrated acceptance suite using real restricted roles, altered requests, concurrent operations and connection faults. Audit client artifacts for secrets and exported files for forbidden fields. Seed one isolated year at the benchmark load and measure five-user concurrency, pagination and summaries.

Evidence: All applicable AT checks pass; p95 targets/results/environment recorded; remaining provider/runtime limits stated. No fabricated timing or coverage results.

### T19 — Windows installer and office pilot

Status: TODO | Dependencies: T18

Build release Windows binaries with installed tooling; package a per-user installer. Keep backend configuration public-client-only and document administrator setup. Install on a clean Windows machine, check launch/login, printer output and update workflow. Begin with new records and reconcile representative real trips before broader use.

Evidence: Installable artifact with version/hash, successful clean-machine run, printing, confirmed money totals, usable custom outputs and restore sign-off. A source ZIP is not this artifact.

### T20 — Android release

Status: TODO | Dependencies: T19

Finalize responsive touch layouts, protected signing key, secure session persistence, file saving/sharing and release APK. Verify the same permissions, financial rules, field picker and snapshots on a physical device. Distribute directly; no paid store publishing.

Evidence: Signed APK with version/hash and device/network results; no platform-specific calculation divergence.

## 4. Acceptance scenarios

All scenarios below are specifications; execution status is NOT RUN until implementation evidence is recorded.

| ID | Scenario | Required result |
|---|---|---|
| AT-01 | Deducted quote 100,000 / fixed 5,000 | Customer 100,000; owner 95,000; broker 5,000; dispatch journal balances. |
| AT-02 | Added owner quote 100,000 / fixed 5,000 | Customer 105,000; owner 100,000; broker 5,000. |
| AT-03 | Percentage and rounding | 5% follows quoted basis; half-paisa rounding is deterministic; invalid deduction rejected. |
| AT-04 | Broker receives 60,000, retains 5,000, remits 55,000 | Customer/owner outstanding each 40,000; custody zero. |
| AT-05 | Owner-versus-broker-funded diesel 10,000 | Owner profit 85,000 in both; required remittance respectively 95,000 or 85,000; no duplicate cost. |
| AT-06 | Customer advance 20,000 and excess credit | No draft earnings; explicit application consumes once; unused credit can be refunded. |
| AT-07 | Jan dispatch / Feb arrival/cost / Mar payment | Correct monthly bases plus complete lifetime profit; corrections explain changed historical reports. |
| AT-08 | Several customers/stops, office arrival | Separate total fares/car details; active consignments delivered; cancelled consignments stay cancelled. |
| AT-09 | Overlap and loaded/empty return | Warning requires confirmation; linked return allowed; empty journey has costs and no fare. |
| AT-10 | Vehicle owner changed | New trips use new owner; prior trips/statements preserve historical owner. |
| AT-11 | Route fare changed | Existing quotes remain unchanged; suggestion for new drafts changes. |
| AT-12 | Assigned-office and operation permissions | Origin controls fares/dispatch; destination arrival; unauthorized direct requests denied. |
| AT-13 | Privileged function/storage attack | Anonymous/disabled staff cannot execute writes or retrieve private receipts. |
| AT-14 | Staff requests complete global balance | Denied; scoped report accurately labelled; admin obtains complete totals. |
| AT-15 | Creator correction / version conflict / dependencies | Current permissions required; stale edit rejected; immutable reversal/replacement with reason. |
| AT-16 | Duplicate/concurrent posting | Same retry returns one result; conflicting request ID rejected; competing claim spend does not overconsume. |
| AT-17 | Paisa precision and allocation mismatch | Exact stored sums; extra payment decimals and unmatched allocations rejected. |
| AT-18 | Personal funding and custody transfers | Customer debt unchanged by owner-funded advance; custody transfer creates no revenue. |
| AT-19 | Standalone maintenance and different cost bearer | Monthly vehicle cost correct; only owner-borne costs reduce owner profit; reimbursement is not income. |
| AT-20 | Receipt failure/type/size/access | Private evidence; failure not reported as successful upload; unauthorized download denied. |
| AT-21 | Cancellation after payment/settlement | Explicit adjustments, credit and refund/recovery; real expenses retained; no second reversal. |
| AT-22 | Scoped aggregates and date basis | Source-level filtering; no global total leaked through summary or search. |
| AT-23 | Field selection/order/reset | Correct eligible fields and required locks; preview matches selected order. |
| AT-24 | Select fewer fields, export both formats | Same authoritative amounts; same eligible selection/order in PDF/Excel. |
| AT-25 | Inject forbidden field or stale/shared preset | Backend rejects unauthorized selection; preset grants no additional access. |
| AT-26 | Simultaneous issuance and supersession | Unique permanent numbers, linked replacement and no reuse. |
| AT-27 | Change company/issuer/preset/source after issuance | Original values and selected layout remain unchanged on reprint. |
| AT-28 | Long names/stops/car IDs/wide tables | Legible multi-page A4; headings repeat; no clipping; appropriate orientation. |
| AT-29 | Hidden data/formula injection | No forbidden payload/metadata/hidden sheets; untrusted text never becomes a formula. |
| AT-30 | Valid/invalid/repeated XLSX draft import | Clear preview; atomic reviewed commit; no duplicated rows or arbitrary journal upload. |
| AT-31 | Backup success/failure/PC offline | Verified encrypted archive and incremental files; last success truthful; missed schedule visible. |
| AT-32 | Restore with separate recovery key | Records, identities/permissions, receipt hashes and document snapshots verified in clean environment. |
| AT-33 | Interrupted network/auth expiry | No false save; input retained in memory; retry does not duplicate posting. |
| AT-34 | Five-user annual benchmark | p95 screen ≤2s and summary ≤5s target measured on documented active-backend conditions. |
| AT-35 | Windows/Android release | Actual install/launch/login/export succeeds; secret-free configuration and protected release signing. |

## 5. Release evidence record

2026-10-11 T03: AT-12/13/14 authorization-layer checks PASS on the disposable local Windows/Supabase backend, migration 20261011000500. Direct requests and native Windows session checks executed; see docs/accounts-evidence.md. This does not mark later lifecycle, financial posting, Android device or release acceptance complete.


For each executed scenario, record date, commit/migration version, platform, test environment, result and evidence path. Store example data without identifying real customers. Record failures and remediation rather than relabeling them passed.

Before pilot, administrator supplies actual company identity, five staff names/office assignments and twenty vehicle/owner records. These are setup inputs, not unresolved architecture decisions. Create a free Supabase project only in the user's account with authorized access; do not guess project identifiers or request passwords in chat.

## 6. Deferred backlog

After Windows and Android stability: Urdu UI/documents with reviewed translations; web client; additional-business onboarding if required; historical/opening-balance migration if explicitly approved; richer maintenance tracking. Reassess free-tier capacity before expansion. No deferred item is silently included in v1 progress.
