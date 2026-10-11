# Project memory: Carrier Records

Version: 1.1 | Last specification update: 2026-10-11

Purpose: Preserve agreed decisions across development sessions. This file is a decision/current-state record, not a second source of financial calculations. Read PRD.md and rules.md before implementing behavior.

## 1. Current state

- The grilling interview and final specification confirmation are complete.
- The user requested customizable output attributes after the initial template decision; the revised plan includes them in both PDF and Excel.
- The user asked to implement the revised plan, then directed work to begin with document generation.
- Six planning Markdown files have been read; T01 now has a Flutter source scaffold and local Supabase configuration. No hosted backend, production staff accounts, installer or APK is delivered.
- The working project folder is D:\portfolio\transport_project. The user will continue in VS Code with the Codex extension.
- Local Git on main is the versioning workflow. The latest user instruction explicitly forbids GitHub publication; no push or repository publication is authorized.
- T00, T01 and T02 are DONE; T03?T20 remain TODO. T02 quote/precision portions verified; full business workflows remain NOT RUN.
- Existing VS Code SDK verified: Flutter 3.47.4 stable (9584c6713b), Dart 3.13.3. Its bin directory was added to user PATH; restart VS Code to inherit it. `tools/flutter.ps1` also resolves the configured SDK without committing the machine path.
- `app/` contains generated Windows/Android runners, Riverpod/router composition and a setup-only screen. Analyzer found no issues and one route harness test passed. Core dependency versions/lockfile are committed. No backend session or business feature is simulated.
- Prerequisites completed: Visual Studio Build Tools/standard x86/x64 ATL, Android Studio JBR, API 36 and plugin-required API 35, build-tools 36, platform-tools, NDK 28.2.13676358, CMake 3.22.1; SDK licences accepted. User enabled Developer Mode (registry value 1 verified). Doctor exits 0 with no issues.
- Windows debug build exits 0 after 126.2s; Android debug build exits 0 after 345.3s. Artifacts are ignored under app/build. Kotlin incremental compilation disabled to address C: Pub cache versus D: project path failure. Gradle official archive size/SHA-256 verified; retries sequential with certificate verification intact. Detailed failed attempts/remedies and hashes in docs/tooling-evidence.md. No installer, release signing, device launch or production distribution claimed.
- Supabase CLI 2.120.0 checksum/version/init verified. Local stack passes Auth/REST/Storage HTTP 200 and PostgreSQL readiness. Optional local analytics disabled to avoid Vector's Docker TCP dependency; no insecure TCP listener enabled. No hosted project linked. Signup and automatic new-table API exposure disabled. Local/test examples contain no keys; backend session work remains T03.
- T02 completed: four local migrations, 27 application tables, business-scoped/party-role foreign keys, versions, owner/quote snapshots, append-only financial/document/audit history and query indexes. Default-deny RLS and revoked client grants remain until T03 scoped authorization. No operational or financial RPC command is yet implemented.
- Exact Dart Money/Percentage/BusinessDate/Quote and UUID/context/command types implemented; decimal-string server quote function rejects extra input precision and recomputes canonical amounts. Integer paisa/BigInt intermediate rounding avoids floating point. Six Dart/widget tests and 43 SQL assertions pass; analyzer and database lint have no issues; formatting check passes. SQL fixtures roll back; local business/Auth counts are zero and migration count four. Post-reset backend health passes. See docs/domain-evidence.md for actual failed attempts/fixes and the limited AT coverage.
- T01/T02 changes use local Git only; do not publish to GitHub. Next task is T03 accounts, scoped permissions and secure sessions.

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
2. Use local Git; do not publish to GitHub under the latest instruction.
3. Resume T03 accounts/permissions/sessions, then follow the task dependencies. T01 native/tooling checks and T02 migration/domain checks passed; see docs/tooling-evidence.md and docs/domain-evidence.md. No login/business workflow is implemented yet.
4. Create required source/tooling in the project and keep production secrets out of it.
5. Do not reinvent the money model, broaden recipient visibility, silently add taxes or enable paid hosting.
6. Record real test/build/recovery evidence and update tasks.md and this current-state section when work progresses.

No further business-design decisions are intentionally left open for the agreed v1. Real company identity, staff assignments, fleet/contact data, Supabase project credentials and release signing material are operational setup inputs supplied securely during implementation.
