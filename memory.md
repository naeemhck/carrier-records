# Project memory: Carrier Records

Version: 1.1 | Last specification update: 2026-10-11

Purpose: Preserve agreed decisions across development sessions. This file is a decision/current-state record, not a second source of financial calculations. Read PRD.md and rules.md before implementing behavior.

## 1. Current state

- User authorized a private GitHub source-backup checkpoint after T10 is DONE. T10 completion checks now pass. Commit, verify the private destination, push main without force and verify its remote commit; record the actual push outcome below. Public publication remains unauthorized.

- Six planning documents and AGENTS.md have been read. The business scope and financial invariants remain unchanged.
- Workspace: D:\portfolio\transport_project. Local Git history is preserved. User-authorized private source backup origin is https://github.com/naeemhck/carrier-records.git; the prior backup verified private visibility and remote/local main at d260f08d400dce5e84a3995ea70ce14872f17a9c. T05-T09 were committed locally; their backup is now authorized together with completed T10. Credentials and private operational data remain excluded. See docs/source-backup.md and docs/corrections-evidence.md.
- T00-T10 are DONE; next T11 reports and dashboard. T11-T20 remain TODO. Draft figures remain potential fare; dispatch recognizes agreed earnings atomically, while arrival and financial settlement remain independent.
- Existing VS Code SDK verified: Flutter 3.47.4 stable (9584c6713b), Dart 3.13.3. tools/flutter.ps1 resolves the configured SDK. T01 developer mode, standard v143 ATL, Visual Studio/Android/JDK/SDK prerequisites and licenses passed; exact installation failures/remedies remain in docs/tooling-evidence.md. No installer duplicates were started during T03.
- App keeps Riverpod composition/go_router navigation with an Auth adapter, staff username sign-in, mandatory password change, administrator account creation/edit/status/offices/reset and logout. Protected FlutterSecureStorage replaces session SharedPreferences. Explicit persistence errors fail sign-in; pending writes/deletions serialize; stale refreshes cannot restore a signed-out profile. Windows native protected storage and real local username sign-in/logout UI tests passed. Android backup is disabled; Android protected-store device execution remains T20 verification.
- Public config: APP_ENV, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, APP_BUSINESS_ID. No privileged key belongs in client configuration. Actual first administrator/company/office identities have not been created; supply real inputs using python tools/manage_accounts.py bootstrap (hidden password prompt, local backend only), then use the administrator Company and master records workspace. See docs/accounts-setup.md and docs/masters-setup.md.
- Supabase CLI 2.120.0 / local Docker stack only, no hosted link/deployment. Auth/REST/Storage health HTTP 200 and PostgreSQL ready after final verification. Global signup, anonymous sign-in and manual linking remain disabled; the password/email provider is enabled because disabling it also disabled managed logins. The custom token hook is enabled and rejects absent/disabled/unassigned/pending accounts.
- At T04, six migrations implemented the 27 public T02 tables, T03 account/security operations and T04 versioned master commands/private retry records. The shared command owner is NOLOGIN/NOBYPASSRLS with explicit master/account privileges and no direct financial writes; temporary schema CREATE and migration-owner membership are revoked. Three fixed private Auth lookup/session helpers use the trusted migration owner and are unavailable to clients. Server checks active profile, current credential revision, live Auth session, office assignment, password-change gate and operation eligibility. Mutable Auth metadata grants nothing.
- Administrator-only Edge account endpoint verifies bearer tokens through Auth and live SQL authorization. Auth service calls stay in the runtime. Account/office/status/password changes revoke target sessions. All ordinary direct table writes (including financial events, journals, allocations and idempotency results) remain denied for administrator and staff JWTs. Global event metadata stays closed; assigned-office balance summaries use source RLS and exact decimal strings. Full posting/report commands remain T06/T07/T11.
- Interrupted password updates lock the target and revoke sessions before calling Auth. Successful finalization forces reset-password users to change their temporary password. Trusted local recovery was tested; failures never report partial work as success. Passwords are absent from audit/operation records and are never written to setup files.
- T02 exact Money/Percentage/BusinessDate/Quote, command types and immutable history/snapshot constraints remain intact. T04 clean reset applies all six migrations; 83 SQL assertions and database lint pass. Analyzer has no issues; fifteen Dart/widget tests pass. The T04 native Windows administrator create/edit/archive workflow passes, in addition to the previously executed T03 protected-storage and staff sign-in/logout tests. Final local API suite passes 302 assertions, preserving T03 direct-write/JWT/signup/private-receipt/scoped-balance/recovery attacks and adding T04 master authorization, history, exact fares, archiving, create/update retries, null/stale/concurrent versions and office archive access removal.
- T03 AT-12/13/14 authorization checks PASS. Origin fare/dispatch, destination arrival, both-office payment/expense eligibility and unrelated-office denial are verified at the backend authorization contract; actual state/posting commands remain later tasks. Staff global balance access is denied; labelled scoped and administrator-complete fixture totals are exact. Storage privacy tested using synthetic objects; upload/content workflows remain T09.
- T04 ordinary Windows debug build succeeds in 150.5s and Android debug build in 151.1s. Package/source audit scans 667 entries/files and finds no actual local service, secret, JWT-signing or S3 credentials. No release signing/installer/Android device/production distribution is claimed. Artifacts/configuration/logs remain ignored. T04 artifact hashes, failed attempts and corrections are in docs/masters-evidence.md; earlier T03 evidence remains in docs/accounts-evidence.md.
- T04 final Auth/REST/Storage health returned HTTP 200; PostgreSQL accepts connections. Auth users, businesses, private password operations, private master retries and storage objects all return to zero; migration count six. Native test configuration is removed. No credentials or business data are committed. Setup steps, actual failures/corrections and T04 evidence are in docs/masters-setup.md and docs/masters-evidence.md.
- T04 permissions: administrator-only master mutation and company maintenance; staff receive active entry choices without contact/Auth/creation/version metadata or archived rows. Destination office choices grant no access. Same-business active origin permission is required for server trip defaults. Office archive immediately removes affected office access; administrators retain history. Party roles are archived rather than deleting historical links. New defaults reject archived owners/drivers/roles/vehicles/routes/offices. AT-10/11 changes to current owner, owner contact/name and route defaults leave prior trips, agreed quotes and issued snapshots unchanged. Used category/party archive preserves saved expenses; master edits never create financial events.
- `require_document_setup()` verifies explicit company setup and current issuer display values. T13 must call it inside the issuance transaction. T05 captures server `get_trip_defaults()` values and requires explicit review of suggested fares; a suggestion must never replace a saved agreement implicitly. T04 test trip/quote/document insertion uses trusted synthetic SQL fixtures, not completed T05/T13 commands. No elevated Windows action is needed for T04.

