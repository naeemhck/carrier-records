# Business, financial and development rules: Carrier Records

Version: 1.1 | Specification date: 2026-10-11

Status: Authoritative implementation rules for the agreed scope. Implementation and test execution pending.

## 1. Interpretation and change control

Use PRD.md for required product behavior, this file for invariants, architecture.md for implementation boundaries, and design.md for presentation. A conflict requires a deliberate specification correction and an entry in memory.md; do not silently choose a behavior. tasks.md tracks actual completion rather than intent.

Requirements confirmed by the user remain the baseline. Detailed choices identified as implementation defaults are engineering decisions that make the specification executable; do not describe them as independently confirmed business facts.

## 2. Business and operational invariants

| Rule | Requirement |
|---|---|
| BR-01 | One business, configurable offices, PKR, internal accounts only. Company identity must be configured before issuing a document. |
| BR-02 | One recorded financial owner per vehicle. Joint-owner sharing stays outside the app. Trip owner snapshots are immutable except through an authorized audited correction. |
| BR-03 | A consignment belongs to one trip and one customer, with an optional broker. One party may have several roles. |
| BR-04 | Consignment price is a total amount, not automatically a per-car rate. Car count is a positive integer for a load; individual car identifiers are optional. |
| BR-05 | Pickup/drop details support several stops and customers on one journey. Stop order is explicit; optional car identifiers may be associated with stops. |
| BR-06 | Route default changes never overwrite saved quotes. A new route choice offers a price suggestion requiring review, not an invisible fare replacement. |
| BR-07 | Drafts do not earn fare or commission. Dispatch recognizes agreed earnings. Arrival marks all active consignments delivered without changing money balances. |
| BR-08 | Overlap with another dispatched trip requires a visible warning and explicit recorded confirmation; it does not prohibit dispatch. |
| BR-09 | Returns are separate trips linked to the outbound trip. Empty returns have no consignments/fare but can incur costs. |
| BR-10 | Physical trip state and financial state are independent. An arrived trip can be unpaid; an advance-paid draft can be undispatched. |
| BR-11 | Cancelled consignments are not later marked delivered by arrival. Cancellation never automatically deletes expenses, refunds money or erases earnings. |
| BR-12 | Used vehicles/parties/routes/categories are archived, not deleted. Existing records remain readable using stored references/snapshots. |

Actual dispatch/arrival dates are business dates; arrival cannot precede dispatch. Drafts may contain planned dates, but a planned date is not an actual dispatch. Allow authorized backdated recording of actual operations with an audit timestamp; report the effective business date correctly.

## 3. Pricing and exact arithmetic

### BR-13: Quote calculation

Let Q be the entered quote and C the commission.

| Mode | Quote basis | Customer charge | Owner entitlement |
|---|---|---|---|
| DEDUCTED | Customer total | Q | Q − C |
| ADDED | Owner fare | Q + C | Q |

Fixed commission is a nonnegative PKR amount. Percentage commission is round_half_up(Q × rate / 100, 2). The implementation default percentage range is 0–100 inclusive; exceptional pricing can use a fixed amount. DEDUCTED rejects C > Q. A consignment without a broker has commission zero. Empty-return fare is zero.

Store Q, mode, fixed/rate method, rate if applicable, C, customer charge and owner entitlement. Store calculated values as a snapshot, not a formula that references a changing route preset. Recompute on the server and return accepted results.

Invariant: customer charge = owner entitlement + commission. Fare adjustments use the same invariant.

### BR-14: Money types

PKR amounts are exact to two decimal places. Reject extra decimal places at input rather than silently changing an entered payment. Percentage calculation is the explicit rounding exception. Database money uses NUMERIC(18,2); interfaces use canonical decimal strings; Dart uses integer paisa. Never use binary floating point for equality, allocations or balances.

Ordinary receipt/transfer amounts are positive; signed changes exist through explicit adjustments/reversals, not disguised negative payments. A reversal must mirror the original posting exactly.

## 4. Recognition and reporting

| Rule | Requirement |
|---|---|
| BR-15 | Recognize fare and commission on actual dispatch date. A draft quote is potential fare, not earnings. |
| BR-16 | Recognize expenses on their expense dates and receipts/transfers on their actual payment dates. Audit recorded_at remains separate. |
| BR-17 | Monthly reports use each measure's date basis. Do not exclude a February expense merely because its trip departed in January. |
| BR-18 | Lifetime trip profit includes every current effective expense linked to that trip, regardless of month. |
| BR-19 | Gross customer fare, brokerage, owner entitlement, vehicle operating profit, owner profit and settlement balances are distinct measures with distinct labels. |
| BR-20 | Vehicle operating profit = customer fare − brokerage − all recorded vehicle costs for the selected basis. Owner profit = owner entitlement − owner-borne costs. |
| BR-21 | A correction affects the effective date of the corrected value. A cancellation adjustment uses its explicitly recorded effective date. Previously issued snapshots never change. |

