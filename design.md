# Product and output design: Carrier Records

2026-10-13 Karvaan update overrides earlier English-only/global-RTL assumptions: no toggle or global RTL flip. English left, Urdu right when bounded space permits; compact English-over-Urdu stack elsewhere. Urdu font/line-height/joining/mixed text must be visually verified early in UI and PDF. Keep Latin digits and unchanged user values. Cover form decorations, tooltips, validation, status, safe errors, navigation, previews and new export labels using stable semantic keys. Preserve keyboard/focus/accessibility; legacy documents keep original labels/assets.

Version: 1.1 | Specification date: 2026-10-11

Status: Design specification; screens and document generators are not yet implemented.

## 1. Design goals

Make daily entry faster than maintaining a register. Keep trip state, amounts earned, money collected, owner settlement and profit visually distinct. Show current office context throughout. Provide direct field selection and preview for printed/PDF/Excel outputs.

The audience is internal staff using office computers, with Android access after the Windows pilot. Favor plain English labels, familiar record tables and compact forms. Do not expose implementation terminology such as RPC, journal account codes, idempotency or RLS in ordinary workflows.

## 2. Visual system: implementation defaults

| Element | Default |
|---|---|
| Surface | White cards/tables on a pale grey application background |
| Primary action | Dark teal; use consistently for Save, Confirm, Issue and Export |
| Text | Dark charcoal; muted grey only for secondary context |
| Typography | Bundled readable Latin font, minimum 14 px body; 12 px secondary/table context |
| Spacing | 8 px base rhythm; 16–24 px panel padding |
| Inputs | Label above input; clear required marker; inline validation |
| Money | PKR prefix, grouping, two decimal places; right-aligned with tabular digits |
| Business dates | DD MMM YYYY display; typed input accepts unambiguous calendar dates |
| Buttons | Explicit verb; one primary action per section |
| Status | Text badge plus color; color is never the only indicator |
| Accessibility | Keyboard navigation, visible focus, meaningful labels, adequate contrast and touch targets |

A light theme is the v1 baseline. App/company logos and contact information are configurable; do not invent company branding. English labels are centralized for later Urdu translation. Future Urdu requires reviewed translations, RTL layout and compatible document fonts, not simply reversing English tables.

## 3. Navigation and layout

Desktop: fixed left navigation, top company/office/account bar, content workspace. Navigation: Dashboard, Trips, Vehicles, Parties, Expenses, Payments, Reports, Settings. Reports contains an Outputs tab/workspace rather than a duplicate independent reporting module.

Android: compact top bar, navigation drawer, card/list views and large primary actions. Use full-width form sections instead of squeezing desktop columns. Preserve business behavior and field access across both clients.

Administrators have All offices and per-office filters. Staff see only their assignments and permitted trips. A scope chip appears on tables and report previews. Staff outputs display “Assigned-office records — not a complete business balance” with office names.

## 4. Screen specifications

### 4.1 Login and setup

Username/password; explicit online sign-in errors; password-change flow after reset. No signup or owner/customer login links. Initial administrator setup captures company name, display name, office names and basic company contact details. Company name and issuer display name are required before issuing documents.

Settings provides staff administration, office assignment, master-data archiving, categories, shared presets and administrator-only backup status. Privileged backup secrets are configured in the separate trusted helper, never in ordinary staff-facing forms.

### 4.2 Dashboard

Selected period and scope remain visible. Cards show dispatched/arrived trips, owner fare earnings, vehicle costs, vehicle operating profit, customer outstanding and owner settlement due. Label each card's date basis. Do not title collections “earnings.”

Show recent journeys and pending arrivals. Administrators see backup age/failure and quota warnings. Scoped staff cards never use global balances. Clicking a card opens the equivalent filtered report.

### 4.3 Trips list

Default columns: trip number, dispatch date, vehicle, origin/destination, owner, car count, state and settlement indicator. Search trip/registration/party; filter office, vehicle, date and status. Paginate 50 rows. Avoid placing all detailed financial fields in the default list.

New trip opens an editable draft. Dispatch is a separate action with a confirmation summary. Overlap confirmation lists the other accessible active trip or a generic conflict description when disclosure is restricted, explains the warning, and records approval.

### 4.4 Trip editor and detail

Header: trip number, vehicle, origin/destination, owner snapshot, state, dispatch/arrival dates and linked return. Tabs: Overview, Consignments, Expenses, Payments, Documents, History.

**Overview:** vehicle/driver/offices/route, planned and actual dates, notes, stops and return link. Origin controls trip details; destination sees Arrival action after dispatch. Read-only fields retain their labels and values; permission errors do not silently discard edits.

**Consignments:** customer, broker optional, car count, optional car identifiers, pickup/drop details, quote basis, brokerage method and value. Preview three labeled amounts: Customer charge, Brokerage, Owner fare share. Fixed/percentage controls and deducted/added basis use examples rather than ambiguous “net fare” labels.

