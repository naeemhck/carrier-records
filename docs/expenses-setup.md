# Expenses, evidence and reimbursement entry

Use the home **Expenses and reimbursements** workspace. Ordinary staff see permitted trip costs and their assigned-office standalone expenses; administrators see business records. Select a vehicle, optionally a permitted trip, an expense office and category. Confirm the actual payer and cost bearer. Enter the expense date, exact PKR amount and notes, then review before confirming.

Choose **Payer personally bears this cost** when payer and bearer are the same. Owner-paid diesel is a cost, not an owner-entitlement settlement: 95,000 earned less 10,000 diesel gives 85,000 profit, but 95,000 remains to remit. Other personally borne costs reduce vehicle operating profit and do not reduce owner profit.

Choose **Personal funds advanced** when another party paid. For a recognized trip's owner-borne cost, explicitly confirm the owner offset and allocate its exact amount to the outstanding owner claims. A 10,000 broker-funded expense reduces 95,000 owner due to 85,000 and creates a separate 10,000 expense reimbursement claim. Commission remains 5,000. Recover that reimbursement separately from actual held funds; it is not another expense or brokerage.

Choose **Held trip funds** only with explicit available custody sources. Allocate cash spent and any owner offset independently; each component must match its required amount. Spending 10,000 held funds directly reduces custody and the applicable owner entitlement, with no personal reimbursement.

An expense before earnings recognition, standalone maintenance, a different bearer or a cost exceeding available owner entitlement uses a separate cost-recovery claim for the amount not offset against an earned owner claim. No trip is invented for maintenance. The owner at expense entry is saved independently of later vehicle-owner changes. Trip expenses use that trip's historical owner. Full monthly and lifetime report presentation remains T11; the scoped cost endpoint uses expense dates for monthly vehicle costs and all linked dates for lifetime trip costs.

Open **Claims / reimburse / recover** on the original expense. Select actual payer/recipient and explicitly allocate remaining claims and held sources. Receiving payment from a different cost bearer creates custody and consumes the recovery claim; paying/recovering a personal advance consumes its expense reimbursement claim and custody. A draft expense can later use **Non-cash owner offset against this original expense** after dispatch: select the same owner as payer/recipient and allocate the expense's recovery claim against that trip's earned owner entitlement. Review cash versus non-cash components before confirming. Claims cannot be consumed twice. Standalone recovery stays separate from unrelated trip entitlement.

A pending or ambiguous financial response retains its request ID and reviewed body. Retry that same request. A claim conflict requires reload and another review; a definite validation rejection preserves entry fields for correction. Success is shown after the RPC transaction commits. Confirmed expenses and financial postings cannot be directly edited; linked corrections and dependency handling remain T10.

## Optional private evidence

Select PNG, JPEG or PDF evidence, at most 5 MB. Evidence is optional. Financial confirmation happens first; upload status is separate. **Expense confirmed / receipt upload failed** means retry the attachment only. The expense-entry screen retains the same attachment request and bytes for an ambiguous retry. Reopening the expense workspace first checks for an existing attachment before offering another upload. Financial retries do not upload again or record another cost.

The trusted `expense-receipts` Edge Function verifies Auth plus a live staff session, office/expense access, supported actual content signatures, declared MIME and actual byte length. It computes SHA-256, uses opaque object paths and appends a link only after Storage metadata confirms the object. Ordinary clients cannot upload directly or call trusted finalization. Private authenticated downloads recheck current RLS; persistent signed URLs are unavailable. Images can be viewed in the guarded private-receipt dialog; PDF bytes are authenticated and downloaded in memory, with file size shown. PDF viewing/printing/export UI is still a later document task.

An administrator can select **Clean abandoned receipt uploads**. Only unreferenced opaque uploads older than 24 hours are removed. Cleanup takes the same attachment lock and permanently reserves abandoned paths before deletion, so racing/expired requests cannot attach removed objects. Referenced evidence is retained. An expired upload needs a fresh attachment request, never a new financial posting.

## Local runtime and deployment boundary

Migration `20261011001100_expenses.sql` and `supabase/functions/expense-receipts/index.ts` implement these contracts. The local Supabase runtime loads the function; no second runtime or installer is required. Hosted deployment has not been performed. When deployment is separately authorized, deploy this function with the configured explicit Auth verification (`verify_jwt=false`); service credentials belong only in the Edge runtime, never client defines or ordinary staff packages. No real receipts or private operational data belong in Git.