Trip-specific costs belong to their trip. Standalone oil changes/maintenance belong to the vehicle and expense date; do not arbitrarily spread them across trips. Monthly vehicle totals include them, and lifetime trip totals do not unless explicitly linked. There is no automatic maintenance-to-trip allocation in v1.

Net owner settlement may differ from profit and from gross cash the owner received while acting as a custodian. Owner export labels use owner-settled amounts, not unqualified customer collections that also contain another party's share.

## 5. Receipt, custody, settlement and credit rules

| Rule | Requirement |
|---|---|
| BR-22 | Every external money movement records actual payer, actual recipient, business date, amount and related allocations. Actor is derived from the session. |
| BR-23 | A customer receipt reduces only explicitly allocated customer claims/advances and increases money held by its recipient. It does not prove that the owner is paid. |
| BR-24 | Customer funds received by an owner/driver/company can still include brokerage or other unsettled shares. Confirm retained owner settlement explicitly. |
| BR-25 | Transfers between custodians move held funds without generating earnings or settling owner entitlement. A transfer paying an owner entitlement is a settlement, not another customer receipt. |
| BR-26 | Commission retention/payment uses actual amounts and may not exceed the broker's unsettled earned claim. Reimbursement must not be mislabeled commission. |
| BR-27 | Partial receipts have no mandatory first-commission or proportional split. Staff record actual retention and remittance. |
| BR-28 | Cash event allocations and any advance-credit remainder exactly equal its amount. Offsets without cash are separately identified. |
| BR-29 | Advance credits belong to a customer and draft trip/consignment. Applying them is an explicit reviewed operation; no earning is created by receiving an advance. |
| BR-30 | Excess receipts become identified credits, not unexplained negative debt. Applying/refunding a credit consumes it once, with allocation and source records. |
| BR-31 | Personal non-expense trip funding creates a funding reimbursement claim. Paying an owner before collecting from a customer does not mark the customer paid or create a second fare. |
| BR-32 | A custodian cannot remit/retain more held funds than available. Money personally advanced must be declared as such, rather than making custody invisibly negative. |

Bulk payments may cover several consignments/trips for the identified parties. Staff must be able to access every allocation; otherwise an administrator records it. No credit or commission is implicitly moved between unrelated trips.

## 6. Expense and reimbursement rules

### BR-33: Required distinctions

Record payer, cost bearer and funding source:

- PERSONAL_FUNDS: payer advanced their own money.
- HELD_TRIP_FUNDS: payer used identified trip funds already in their custody.
- SELF_FUNDED_COST: payer equals cost bearer and paid personally; there is no reimbursement obligation.

The form can infer SELF_FUNDED_COST from payer/bearer selection, but staff review the result. Personal funding is the safe default when no held-funds source is selected. Held-funds spending requires enough custody and an explicit source allocation.

### BR-34: Profit versus due

Every real expense contributes to vehicle cost once. Owner profit includes only owner-borne expenses. An owner-borne expense paid personally by that owner does not reduce OWNER_PAYABLE: the owner has already borne it outside the held trip funds.

If another party personally pays an agreed owner-borne expense, reduce the owner's net entitlement and create a reimbursement claim for that payer. If it is paid from held trip funds, reduce the owner entitlement and that custody directly; do not create a second reimbursement claim.

If the cost bearer is another party, use a separate cost-recovery claim against that party; do not reduce owner profit. Actual reimbursements/offsets settle claims and are never a second expense or new fare.

### BR-35: Allocations

A trip-wide expense need not be allocated to customers. All customer charges remain their agreed amounts unless an explicit fare adjustment changes them. Expense attachment does not permit a hidden charge increase.

Reimbursements reference expense IDs and can consume each reimbursement claim at most once. Refunds/voids of an expense require their own recorded correction and dependent-settlement handling. Preserve receipt evidence and reversal links.

## 7. Canonical posting examples

Notation: Dr = debit; Cr = credit. These are settlement-subledger accounts, not office bank balances. Profit is calculated from effective fare/expense records, not by treating all receipts as revenue.

### 7.1 Fare and broker receipt