- T05 implements guarded draft list/details/editor, office/vehicle/state/date/party searches (50-row pages), multiple customer consignments, ordered stops, optional car IDs, integer-paisa/BigInt previews, explicit route suggestions and server-derived prices. Aggregate mutation is origin/creator-controlled or administrator, with expected version, UUID retries and audited before/after values. Backend/RLS scope does not expand through searches, destination choices, spoofed origins or direct calls. Unchanged references preserve historical owner/route/agreed fare; archived existing customer agreements remain editable while new selection is denied.
- T05 linked loaded/empty returns reverse offices on the same vehicle and reject cycles/dependency changes. Any other DISPATCHED trip on that vehicle requires explicit confirmation, reason and an actor-bound ten-minute review ticket. Hidden conflicts disclose only a generic warning. T06 must share the `trip-vehicle:<UUID>` advisory lock and account-lock order with draft saves; changed conflict versions invalidate old reviews.
- T05 actual functional evidence: clean reset with seven migrations, 95 database assertions, database lint, analyzer and 26 Flutter tests PASS. Real HTTP/native suite passes 344 assertions including T03 regression attacks, forged client prices, office/creator checks, direct-write denial, retries/concurrency, history, linked returns, child reorder/removal/empty conversion, archived-customer retention and overlap review attacks. Real Windows staff list/detail/editor/save test passes and persisted native edit is checked by admin RPC. AT-08 draft portion and AT-09 draft return/overlap/zero-fare portion pass; arrival/delivery/cancelled propagation is explicitly NOT RUN until T06, and expense/financial posting remains later tasks.
- T05 ordinary Windows/Android debug builds pass (66.6s/67.0s); native test build 65.2s. Local Auth/REST/Storage health HTTP 200, PostgreSQL ready; all synthetic Auth/business/password/master/trip-retry/sequence/review/storage objects return to zero. Temporary credential config removed. Final package/source audit passes 678 entries/files with no actual local service, secret, JWT-signing or S3 credentials. T05 completion checks pass and work is recorded in a local commit; no T05 GitHub push. Evidence and failures/corrections: docs/trips-evidence.md. No elevated administrator action is needed.

