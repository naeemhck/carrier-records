# Product requirements: Carrier Records

Version: 1.1 | Specification date: 2026-10-11

Status: Business scope confirmed. Planning documents generated; application implementation pending.

2026-10-12 user scope update: public Flutter web hosting on free Cloudflare Pages is explicitly authorized and deployed at https://carrier-records.pages.dev. This supersedes the original deferred-web item for the hosting request. Existing backend authorization and exact accounting rules apply unchanged. Web field/export checks and the Windows/Android release gates are separate; see docs/web-deployment-evidence.md. The user explicitly waived the database backup prerequisite for this deployment.

## 1. Purpose

Replace registers and fragmented spreadsheets with an internal system for recording car-carrier journeys, fares, brokerage, payments, expenses, and settlements. Produce accurate vehicle and owner reports and customizable recipient-specific bills without requiring customers, owners, or brokers to use the app.

The app records transport arranged outside it. It is not a booking system. A typical real-world flow is customer → broker → carrier. The customer may pay the broker, owner, driver, or transport business; who received money and who ultimately earned it must be distinguishable.

## 2. Initial rollout and success

| Item | Requirement |
|---|---|
| Business | One transport business; no public business onboarding |
| Offices | Two initially, including Karachi and Islamabad; configurable names and additional offices |
| Users | Five individual internal staff accounts initially |
| Fleet | Twenty vehicles initially |
| Clients | Windows installer first; Android APK second |
| Connectivity | Internet required to confirm records |
| Language | English v1; translation-ready code; Urdu later |
| Country / currency | Pakistan / PKR |
| Business date zone | Asia/Karachi; audit timestamps stored in UTC |
| Hosting | Free Supabase pilot; no automatic paid upgrade |
| Starting records | New operational records only; no historical import or opening balances |
| Performance benchmark | 1,000 trips/month, a test load rather than a forecast |

Success means staff can reconcile a real trip from agreed fares through receipts, expenses, and owner/broker settlement; both offices can work on the same journey; printed and Excel outputs show the intended recipient's information; restoring a backup recovers usable records and receipts.

## 3. Users and boundaries

### Administrator

Manages company settings, users, office assignments, master records, shared output presets, and backups. Can access all business records, correct records with history, and generate complete statements.

### Office staff

Have individual accounts and one or more assigned offices. See trips involving an assigned origin or destination office. Origin staff manage trip details, fares, and dispatch. Destination staff mark arrival. Both may enter permitted payments and expenses. Entry creators may correct their own records only while they retain the required office and operation permission. Administrators handle other corrections.

Standalone vehicle expenses belong to an office and are visible to that office's staff and administrators. Staff-generated reports are explicitly scoped; complete cross-office balances are administrator outputs.

### External parties

Owners, customers, brokers, and drivers are contact/financial records, not app accounts. Owners receive printed or Excel statements. Record one financial owner per vehicle; joint owners divide their proceeds outside the app.

## 4. Scope exclusions

No customer booking, public signup, external-party login, tax calculation or tax submission, separate office cash/bank books, historical migration, opening balance migration, joint-owner percentages, offline financial posting, paid subscriptions, GPS tracking, automatic messaging, or app-store distribution in v1. Web and Urdu are deferred. Operational billing does not introduce a claim of tax compliance.

## 5. Functional requirements

