# Payments and allocations

Use an administrator-managed staff account with an assignment to the trip's origin or destination. Open **Trips → Trip details → Payments and allocations**. The screen contains only permitted trips and does not represent a complete party or business balance.

Choose an action, actual payer, recipient, recording office, payment date, total and reason/reference. Enter explicit allocations; select each outstanding claim and, where required, its available funding source. The screen shows remaining and resulting balances, cash allocations, non-cash credit applications and identified credit remainder. Review, then confirm. Confirmation follows the committed server response.

- **Customer receipt:** reduces selected customer debt and increases recipient-held money. It does not pay the owner or broker. Use another allocation marked **Identified excess credit** for a reviewed remainder on that customer's trip.
- **Owner settlement / Commission retained or paid:** select actual custodian funds and earned claims on the same trip. Recipient may equal payer for actual retention. There is no automatic first-commission or proportional split.
- **Held-funds transfer:** moves identified custody to a different recipient, without paying earned claims or creating earnings. A later owner/commission retention requires its own explicit settlement.
- **Personally funded owner payment:** pays the owner claim using declared personal money and creates a reimbursement claim for the funder. Customer debt is unchanged. **Recover personal funding** consumes that claim and identified held funds separately.
- **Customer advance:** identifies a customer and draft trip, optionally a specific consignment. Receiving it creates held money and unused credit, with no earnings. After dispatch, choose **Apply customer credit**, with the same customer as payer/recipient, to explicitly offset eligible customer debt on that trip. Consignment-specific credits remain restricted to their consignment.
- **Refund unused customer credit:** choose the customer's unused credit and the actual payer's available custody on that trip. A refund consumes both; it cannot overdraw custody or reuse an applied credit.

For bulk payments, add each permitted trip and its explicit allocation. Add another allocation on the same trip to split a claim across several available sources or identify a receipt remainder. The total must match all allocations and credit remainder exactly. Credits and held-funds sources cannot silently move between unrelated trips.

Connection errors retain the reviewed request in memory. Retry the same confirmation after a lost response; it cannot create a second event. To change selections, reload balances and review again. A conflict requires reload and review. If a payment committed but balance reload failed, the screen states those outcomes separately and requires reload before another payment.

Funded draft identities cannot change and cancellation cannot erase financial history. Expense posting, diesel funding, expense reimbursement/mixed expense offsets and evidence uploads belong to T09. Dependent corrections and cancellation adjustment plans belong to T10; date-basis/profit reports belong to T11. Arrival remains independent of payment settlement.

No elevated Windows action, hosted deployment or real business setup is required for the local test environment. Real administrator/company/party setup remains explicit; see [account setup](accounts-setup.md) and [master setup](masters-setup.md). Never enter privileged keys into ordinary app configuration.