- T06 implements Draft to Dispatched to Arrived plus retained unposted cancellation; origin dispatch, destination arrival, actual ISO business dates and audited backdating. Active consignments become delivered together; cancelled fare/count/car evidence remains cancelled and cannot be deleted or rewritten through draft saving. First operations may be recorded by permitted colleagues; subsequent trip/dispatch/arrival corrections require their respective creator and current operation/office permission, or admin. Scoped history strips Auth/business/request IDs and hidden snapshots. Locked versions reject stale/concurrent edits; client success waits for the committed backend response. Dispatch overlap requires a current actual-date review, not just a saved draft flag.
- T06 migration 20261011000800 adds private lifecycle retry/recognition records and a narrow private dispatch-earnings hook owned by separate NOLOGIN/NOINHERIT/NOBYPASSRLS carrier_earnings. Only the lifecycle owner invokes it; clients have no role membership or helper access. It can append financial events/journals but cannot modify/delete them or create schema objects. The ordinary account/master/operational owner still cannot directly write journals/events. Migration administrator retains only a non-SET/non-inheriting administrative grant. Actual dispatch debits customer receivable and credits saved historical owner entitlement/brokerage in the same transaction; empty dispatch has no financial events. Dependency-free dispatch-date corrections append linked reversals/replacements rather than rewriting the source; dependent receipts/allocations or issued documents block reposting. Arrival never changes journals or creates receipts/owner payments.
- T06 actual evidence: final eight-migration clean reset, 110 SQL assertions, database lint, analyzer and 32 Flutter tests PASS. Final combined account/draft/lifecycle HTTP suite passes 465 assertions including denied cross-office fare/direct writes, creator and revoked-office checks, every pending AT-08 delivery/cancellation check, cancelled draft evidence protection, concurrent correction/arrival conflicts, exact idempotent linked date reposting, and injected deferred commit failure with complete rollback. Windows native origin dispatch to destination arrival and history PASS (57.7s build, 8s test), with real RPC persistence verification. Ordinary Windows/Android debug builds exit 0 in 42.7s/44.2s. Package/source privileged-value audit passes 686 entries/files. Auth/REST/Storage HTTP 200, PostgreSQL ready; Auth/business/private lifecycle recognition/retry/password/master/trip review/sequence/storage fixtures zero, all public triggers enabled, temporary native credentials absent. No elevated administrator action, hosted deployment, Android device test, release/restore or GitHub push is claimed. See docs/lifecycle-evidence.md for contracts, hashes and corrected verification failures.
- T06 acceptance boundaries: AT-08 arrival/cancelled propagation and AT-12 lifecycle permissions PASS. AT-07 January dispatch/February arrival/monthly earnings correction and AT-15 creator/version/immutable date repost/dependency blocking PASS at the implemented boundary. A trusted zero-amount March receipt fixture only checks dependency metadata/date independence, not completed receipt posting. February expense posting, March real payment, lifetime profit and report UI remain NOT RUN for T07-T11. T07 must extend the real narrow dispatch interface with general immutable postings, locked claims/allocations, receipts/custody and reviewed advance applications (currently rejected). T08 settlement/transfer/funding/credit, T09 expense and T10 dependent correction/refund/cancellation plans remain pending. Never equate Arrived with Paid or Settled.