| Event | Debit | Credit |
|---|---|---|
| Dispatch: customer 100,000 / owner 95,000 / broker 5,000 | CUSTOMER_RECEIVABLE 100,000 | OWNER_PAYABLE 95,000; BROKER_COMMISSION_PAYABLE 5,000 |
| Customer pays broker 100,000 | CUSTODY_RECEIVABLE(broker) 100,000 | CUSTOMER_RECEIVABLE 100,000 |
| Broker retains 5,000 | BROKER_COMMISSION_PAYABLE 5,000 | CUSTODY_RECEIVABLE(broker) 5,000 |
| Broker remits owner 95,000 | OWNER_PAYABLE 95,000 | CUSTODY_RECEIVABLE(broker) 95,000 |

All four balances finish at zero. Owner earnings are 95,000, not 100,000; brokerage is not transport-company revenue.

### 7.2 Owner personally funds diesel

Record owner-borne diesel 10,000, paid personally by owner. No owner settlement liability change. Owner profit = 95,000 − 10,000 = 85,000. The broker still settles owner entitlement 95,000.

### 7.3 Broker personally advances diesel

Starting from earned fare and broker custody of 100,000:

| Event | Debit | Credit |
|---|---|---|
| Owner-borne diesel funded personally by broker | OWNER_PAYABLE 10,000 | EXPENSE_REIMBURSEMENT_PAYABLE(broker) 10,000 |
| Broker recovers the advance from held funds | EXPENSE_REIMBURSEMENT_PAYABLE(broker) 10,000 | CUSTODY_RECEIVABLE(broker) 10,000 |
| Owner remittance | OWNER_PAYABLE 85,000 | CUSTODY_RECEIVABLE(broker) 85,000 |
| Broker commission retained | BROKER_COMMISSION_PAYABLE 5,000 | CUSTODY_RECEIVABLE(broker) 5,000 |

Owner profit 85,000; owner cash settlement 85,000; brokerage 5,000; all claims/custody zero. Recovering the advance is not brokerage income.

### 7.4 Broker spends held trip funds on diesel

For the same owner-borne expense, Dr OWNER_PAYABLE 10,000 / Cr CUSTODY_RECEIVABLE(broker) 10,000. There is no personal reimbursement claim. Remit 85,000 and retain commission 5,000. All claims/custody reach zero.

### 7.5 Customer advance

Draft receives 20,000 from customer via broker: Dr CUSTODY_RECEIVABLE 20,000 / Cr CUSTOMER_ADVANCE_CREDIT 20,000. No fare earnings yet. On dispatch post full fare, then explicitly apply the advance: Dr CUSTOMER_ADVANCE_CREDIT 20,000 / Cr CUSTOMER_RECEIVABLE 20,000. For a 100,000 fare the remaining customer debt is 80,000.

### 7.6 Funding before customer payment

Broker personally settles owner fare 95,000 before customer collection: Dr OWNER_PAYABLE 95,000 / Cr TRIP_FUNDING_PAYABLE(broker) 95,000. Customer debt remains 100,000. When customer later pays broker, post the normal receipt; recover funding separately from commission. Do not use a negative custody balance to represent this advance.

### 7.7 Cancelled fare and refund

Reverse/adjust agreed charges using balanced customer/owner/commission changes. If money was already applied, move the resulting customer credit to CUSTOMER_ADVANCE_CREDIT. An actual refund debits that credit and credits the funded custody source. Prior owner/commission settlements may create recovery balances; record recoveries or personal refund funding explicitly. Incurred diesel remains an expense unless independently corrected.

## 8. Corrections and cancellation

| Rule | Requirement |
|---|---|
| BR-36 | Creators may correct only their own entries under current permissions; administrators can correct all. Include a reason. |
| BR-37 | Confirmed journals are append-only. Reverse/repost; never overwrite a recorded payment amount or date in place. |
| BR-38 | A reversal can occur once and must unwind dependent allocations/settlements first or atomically as an explicit correction plan. |
| BR-39 | Operational edits keep version and before/after audit data. Actor/time/reason cannot be supplied as falsified client values. |
| BR-40 | Cancellation charges are explicit agreed fare adjustments with an owner/broker split. Refunds are actual events, not automatic status consequences. |
| BR-41 | Corrections preserve source and document references; old issued documents remain available and visibly superseded when replaced. |

Closing a month is not implemented in v1. An old month's current report can change after an authorized correction; show generation time and preserve history explaining the change. A previously issued report/document snapshot remains reproducible.

## 9. Permissions