**Expenses:** date, category, amount, payer, cost bearer, payment source, receipt and reimbursement status. Personal funds versus Held trip funds selection makes the funding distinction visible. The held-funds option requires a source. Show “Owner has already paid this personally” when appropriate to prevent double deduction from a remittance.

**Payments:** separate event labels for Customer receipt, Held-funds transfer, Owner settlement, Commission retained/paid, Reimbursement, Advance application, Refund and Funding/recovery. Display outstanding claims and held funds separately. A customer receipt must not change the owner settlement badge to Paid by itself.

**Documents:** issued number, recipient, issue date/user, original/superseded state and Reprint action. Create new output opens the customization workspace with trip/recipient preselected.

**History:** actor, date/time, reason and changed values. Financial reversals link to source/replacement events. Do not expose unrestricted history through a scoped record.

### 4.5 Vehicles and parties

Vehicle detail: registration, current owner, driver association if recorded, trip history, date-filtered earning/cost view and maintenance expenses. Historical trips retain their owner even if the current owner changes.

Party detail supports several roles for one real person. Tabs depend on role: related records, claims/credits, settlements and statements. Administrators see complete balances; staff see explicitly scoped values. Owner statements show owner settlement/profit, not gross customer collections.

### 4.6 Expense entry

Enter vehicle and optional trip first. Show the owner from that trip or the selected vehicle as a suggestion; explicitly confirm payer and cost bearer. Categories are editable master data, initially suggested Diesel, Oil change, Tolls, Driver allowance, Repairs, Tyres, Permits, Loading and Other.

Optional notes and receipt evidence; no compulsory image upload for a recorded expense. Receipt upload progress/failure is separate from monetary confirmation. Unlinked maintenance remains a vehicle/month expense unless staff explicitly link it to a trip.

### 4.7 Payment and allocation entry

Select action → payer/recipient/date/amount → sources and target claims → review → Confirm.

Allocation grid columns: trip, customer/claim, outstanding, allocated amount and resulting balance. Show “Allocated”, “Credit remainder” and “Total” immediately. A bulk payment requires explicit amounts; provide convenient prefill suggestions but never consume unrelated debts silently.

For receipts to an owner or broker, offer a reviewed settlement/retention component where actually applicable. Record money held for someone else independently of the recipient's own earnings. Use distinct labels for cash and non-cash offsets.

Confirmation shows all resulting claim changes. Server errors preserve in-memory input and explain what must be changed. Version conflicts show changed values and require reload/review; do not simply retry with a new version.

## 5. Reports and Outputs workspace

### 5.1 Report selection

Report families: Trip detail/profit, Vehicle monthly, Owner statement, Broker monthly commission, Customer statement, Customer invoice and Payment receipt. Administrators also access full internal reports and recovery history.

Report selectors specify period, vehicle/owner/broker/customer, office scope and financial date basis where relevant. Lifetime trip report uses a trip selection rather than pretending to be monthly. Empty states state “No records in this period/scope,” not zeros presented as a complete statement.

### 5.2 Attribute selection interaction

Desktop layout: left configuration panel, right live preview. Android uses sequential Configuration and Preview screens.

Configuration contains:

1. Output type and recipient.
2. Current filters and scope summary.
3. Saved preset selector: system defaults, personal presets and company presets.
4. Grouped checkboxes: Identity, Journey, Cars, Charges, Expenses, Payments, Balances and Notes, subject to the eligible field catalogue.
5. Selected-fields list with Up/Down controls and optional drag ordering on desktop.
6. Select all permitted, Reset defaults, Save preset and Preview actions.
7. Format options: automatic/portrait/landscape PDF and Excel sheet label.

Required document fields display a lock icon and explanation. They remain in header/summary even when not repeated in detail rows. Ineligible fields do not appear as selectable options. Modified requests are still rejected on the server.

Changing attribute selection does not change filters or monetary values. Preview labels display the report period, recipient, office scope and selected data basis. The UI must not use visible columns to recompute totals.

### 5.3 Presets

Save a name, recipient/report kind, field order and formatting. Do not save report data, credentials or a permission bypass. Staff can rename/delete their own presets. Administrators can create/manage shared company presets. System defaults remain available even after personal customization.

If a preset becomes invalid after catalogue/access changes, explain the incompatible fields and require review. Do not quietly add previously forbidden fields or increase report scope. Existing issued documents remain unchanged.

### 5.4 Example field choices

| Output | Suggested selectable details | Always excluded |
|---|---|---|
| Internal trip | Vehicle, driver, route, stops, customers, gross fares, brokerage, owner shares, costs, transfers, profits | Records outside the staff member's scope |
| Customer invoice | Vehicle, route, car count/IDs, pickup/drop, consignment lines, payment/balance details, notes | Other customers, owner profit, internal expenses and brokerage breakdown |
| Owner statement | Vehicle/trip/dates, owner fare share, owner-borne categories, reimbursements, owner settlements, balance, notes | Gross customer fare and brokerage |
| Broker monthly | Trips/dates, customer references, commission basis where permitted, earned/retained/paid/due commission, relevant transfers | Owner profitability |