- T07 implements a restricted carrier_finance posting/claim kernel and the public CUSTOMER_RECEIPT RPC. Financial-event/journal/allocation/audit/idempotency tables remain append-only and direct client writes stay denied. All eight documented account purposes remain distinct. Each receipt has actual payer/recipient/recording office/date, positive decimal amount, reason and exact explicit customer claim allocations. Customer debt reduction increases recipient custody, never automatically settling owner entitlement or brokerage. Receipt before the earning date requires the later advance workflow. New recipients/offices must be active; an identical committed retry can still return after recipient archiving under current permissions.
- T07 claim availability and revisions are derived from immutable lines and signed allocation history; reversed source claims are closed. Commands use the existing account lock, live authorization recheck and ordered claim locks, validate aggregate source consumption, then append one balanced event and all allocation/audit/retry data atomically. Same-actor identical retries return one original result; changed bodies/actors or stale claims conflict. Bulk requests require access to every trip before write or cached-result return. T06 dispatch earnings are reused as claims and are not posted again; its rollback and dependent-date-correction guarantees remain verified. No client success precedes committed response.
- T07 read APIs derive exact trip/party/account balances from effective immutable journals with an explicit trip-only scope label. Global/assigned summaries retain invoker RLS and now support wider NUMERIC(38,2) aggregates. Typed Dart receipt/claim contracts use integer paisa, decimal strings, UUIDs and actual business dates; aggregate parsing uses BigInt. There are no editable balance summaries or automatic Paid/Settled statuses.
- T07 actual verification: final clean reset applies nine migrations; lint no issues; 121 SQL assertions, analyzer and 36 Flutter tests PASS. The combined account/draft/lifecycle/finance suite passes 602 assertions, including AT-01/02/04 real dispatch/receipt plus private canonical retention/remittance, AT-16 conflicting/duplicate/concurrent requests and competing customer/custody spend, AT-17 precision/sign/type/allocation/wide-aggregate checks, correct office/party authorization, archived-recipient retry, source overdraft denial, immutable event totals and deferred commit failure with no partial event/allocation/audit/retry/claim changes. Ordinary Windows/Android builds exit 0 in 36.8s/16.7s; package/source audit passes 692 entries/files without actual local privileged values. Auth/REST/Storage HTTP 200, PostgreSQL ready; synthetic Auth/business/events/journals/allocations/idempotency/private cache/storage counts zero; public triggers enabled; no remaining finance/security SET privilege for migration/test administrator. Evidence, failures and hashes: docs/financial-engine-evidence.md. No T07 native UI run, hosted deployment, release/restore or push is claimed.
- T07 scoped completion is DONE. Full T08 transfer/retention/settlement/funding/credit/refund entry and reviewed advances remain next; the T07 public wrapper rejects those kinds. The private kernel supports shared claim consumption only. Its funding/expense/advance/cost-recovery fixture tests are explicitly metadata tests, not actual T08/T09 creation workflows, receipt uploads or profit reports. T09 expense/evidence/mixed-offset workflow, T10 dependent correction/cancellation plans and T11 full date-basis/profit reports remain pending. Preserve the user's private backup checkpoint after T10; do not push T07.