| Action | Origin staff | Destination staff | Administrator |
|---|---|---|---|
| Read a trip involving an assigned office | Yes | Yes | All |
| Create/edit trip details and fares | Yes | No, unless also assigned origin | Yes |
| Dispatch | Yes | No, unless also assigned origin | Yes |
| Mark arrival | No, unless also assigned destination | Yes | Yes |
| Add permitted payments/expenses | Yes | Yes | Yes |
| Correct own entry | Required operation permission + creator | Required operation permission + creator | Any |
| Correct another person's confirmed entry | No | No | Yes |
| Complete cross-office balances | No | No | Yes |
| Scoped report/export | Yes, clearly scoped | Yes, clearly scoped | Yes |
| Personal output preset | Yes | Yes | Yes |
| Shared output preset / staff administration | No | No | Yes |
| Backup credentials / restore | No | No | Yes |

BR-42: Losing an office assignment removes access, including through old preset IDs, URLs, search, receipt downloads and export requests. Disabled staff are denied even if a previous token exists. UI controls and backend authorization must agree.

## 10. Output attributes and issued documents

| Rule | Requirement |
|---|---|
| BR-43 | Server catalogue defines eligible fields, labels, groups, types, required flags and defaults per report/recipient. |
| BR-44 | Selected fields and ordering are validated on each request. A preset cannot authorize a restricted field. |
| BR-45 | Owner output excludes gross customer fare and brokerage; broker output excludes owner profitability; customer output contains only that customer's records. |
| BR-46 | Report rows/aggregate scope obey office permissions. Staff outputs explicitly state they are scoped rather than complete business balances. |
| BR-47 | Attribute visibility changes presentation, not accounting. Totals derive from authorized source data and declared filters independently of displayed columns. |
| BR-48 | Company, issuer, document number/date, recipient and applicable total/receipt amount are required issued-document fields. Period/scope remain on reports. |
| BR-49 | Personal presets are user-owned; shared presets are admin-managed. Store presentation settings, not privileged cached data. |
| BR-50 | PDF and Excel use the same selected eligible attributes. Required fields can be rendered as header/summary rather than repeated columns. |
| BR-51 | Forbidden data is absent from payloads, hidden sheets/columns, metadata, links and embedded source objects. |
| BR-52 | Issuance allocates a unique permanent number and immutable company/issuer/recipient/value/configuration snapshot. Preset changes affect new outputs only. |
| BR-53 | Reprints use the issued snapshot and original issuer name. Superseding documents use new numbers and identify the superseded document. |
| BR-54 | Selecting fewer fields does not change an invoice's authoritative amount. Do not silently add filters when a field is deselected. |

Customer invoices combine that customer's consignments on one trip. A broker monthly statement and owner monthly statement aggregate only their permitted records. Issuer name is the logged-in user's display name when issued, not whoever later prints it.

## 11. Imports, attachments and recovery

BR-55: Import only supported template versions. Preview row-level errors, resolve references and revalidate on the server before committing. Unknown/ambiguous references are errors. Idempotent batch/row keys prevent duplicates. Operational/expense imports create drafts for normal confirmation; no arbitrary journal upload.

BR-56: Do not migrate opening balances or historic records in v1. Import/export support remains available for new operations. Imported formulas are not executable data. Treat exported text beginning with formula triggers as text, and use true monetary cells only after validated numeric conversion.

BR-57: Receipt objects stay private, use opaque names and must pass size/type checks. Financial posting and receipt upload failure states are distinguishable. Referenced evidence is not silently removed by cleanup.

BR-58: Backup includes database/identity data and receipt manifests/objects; database dump alone is incomplete. Success requires verification, not merely starting a job. Incremental file copy prevents wasteful repeated downloads.

BR-59: Backups are encrypted and recoverable with a separately held recovery key. Scheduling depends on the administrator PC being online. Show stale/failure status and an off-PC-copy reminder. Test restore before production use.

BR-60: Do not automatically incur costs or discard financial history to satisfy a free-tier quota. Report quota failures and provide administrator-controlled export/recovery paths.

## 12. Development rules

- Prefer existing feature/domain interfaces over duplicate calculations in screens or exporters.
- Database migrations, permission changes and financial posting changes require meaningful integration tests.
- Commit generated lockfiles and migration files; keep keys, signing material, database dumps and personal data out of source control.
- Financial actions use transactions, idempotency and version/claim checks. Retry only operations with defined retry semantics.
- No sample balances or mock API success in production code. Development seed records stay in explicit test environments.
- No hard-coded real company identity or staff names. Setup collects them before document issuance.
- Validate inputs at the client for usability and again at the server for authority.
- Do not log passwords, tokens, receipt contents, or unrestricted report payloads.
- Centralize English strings and prepare localization hooks; do not ship unreviewed Urdu translations as completed functionality.
- Task completion requires the evidence in tasks.md; update memory.md when the implementation or a deliberate decision changes.