Backend configuration defines exact stable keys; this table specifies behavior. Brokers' statements may include relevant settlement detail without revealing owner profit. Customer total remains the final quoted customer charge.

## 6. Printed document design

### 6.1 Common header/footer

A4 with company name and optional address/contact/logo; document title; permanent number and issue date for issued invoices/receipts; recipient; issuer display name. Reports show period and scope. Footer includes page number and supersession reference when applicable. No tax fields or assumed tax registration.

Use black/grey text suitable for printing with restrained separators. Minimum legible document body text: 9 pt. Do not shrink unlimited columns to unreadable widths; change orientation or split logical sections. Wrap long names, stops and identifiers.

### 6.2 Customer invoice

Combine that customer's consignments from one trip. Show selected journey/car/detail attributes and mandatory invoice total. Optional paid/balance details use canonical amounts. Omit internal commission/cost/profit. Company and issuing user appear regardless of selected optional columns.

### 6.3 Receipt

Show actual payer/recipient, date, amount and selected allocation references. The applicable receipt amount is mandatory. Choose the intended recipient template before exporting; an owner settlement receipt is different from a gross customer receipt held by an owner.

### 6.4 Owner and broker statements

Owner summary separates Owner fare share, Owner-borne costs, Profit, Owner settlements and Amount payable/recoverable. Selected detailed fields can be omitted without modifying summary calculations. Broker summary separates Earned commission, Retained/paid commission, Unsettled commission and relevant reimbursements/funds held.

### 6.5 Immutability and pagination

Preview before issuance reflects selected attributes. Issuance persists the configuration. Reprint retrieves the original snapshot; changes in user name, company name, preset or source records must not change the old issued file. A corrected issued document is superseded explicitly.

Repeat column headings across pages, avoid splitting short rows, repeat essential identity as needed, and show totals only from the canonical payload. Long car lists can become a selected detail section rather than a single overflowing cell.

## 7. Excel output and import design

Excel exports use the same selected attributes and order, with a report metadata area, clear headings, monetary formatting, sensible widths and a frozen heading row. Do not include a hidden “full data” sheet. Financial totals are provided by the backend; Excel presentation is not the authoritative ledger. Treat untrusted text as text rather than executable formulas.

Import uses Download template → Choose XLSX → Validate → Preview rows and errors → Confirm import. Display supported template version and counts. Unknown parties/routes and ambiguous dates require resolution. Imported operational/expense drafts use normal confirmation flows. No opening-balance or historical migration screen.

## 8. Feedback and recovery states

- Loading: skeleton/progress and disabled duplicate confirmation.
- Save: show success only after server commit; retain source record ID.
- Offline/timeout: keep unsent form input in memory and offer retry with the same request.
- Forbidden: explain changed access without disclosing the hidden record.
- Conflict: compare permitted current values and require review.
- Quota/upload failure: explain the affected operation and administrator action.
- Backup stale/failure: administrator banner with last verified success and recovery instructions.
- Empty or scoped report: visible scope, not a misleading global zero.

## 9. Design verification

Check keyboard-only desktop entry, Android touch entry, field-picker ordering, required-field explanation, mixed cash/offset review, long names, multiple stops, wide exports and multi-page car lists. Verify PDFs visually using rendered pages during implementation. Confirm selected-field parity and privacy in actual XLSX/PDF files, not just screenshots.

## Local GUI restructure (2026-10-14)

Written specification is authoritative for this work. The six glass/standard mockup PNGs are not present in the repository, the two latest attachment folders, or the relevant Downloads inventory; exact filenames were not supplied. No mockup matching is claimed. User explicitly removed the apple-look/apple-motion/archive prerequisite; no skill installation is needed.

Use KarvaanDesign shared tokens: background F4F5F7, white content, ink1D1D1F, secondary646469 (contrast-adjusted), accent0E7A3D; 8px spacing, panel22/card18/control12 radii. Glass is bounded and limited to navigation/action layers, with opaque high-contrast/accessibility/reduced-motion fallback. Forms and financial values stay opaque. Stacked English semibold/Urdu regular uses existing fonts/catalogue, global LTR, Urdu-only RTL, minimum12px Urdu before scaling, Latin identifiers/digits.

Persistent grouped navigation lives outside the existing child navigator. Narrow layout exposes the same permitted destinations in an immediate overlay. Existing account/home and route targets remain available; role changes invalidate guarded workspace contents. Money starts with the existing scoped paginated trip selection, then the existing trip allocation workflow; it does not fabricate global totals or a new API.

Only the trip-step transition may animate (250ms; reduced-motion immediate). Keep server review, overlap acknowledgements, version/idempotency and busy-dismissal guards unchanged. Existing output v1/v2 renderers and snapshot infrastructure are immutable; a new issued template requiring backend registration is a documented dependency, not authorization to change backend contracts in this presentation task.

The prior monthly-summary gate remains unresolved (p95 5.871856s); GUI changes must be measured separately and must not be presented as fixing it. T19 owner acceptance/waivers remain recorded as such. T20 remains TODO.