- T08 implements public owner remittance/settlement, actual commission retention/payment, custody transfers, personal owner funding/recovery, customer advances, explicit excess receipt credits, applications and funded refunds. Customer receipt, held money, owner/commission due and personal funding stay distinct. Personally paying an owner does not reduce customer debt. Transfers do not recognize earnings. Credits remain customer/trip/optional-consignment specific; refunds and applications consume identified claims exactly once.
- T08 reuses the restricted T07 kernel and atomic T06 dispatch claims. Both source and target aggregate consumption are locked/versioned, including several sources paying one target. Semantic money creation/transfer/refund commands use strict fields, exact decimal strings, actual payer/recipient/date, live trip/office authorization before retries, immutable balanced postings/audit/idempotency and no direct client financial writes. Funded draft identities/customer links and cancellation are protected; arrival delivery remains independent. Non-cash trip-credit applications correctly retain target consignment context and custody consumption retains source context.
- T08 real Payments and allocations entry opens from trip details, supports explicit partial/bulk sources/targets with remaining/resulting balances and cash/offset/credit totals, and uses integer paisa/BigInt. Every command is reviewed, success follows commit, lost responses reuse the reviewed request, conflicts require reload, and successful posting with failed balance reload is shown separately. Guards hide payment forms and open selectors after changed account/office access.
- T08 actual evidence: ten-migration clean reset, 132 SQL assertions/lint, analyzer and 42 Flutter tests PASS. Combined account/draft/lifecycle/finance/payment backend suite passes 726 assertions; expanded account/payment suite passes 291 assertions including source/recipient manipulation and trip-level credit attribution. Native Windows account/payment harness passes 287 assertions; real UI receipt 60000, retention 5000, remittance 55000 independently persist, leaving customer/owner due 40000 and custody zero (86.1s build/35s test). Ordinary Windows/Android builds exit 0 (67.4s/110.7s); actual privileged-value source/package audit PASS. Auth/REST/Storage HTTP 200, PostgreSQL ready, synthetic Auth/business/trip/expense/journal/event/allocation/audit/idempotency/private retry/receipt/storage rows zero; triggers enabled, ten migrations, no remaining finance/security/earnings SET privileges or native credential config. See docs/payments-evidence.md for failures, fixes, contracts and hashes; docs/payments-setup.md for entry.
- T08 scoped checks are DONE: AT-04/06/18 and non-expense settlement/funding primitives pass. Complete AT-05 diesel, profit, expense reimbursement and mixed expense offsets remain explicitly DEFERRED to T09. Public expense/reimbursement commands remain unavailable, T10 retains dependent correction/cancellation plans, T11 retains full reports, and Android device/release/restore is not claimed. No elevated Windows action, hosted deployment or GitHub push occurred; preserve the private backup checkpoint after verified T10.


- T09 is DONE. Earlier task-time boundaries above are historical; the T09 checks supersede expense/upload deferrals. Confirmed expenses save vehicle, optional trip, office/category/date, exact cost, payer/bearer/funding and historical owner classification. SELF_FUNDED_COST changes cost/profit without owner due; explicit personally advanced/held owner offsets consume earned claims, with separate reimbursement or custody consumption. Draft/standalone/different-bearer/excess costs use separate recovery claims, and later explicit owner offsets consume the original expense once. Reimbursement is neither brokerage nor another cost. Standalone settlement retains the original expense office, including journal metadata.
- T09 private evidence is independently appended after financial commitment. Trusted Edge Auth/live-office checks, actual signature/MIME/5MB length/SHA-256 and SQL object metadata validation precede linking. Authenticated downloads recheck RLS; signed URLs/direct ordinary upload/finalization are denied. Upload failures retry attachment only with a separate UUID. Administrator cleanup reserves and removes only unreferenced opaque objects older than 24 hours; referenced receipts remain. Guards cover expense forms/selectors. No client privileged credentials or new earnings are introduced.
- T09 actual evidence: final clean eleven-migration reset, 148 SQL assertions/lint, analyzer and 50 Flutter tests PASS. Combined account/trip/lifecycle/finance/payment/expense/native run passes 890 assertions; final standalone-office authorization suite passes 309. Both real diesel profits are 85000, with owner cash95000 versus85000, reimbursement10000 and brokerage5000 separate. Maintenance/different bearer/monthly/lifetime/historical owner, duplicate and competing financial/evidence requests, actual Storage failure, deferred commit rollback, old JWT revocation and direct backend permission attacks PASS. Windows native expense1234.56/private receipt/persisted link/authenticated bytes PASS (52.2s build/13s test). Ordinary Windows/Android builds exit0 (45.2s/144.6s); source/package credential audit PASS. All synthetic identity/session/business/financial/private retry/evidence/Storage/abandoned-upload data zero; health HTTP200/PGready, triggers enabled, eleven migrations, role SET privileges revoked and native config removed.
- T09 contracts, failures/fixes and artifact hashes: docs/expenses-evidence.md; user entry: docs/expenses-setup.md. The first native UI run correctly globally logged out its staff session; the harness was fixed to log in again before revocation tests. Full-owner retry validation now follows cached-result/version handling. Standalone office spoofing is denied. T10 must implement linked corrections/dependent unwind/cancellation, and T11 full reports. Actual OS file-dialog execution, Android device/release/restore and production deployment remain NOT RUN. No elevated Windows action or GitHub push; preserve the backup checkpoint after verified T10.

