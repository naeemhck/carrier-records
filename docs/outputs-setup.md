# Authorized previews and presets

Open Reports → Outputs and presets. Choose the report and recipient, then the dates and optional office, vehicle, historical owner or trip filters. Owner, customer and broker recipients require the actual party. Lifetime trip profit and customer invoice previews require a trip; payment receipt previews require an eligible committed payment.

The server supplies field keys, labels, groups, types, required flags and defaults. Required identity and document fields stay locked. Select all permitted includes only the current eligible catalogue. Reset restores system defaults. Up/Down controls determine preview order. Desktop displays configuration beside the preview; compact screens show configuration followed by a preview with Edit configuration. Preview pages contain at most fifty rows, with totals for the entire authorized filter.

Filters determine source records. Selecting fewer columns or changing orientation/sheet label never recalculates earnings, costs, debt, credits, custody or settlement. Summaries remain canonical and recipient-safe, even when an optional detail column is hidden. Money crosses the interface as decimal strings; counts are integers. Date bases and incomplete office scope are explicit. These are current effective records, so audited corrections can change earlier periods.

Owner outputs exclude customer gross charges, brokerage and customer receipts. They show historical owner earnings, owner-borne costs/profit and separate settlement/recovery balances. Customer outputs contain only that customer's consignments, car identifiers, linked stops, notes, charges, receipts and credits. Broker outputs contain relevant consignments and brokerage/custody/payment information, excluding owner profit and internal costs. Whole-trip advances retain the identity of their actual customer even without a consignment ID.

Save a named personal preset to preserve report/recipient kinds, ordered fields and format options. Staff can update/rename/delete their own presets. Administrators can manage shared company presets; ordinary staff can use valid shared presets. System defaults always remain available. Filters, report rows, credentials and cached financial payloads are never saved in a preset. Reload catalogue and presets refreshes their current versions.

Every use rechecks live staff/office access, recipient eligibility, required fields and preset ownership. A preset grants no data access. Incompatible presets are identified and rejected, with cached/forbidden configurations omitted from the listing. Review and repair them using current permitted fields. Version conflicts require reloading before editing. Ambiguous save/delete retries preserve the original request UUID and body; success follows the committed response.

Document previews require explicit company setup and use current company/issuer labels. They display **Not issued — preview** and allocate no permanent document number. Owner receipt previews reflect actual owner settlement/funding/reimbursement, rather than gross customer money merely held by an owner. A bulk receipt must be fully authorized; a filter cannot silently turn it into a partial receipt.

Transactional document issuance and immutable snapshots remain T13. PDF/print/Excel generation and file-level metadata/hidden-sheet checks remain T14. This task generates authorized preview payloads and saves presentation presets only.

## Backend interfaces

Migration `20261011001400_outputs.sql` adds `get_output_catalogue`, `prepare_output`, `list_output_receipts`, `list_output_presets`, `save_output_preset` and `delete_output_preset`. Financial and recipient calculations use private scoped report facts. Raw catalogue/preset tables and retry caches are closed to ordinary clients. The server-owned catalogue is versioned SQL; changes require a reviewed migration. Preset writes use actor-bound UUID retries, version checks, audit events and the staff-administration lock. The customization role cannot write financial events or journals.

The API acceptance harness requires an empty loopback test stack and managed synthetic identities. Run `python tools/tests/t03_api.py --reports --reports-functional --outputs`; add `--native-outputs` to exercise the production Flutter repositories in Windows. Fixtures, logs, authentication material and native configuration remain local and excluded from Git.
