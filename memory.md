# Project memory: Carrier Records

Version: 1.1 | Last specification update: 2026-10-11

Purpose: Preserve agreed decisions across development sessions. This file is a decision/current-state record, not a second source of financial calculations. Read PRD.md and rules.md before implementing behavior.

## 1. Current state

- Six planning documents and AGENTS.md have been read. The business scope and financial invariants remain unchanged.
- Workspace: D:\portfolio\transport_project. Local Git history is preserved. On 2026-10-11 the user superseded the earlier no-GitHub instruction for a private source backup: origin is https://github.com/naeemhck/carrier-records.git, created under the verified naeemhck account with private visibility. Public publication and inclusion of credentials/operational data remain unauthorized. See docs/source-backup.md for the pre-push review; remote commit equality is verified after pushing.
- T00-T04 are DONE; T05-T20 remain TODO. Next task is T05 trips/consignments/stops/car records. T04 company/master forms, administrator commands, exact route defaults, multiple party roles and used-record archiving are implemented. AT-10/11 historical snapshots and relevant direct authorization attacks pass. Later financial/lifecycle/output/release/restore acceptance is NOT RUN.
- Existing VS Code SDK verified: Flutter 3.47.4 stable (9584c6713b), Dart 3.13.3. tools/flutter.ps1 resolves the configured SDK. T01 developer mode, standard v143 ATL, Visual Studio/Android/JDK/SDK prerequisites and licenses passed; exact installation failures/remedies remain in docs/tooling-evidence.md. No installer duplicates were started during T03.
- App keeps Riverpod composition/go_router navigation with an Auth adapter, staff username sign-in, mandatory password change, administrator account creation/edit/status/offices/reset and logout. Protected FlutterSecureStorage replaces session SharedPreferences. Explicit persistence errors fail sign-in; pending writes/deletions serialize; stale refreshes cannot restore a signed-out profile. Windows native protected storage and real local username sign-in/logout UI tests passed. Android backup is disabled; Android protected-store device execution remains T20 verification.
- Public config: APP_ENV, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, APP_BUSINESS_ID. No privileged key belongs in client configuration. Actual first administrator/company/office identities have not been created; supply real inputs using python tools/manage_accounts.py bootstrap (hidden password prompt, local backend only), then use the administrator Company and master records workspace. See docs/accounts-setup.md and docs/masters-setup.md.
- Supabase CLI 2.120.0 / local Docker stack only, no hosted link/deployment. Auth/REST/Storage health HTTP 200 and PostgreSQL ready after final verification. Global signup, anonymous sign-in and manual linking remain disabled; the password/email provider is enabled because disabling it also disabled managed logins. The custom token hook is enabled and rejects absent/disabled/unassigned/pending accounts.
- Six migrations now implement the 27 public T02 tables, T03 account/security operations and T04 versioned master commands/private retry records. The shared command owner is NOLOGIN/NOBYPASSRLS with explicit master/account privileges and no direct financial writes; temporary schema CREATE and migration-owner membership are revoked. Three fixed private Auth lookup/session helpers use the trusted migration owner and are unavailable to clients. Server checks active profile, current credential revision, live Auth session, office assignment, password-change gate and operation eligibility. Mutable Auth metadata grants nothing.
- Administrator-only Edge account endpoint verifies bearer tokens through Auth and live SQL authorization. Auth service calls stay in the runtime. Account/office/status/password changes revoke target sessions. All ordinary direct table writes (including financial events, journals, allocations and idempotency results) remain denied for administrator and staff JWTs. Global event metadata stays closed; assigned-office balance summaries use source RLS and exact decimal strings. Full posting/report commands remain T06/T07/T11.
- Interrupted password updates lock the target and revoke sessions before calling Auth. Successful finalization forces reset-password users to change their temporary password. Trusted local recovery was tested; failures never report partial work as success. Passwords are absent from audit/operation records and are never written to setup files.
- T02 exact Money/Percentage/BusinessDate/Quote, command types and immutable history/snapshot constraints remain intact. T04 clean reset applies all six migrations; 83 SQL assertions and database lint pass. Analyzer has no issues; fifteen Dart/widget tests pass. The T04 native Windows administrator create/edit/archive workflow passes, in addition to the previously executed T03 protected-storage and staff sign-in/logout tests. Final local API suite passes 302 assertions, preserving T03 direct-write/JWT/signup/private-receipt/scoped-balance/recovery attacks and adding T04 master authorization, history, exact fares, archiving, create/update retries, null/stale/concurrent versions and office archive access removal.
- T03 AT-12/13/14 authorization checks PASS. Origin fare/dispatch, destination arrival, both-office payment/expense eligibility and unrelated-office denial are verified at the backend authorization contract; actual state/posting commands remain later tasks. Staff global balance access is denied; labelled scoped and administrator-complete fixture totals are exact. Storage privacy tested using synthetic objects; upload/content workflows remain T09.
- T04 ordinary Windows debug build succeeds in 150.5s and Android debug build in 151.1s. Package/source audit scans 667 entries/files and finds no actual local service, secret, JWT-signing or S3 credentials. No release signing/installer/Android device/production distribution is claimed. Artifacts/configuration/logs remain ignored. T04 artifact hashes, failed attempts and corrections are in docs/masters-evidence.md; earlier T03 evidence remains in docs/accounts-evidence.md.
- Final Auth/REST/Storage health returns HTTP 200; PostgreSQL accepts connections. Auth users, businesses, private password operations, private master retries and storage objects all return to zero; migration count six. Native test configuration is removed. No credentials or business data are committed. Setup steps, actual failures/corrections and T04 evidence are in docs/masters-setup.md and docs/masters-evidence.md.
- T04 permissions: administrator-only master mutation and company maintenance; staff receive active entry choices without contact/Auth/creation/version metadata or archived rows. Destination office choices grant no access. Same-business active origin permission is required for server trip defaults. Office archive immediately removes affected office access; administrators retain history. Party roles are archived rather than deleting historical links. New defaults reject archived owners/drivers/roles/vehicles/routes/offices. AT-10/11 changes to current owner, owner contact/name and route defaults leave prior trips, agreed quotes and issued snapshots unchanged. Used category/party archive preserves saved expenses; master edits never create financial events.
- `require_document_setup()` verifies explicit company setup and current issuer display values. T13 must call it inside the issuance transaction. T05 must capture server `get_trip_defaults()` values and require explicit review of suggested fares; a suggestion must never replace a saved agreement implicitly. T04 test trip/quote/document insertion uses trusted synthetic SQL fixtures, not completed T05/T13 commands. No elevated Windows action is needed for T04.

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
| 2026-10-11 | Continue in VS Code with Codex using the existing D:\portfolio\transport_project folder; private GitHub versioning requested | User selected the development workflow; local Git prepared, remote publication pending authentication |
| 2026-10-11 | Continue T01 with existing Flutter SDK and local Git; do not publish to GitHub | Latest instruction supersedes the earlier remote-publication request |