- T10 DONE (2026-10-11): migration 20261011001200 adds reviewed creator/admin corrections, exact linked journal/allocation reversals, semantic replacements, audited fare edits, retained/effective expense history, explicit cancellation fees/credits/recoveries, recovery receipts and personal refund funding. Private transaction capabilities allow only vetted cancellation state changes; no direct client journals or privileged client keys. Cancellation-fee corrections explicitly unwind dependent refunds/recoveries. Financial source corrections cannot silently erase dependent actual expenses or invalidate a cancelled trip plan. Original expenses/evidence and operational dates remain; effective reversals use original dates and replacements explicit corrected dates. Full report presentation remains T11 and document issuance T13.
- T10 actual verification: clean 12-migration reset PASS; 163 SQL assertions PASS; lint no errors with unused-variable warnings recorded; final analyzer no issues; 52 Flutter tests plus two focused correction tests PASS. Combined real account/trip/lifecycle/finance/payment/expense/correction suite passes 1,062 checks, including Windows native creator correction and independent linked expense replacement verification (59.7s build/8s test). Ordinary Windows/Android debug builds PASS (37.7s/50.3s); privileged-value audit PASS across 726 source/package entries. Auth/REST/Storage HTTP 200, PostgreSQL ready, public/private/Auth/Storage synthetic records zero, triggers enabled, temporary role SET access and native config absent. AT-07/15/21 pass at the documented implemented boundary; T06 rollback/arrival separation and T07-T09 regressions preserved. Failures and fixes, exact golden balances and hashes: docs/corrections-evidence.md. No administrator action needed.
- T10 checkpoint preparation: origin remains https://github.com/naeemhck/carrier-records.git; existing Git Credential Manager authentication and GitHub API verify naeemhck ownership, private=true and visibility=private. Credentials stay only in memory. Read-only source/history audit passes 157 tracked files, no intended untracked files and 246 reachable historical blobs at preparation; ignored local files remain intact. Only main exists, with no additional branches/tags. Completion checks pass; commit and execute the authorized private checkpoint, then record its actual outcome.

## 2. Confirmed business decisions


| Decision | Agreed position |
|---|---|
| Product | Internal records, reports and bills; no booking system |
| Business model | No separate management fee or transport-company brokerage income in this scope |
| Accounts | Staff only; owners/brokers/customers receive outputs, not logins |
| Initial rollout | One business, two offices, five users, twenty vehicles |
| Office workflow | Origin dispatches; destination marks arrival; vice versa for the return |
| Access | Assigned offices for staff; administrator sees everything |
| Office duties | Origin controls trip/fare/dispatch; destination arrival; both permitted money/expense entries |
| Arrival | Marks active customer consignments delivered; financial settlement stays independent |
| Vehicle overlap | Warn and allow confirmed override |
| Returns | Loaded and empty journeys recorded separately and linked |
| Loads | Multiple customers/stops/prices on a trip; consignment total fare and count with optional car IDs |
| Owner model | One recorded owner; joint owners split outside the app |
| Brokerage | Deducted from customer quote or added to owner quote; record actual retention and transfers |
| Payments | Partial and multi-trip payments, explicit allocation, trip-linked advances/credits |
| Expenses | Payer and cost bearer recorded separately; relevant categories editable |
| Monthly earnings | Dispatch date; cash/payment and expense dates stay separate |
| Corrections | Creator may edit own permitted record; admin can correct all; retain history |
| Cancellation | Explicit adjustments/refunds; keep original record and actual expenses |
| Office cash | Trip/party balances only; no office cash/bank bookkeeping |
| Outputs | Recipient-specific privacy plus selectable/reorderable attributes and reusable presets |
| Owner privacy | Exclude brokerage and gross customer fare from owner outputs |
| Bill identity | Company name plus issuing user's name; preserve on issued documents |
| Issued documents | Permanent number/snapshot; corrected documents supersede rather than overwrite |
| Tax | Skip tax in v1 |
| Excel | Import/export support; start with new records, no historical or opening-balance migration |
| Platforms | Native Windows installer first, Android APK after Windows pilot; possible web later |
| Connectivity | Internet required; no offline posting |
| Language | English first, Urdu later; translation-ready architecture |
| Hosting budget | Zero-cost start; approved free Supabase pilot |
| Backup | Daily administrator-PC backup, manual action and off-PC-copy reminder |