| ID | Capability | Acceptance outcome |
|---|---|---|
| FR-01 | Company, offices, accounts | Administrator maintains company identity, user display names, account status, roles, and office assignments. |
| FR-02 | Master records | Maintain vehicles, owners, customers, brokers, drivers, routes, and expense categories; used records are archived rather than deleted. |
| FR-03 | Route presets | Save endpoints and suggested total consignment fare; allow agreed-fare override; historical prices remain unchanged. |
| FR-04 | Trip draft | Select carrier, driver, offices, route and dates; add stops and consignments before dispatch. |
| FR-05 | Consignments | Multiple customers per trip; each consignment has a total fare, car count, optional individual car identifiers, and pickup/drop details. |
| FR-06 | Lifecycle | Draft → Dispatched → Arrived, with cancellation. Destination arrival marks every active consignment delivered. Payment status is independent. |
| FR-07 | Return and overlap | Link loaded or empty return journeys; warn on overlapping dispatched trips and audit an explicit override. |
| FR-08 | Brokerage | Support deducted/added commission, fixed PKR or percentage, and stored calculation snapshots. |
| FR-09 | Receipts | Record actual payer, recipient, date, amount and reference; customer payment and owner receipt remain distinct. |
| FR-10 | Allocations and advances | Explicit bulk allocations, trip-linked advances, excess credits, application of credits and refunds; prevent duplicate consumption. |
| FR-11 | Transfers and retention | Record actual remittances, owner settlement, commission retained/paid, reimbursements and recoveries. |
| FR-12 | Expenses | Vehicle, optional trip, category, date, amount, payer, cost bearer, payment source, notes and optional receipt. |
| FR-13 | Corrections | Creator/admin corrections with reason and retained history; confirmed money uses reversal/replacement. |
| FR-14 | Cancellation | Retain incurred costs and money movements; enter agreed fare adjustments, cancellation charges, refund credits and actual refunds explicitly. |
| FR-15 | Reports | Monthly vehicle/owner earnings, brokerage, expenses, receipts, intermediary-held money, credits and outstanding obligations; lifetime trip profitability. |
| FR-16 | Recipient templates | Internal, customer, owner and broker outputs expose different permitted information. |
| FR-17 | Attribute selection | Select and order permitted attributes, select all permitted, reset defaults and preview PDF/Excel. |
| FR-18 | Output presets | Staff save personal presets; admins publish shared presets. Presets never grant additional data permissions. |
| FR-19 | Issued documents | Company and issuer name, unique number, immutable values and layout snapshot; corrections issue linked superseding documents. |
| FR-20 | Excel import/export | Template-based import with preview, validation and duplicate protection; export selected authorized fields. |
| FR-21 | Recovery | Daily administrator-PC backup, incremental receipt copy, manual action, encrypted archives, failure indication and tested restoration. |
| FR-22 | Usability and speed | Desktop-first compact entry and searchable tables; Android touch layouts; asynchronous work and clear connection errors. |

## 6. Core journeys

### Record and dispatch a loaded trip

1. Origin staff choose a vehicle, driver, destination office and route.
2. Add customer consignments, stops, car counts and optional identifiers.
3. Select quoted fare basis and brokerage mode; review customer total, owner entitlement and commission.
4. Save a draft. Record a trip-linked advance if received.
5. Dispatch after reviewing amounts, dates and overlap warnings. Confirm any advance application.
6. Destination staff mark arrival; active consignments become delivered.
7. Continue settlement independently until all relevant claims and credits are reconciled.

### Record money received by a broker

Record the customer receipt and allocate it to consignments. That changes customer debt and identifies funds held by the broker. Later record actual commission retention, expense reimbursements and owner transfers. A receipt alone must not mark the owner paid.

### Record an expense

Choose vehicle/trip, category, date, payer and cost bearer. Distinguish personal funds advanced from funds already held for the trip. Confirm any settlement offset separately or as an explicitly reviewed component of the expense posting. The same expense cannot be reimbursed twice.

### Generate an output

Choose document/report type, recipient and filters → choose permitted attributes → reorder → optionally load/save a preset → preview → print, PDF or Excel. Issuing an invoice/receipt permanently records its document configuration and amounts. Reprinting uses that snapshot.

## 7. Financial reporting definitions