Dates above record this specification baseline, not an inferred timestamp for every earlier interview answer.

## 8. Documentation verification

Verified in this phase: all six expected UTF-8 Markdown documents exist; required scope/platform/count/customization details are included; FR/BR/AT references are internally valid; selected arithmetic examples reconcile; implementation tasks remain marked pending.

Not verified in this phase: Flutter application analysis/tests, SQL migrations/RLS execution, Supabase deployment, native builds, PDF/XLSX generation, performance, scheduled backups or restoration. These require implementation evidence and must remain NOT RUN in tasks.md.

## 9. Resume instructions

1. Read the six documents, starting with this file and PRD.md/rules.md.
2. Preserve local Git history. The user authorized a private GitHub source backup at origin https://github.com/naeemhck/carrier-records.git. Verify private visibility before a backup push; never force-push or publish private operational files. Public publication remains unauthorized.
3. Resume T05 trips/consignments/stops/car records, then follow task dependencies. T01-T04 completion checks passed; see docs/tooling-evidence.md, docs/domain-evidence.md, docs/accounts-evidence.md and docs/masters-evidence.md. First real administrator/company/office setup still needs actual user inputs; use docs/accounts-setup.md and docs/masters-setup.md.
4. Create required source/tooling in the project and keep production secrets out of it.
5. Do not reinvent the money model, broaden recipient visibility, silently add taxes or enable paid hosting.
6. Record real test/build/recovery evidence and update tasks.md and this current-state section when work progresses.

No further business-design decisions are intentionally left open for the agreed v1. Real company identity, staff assignments, fleet/contact data, Supabase project credentials and release signing material are operational setup inputs supplied securely during implementation.