## 3. Terminology

- **Trip:** One vehicle journey, including an empty return. Contains zero or more consignments according to loaded/empty state.
- **Consignment:** A customer's load and agreed total charge on a trip; can include several cars/stops.
- **Quoted fare:** Entered pricing base whose meaning is determined by DEDUCTED or ADDED mode.
- **Owner entitlement:** Fare share earned by the owner before owner-borne costs.
- **Brokerage:** Agreed commission earned by a broker; not automatically the app business's income.
- **Receipt:** Actual money received from the identified payer by the identified recipient.
- **Custody / held funds:** Trip money received on behalf of others and not yet allocated/remitted/returned/spent/retained properly.
- **Settlement:** Discharge of an entitlement/reimbursement through actual payment, retention or an explicitly identified offset.
- **Cost bearer:** Party ultimately responsible for an expense, regardless of who initially paid it.
- **Personal advance:** Money someone funded themselves, distinct from spending already-held trip funds.
- **Owner profit:** Owner entitlement minus owner-borne costs; distinct from settlement balance.
- **Scoped statement:** Statement containing only an authorized subset of records; not a complete business balance.
- **Output preset:** Saved field selection/order/formatting; no cached privileged data or permission grant.
- **Issued snapshot:** Immutable document data and layout configuration used for reprinting.

## 4. Essential example to preserve

Customer total 100,000; broker commission 5,000; owner entitlement 95,000.

Owner-borne diesel 10,000 gives owner profit 85,000.

- If owner personally paid diesel, the broker still owes/remits 95,000.
- If broker funded diesel and takes an agreed reimbursement/offset, cash remittance is 85,000 plus the 10,000 cost settlement.
- Broker commission remains 5,000. Reimbursement is not commission. Count diesel once.
- Customer payment to broker does not by itself prove owner settlement.

Canonical postings and additional examples live in rules.md. Never replace this distinction with a shortcut “net fare minus all expenses equals money due.”

## 5. Locked implementation defaults

These defaults complete the technical specification; they are not additional independently reported business facts.

- Flutter/Dart with shared Windows/Android domain code, Riverpod, go_router and Supabase adapters.
- Supabase Auth/PostgreSQL/private Storage, transactional database functions and small admin-only Edge Functions; no separate always-running API server.
- Username/password internally mapped to non-deliverable Auth identifiers; no required staff personal email.
- One active business with business_id retained in records for future expansion; no SaaS onboarding.
- Exact money, decimal-string interfaces and integer paisa in Dart; round-half-up percentage commission on the selected quote basis.
- Fixed commission and percentage support; percentage input to two decimal places, range 0–100; fixed amount for exceptional pricing.
- Balanced immutable settlement subledger; no office bank/cash books.
- Versioned operational updates; idempotent financial commands; reversal/replacement for confirmed money.
- Personal-funding versus held-trip-funding selection for expense posting.
- Customer invoice groups that customer's consignments on one trip.
- Owner change and route-price change preserve historical snapshots.
- Server-owned field catalogue and recipient payload redaction; customize presentation without changing calculations.
- Personal presets for staff and admin-shared presets; mandatory identity/total fields retained.
- A4 PDF with adaptive orientation and page handling; selected-field parity in Excel; English v1.
- Template imports produce operational/expense drafts for normal confirmation; no arbitrary journal upload.
- Private evidence with 5 MB pilot per-file limit; supported image/PDF evidence.
- Daily encrypted database backup plus incremental file backup, 30 successful daily archives locally, separate recovery key and actual restore rehearsal.
- Backup scheduling defaults to 18:00 in the admin PC's displayed local time zone, configurable at setup, with missed-run catch-up. No live backup schedule has been installed.
- Server-issued document numbering defaults to INV-YYYY-NNNNNN and RCP-YYYY-NNNNNN; the year follows Pakistan-local issuance date.
- Use Asia/Karachi for business dates; UTC for audit timestamps.
- 50-row default pagination. Test 1,000 trips/month for one year with five concurrent users; this is not a business-volume forecast.
- Suggested first office labels Karachi and Islamabad remain editable; actual company/staff/fleet data is supplied at setup.