| Measure | Meaning |
|---|---|
| Customer charge | Amount owed for the consignment, including agreed brokerage arrangement |
| Owner entitlement | Fare share earned by the recorded owner, before owner-borne operating costs |
| Brokerage earned | Agreed commission recognized on dispatch |
| Customer outstanding | Recognized customer charges less applied customer receipts/credits and adjustments |
| Owner profit | Owner entitlement less owner-borne costs for the selected reporting basis |
| Vehicle operating profit | Customer fares less brokerage and all vehicle operating costs |
| Owner settlement balance | Amount payable/recoverable after actual settlements, agreed expense offsets and corrections |
| Intermediary-held funds | Customer/trip funds received but not remitted, returned, expended from those funds, or legitimately retained |

Monthly income uses dispatch dates, receipts use payment dates, and expenses use expense dates. A month's vehicle report includes that month's vehicle expenses even when they belong to an earlier trip. Lifetime trip profit includes all linked expenses regardless of month. Report headings declare the basis and scope.

## 8. Required accounting examples

### A: Deducted brokerage

Customer charge 100,000; brokerage 5,000; owner entitlement 95,000. Customer pays broker 100,000. Customer owes zero, but owner settlement is still 95,000 until transfers/offsets are recorded. Broker retains 5,000 and remits 95,000: owner balance, commission balance and held funds become zero.

### B: Added brokerage

Owner quote 100,000; brokerage 5,000; customer charge 105,000. Do not deduct commission from the owner quote a second time.

### C: Partial payment

For example A, customer pays broker 60,000. Staff record actual retention of 5,000 and owner remittance of 55,000. Customer outstanding is 40,000; owner settlement remaining is 40,000; broker holds zero. Other real splits are allowed and produce their own balances.

### D: Expense funded by owner

Owner entitlement 95,000; owner pays owner-borne diesel 10,000 personally. Profit is 85,000. Broker still owes 95,000; the owner's personal payment is not an additional deduction from the remittance.

### E: Expense funded by broker

Same entitlement/cost, but broker pays diesel. An agreed reimbursement/offset of 10,000 plus cash remittance 85,000 settles owner entitlement 95,000. Broker's commission remains 5,000. Expense is counted once. Track whether diesel used a personal advance or held trip funds.

### F: Cross-month journey

Dispatch January 30; arrival February 2; payment March 5. Fare and brokerage appear in January earnings; arrival in February operations; receipt in March receipts. An expense dated February belongs in February expenses and in lifetime trip profit.

## 9. Output privacy and customization

Internal outputs can select all information permitted by the staff member's office scope. Customers see only their own charges/receipts/consignments. Owners see owner fare share, applicable expenses and settlements, excluding gross customer fares and brokerage. Brokers see commission and relevant settlements, excluding owner profitability.

The backend owns the field catalogue and enforces eligibility. Filtering rows and selecting columns are different operations. Column visibility never changes calculations. Required invoice/receipt identity and applicable total fields cannot be removed. Report period and scope always remain visible. Files must not include forbidden fields in hidden sheets, metadata or embedded source payloads.

## 10. Nonfunctional acceptance

- No financial save succeeds without a confirmed server response; preserve unsent input in memory on failure.
- Money calculations use exact arithmetic, not binary floating point.
- Concurrent edits produce a conflict, not a silent overwrite. Duplicate retries create one posting.
- Ordinary paginated screens target p95 ≤ 2 seconds and monthly summaries p95 ≤ 5 seconds on an active backend and documented stable network, with five concurrent users and one year at the benchmark load.
- Financial history and issued snapshots cannot be hard-deleted through the app.
- Backup and restore tests must recover records, receipt objects, identity mappings and office permissions.
- Free-tier quota failures produce actionable errors, never an automatic paid upgrade.

## 11. Release acceptance

Windows pilot requires financial, permission, export and restore checks to pass with measured results. Android requires the same backend behavior, secure sessions, usable touch forms and tested print/share exports. Native builds and deployment remain pending; this document records requirements, not evidence that they have been implemented.

Companion documents: architecture.md, rules.md, design.md, tasks.md and memory.md.