## 6. Scope and operational limits

No tax, booking, public signup, external-party access, opening balances, historical migration, joint-owner splitting, offline transactions, paid upgrades, GPS or automatic messaging. Urdu and web remain deferred.

The free Supabase plan has quotas and inactivity behavior. The planning reference includes 500 MB database, 1 GB files and no included automatic backups; verify provider terms at setup. Zero subscription cost does not establish guaranteed production availability. Do not claim speed measurements, continuous backup scheduling while the PC is off, or permanent free capacity.

Backups must be recoverable after losing the original PC. Keeping an encryption key only under that PC's DPAPI is insufficient. Receipt objects are not recovered by restoring database rows alone. Privileged backup tooling remains separate from ordinary staff packages.

## 7. Decision history

| Date | Decision/change | Reason |
|---|---|---|
| 2026-10-11 | Final interview scope confirmed | Make the business and money flows explicit before generation |
| 2026-10-11 | Company and issuing user on bills; tax excluded | Direct user clarification |
| 2026-10-11 | Two offices, five users, twenty vehicles | Actual starting-size clarification replaces earlier provisional estimates |
| 2026-10-11 | Native Windows and Android, internet required | Direct platform preference; Windows pilot first |
| 2026-10-11 | Free Supabase pilot and daily PC backups | Zero-cost constraint and selected hosting/recovery approach |
| 2026-10-11 | Attribute selection/order/presets in output workflow | User requested easy output customization; preserve recipient restrictions |
| 2026-10-11 | Document generation prioritized | User explicitly asked to start with the six documents before application work |
| 2026-10-11 | Add private GitHub source-backup checkpoint after T10 | User requested the push command after T10; defer this checkpoint until verified completion |
| 2026-10-11 | Continue in VS Code with Codex using the existing D:\portfolio\transport_project folder; private GitHub versioning requested | User selected the development workflow; local Git prepared, remote publication pending authentication |
| 2026-10-11 | Continue T01 with existing Flutter SDK and local Git; do not publish to GitHub | Latest instruction supersedes the earlier remote-publication request |

Dates above record this specification baseline, not an inferred timestamp for every earlier interview answer.

## 8. Documentation verification

Verified in this phase: all six expected UTF-8 Markdown documents exist; required scope/platform/count/customization details are included; FR/BR/AT references are internally valid; selected arithmetic examples reconcile; implementation tasks remain marked pending.

Not verified in this phase: Flutter application analysis/tests, SQL migrations/RLS execution, Supabase deployment, native builds, PDF/XLSX generation, performance, scheduled backups or restoration. These require implementation evidence and must remain NOT RUN in tasks.md.

## 9. Resume instructions

1. Read the six documents, starting with this file and PRD.md/rules.md.
2. Preserve local Git history. The user authorized a private GitHub source backup at origin https://github.com/naeemhck/carrier-records.git. Verify private visibility before a backup push; never force-push or publish private operational files. Public publication remains unauthorized.
3. Resume T10 corrections, cancellation and recovery claims, following tasks.md dependencies and the T10 private source-backup checkpoint. T00-T09 completion checks passed; see docs/expenses-evidence.md plus the earlier task evidence. First real administrator/company/office setup still needs actual user inputs; use docs/accounts-setup.md and docs/masters-setup.md.
4. Create required source/tooling in the project and keep production secrets out of it.
5. Do not reinvent the money model, broaden recipient visibility, silently add taxes or enable paid hosting.
6. Record real test/build/recovery evidence and update tasks.md and this current-state section when work progresses.

No further business-design decisions are intentionally left open for the agreed v1. Real company identity, staff assignments, fleet/contact data, Supabase project credentials and release signing material are operational setup inputs supplied securely during implementation.
