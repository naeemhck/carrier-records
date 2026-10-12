# Permanent documents and snapshots

Reports -> Outputs supports customer invoices and external-recipient payment receipts. Select the intended recipient, trip/payment, permitted fields and formatting, then preview. **Issue document** captures current server-authorized values and assigns the permanent number only after the transaction commits. Explicit company setup and a nonblank current issuer display name are required inside that transaction.

Invoices combine only the chosen customer's consignments on one trip. Receipts describe an actual committed payment and its authorized allocations. Owner receipts reflect owner settlement/funding/reimbursement, rather than gross customer collections held in custody. An invoice is not another earning event and issuing a receipt does not record another payment.

Numbers use `INV-YYYY-NNNNNN` and `RCP-YYYY-NNNNNN`, with independent business/type/year counters and at least six digits. The year/date follow the server's Pakistan-local issuance date; actual payment date stays separate. Committed numbers and originals cannot be deleted or reused. A failed transaction leaves no issued document or sequence increment; retry retains the same request UUID and body.

**Issued documents** lists only currently accessible records in fifty-row pages. Open a document to view its stored snapshot and original company, issuer, recipient, values and field/order/format configuration. Reprinting uses that snapshot, never current names, fares or presets. Losing an office assignment or disabling an account removes access to snapshot reads and cached issuance retries.

The original issuer under current source permissions, or an administrator, may choose **Prepare superseding document**. Review current filters/eligible fields/source values and provide a correction reason. The server adds a new number and a link to the old document; it never overwrites the old snapshot. A leaf may be superseded once. Invoice replacements retain the same customer/trip. Receipt replacements must refer to the same payment or its linked financial replacement lineage. Changing a preset or correcting money does not silently supersede a document.

Ambiguous confirmation retains the original command and UUID. Close and reload issued documents before preparing a changed request. Financial saves, number allocation, snapshot/source records, audit and retry cache are committed together; failure is not displayed as issuance success.

## Storage and integrity

Migration `20261012044220_immutable_documents.sql` adds narrowly privileged `carrier_documents`, private immutable source/command/retry records and `issue_document`, `get_issued_document`, `list_issued_documents`. Current authorization uses private trip/office references, separate from recipient-visible snapshots. Raw document/sequence table access stays closed to ordinary staff/admin clients. The issuer role can insert snapshots and advance counters, but cannot overwrite/delete originals or write financial journals.

Schema/template version 1 stores a complete selected/redacted payload, display snapshots and permanent identity. SHA-256 covers PostgreSQL's canonical `jsonb::text`, returned as `canonical_content` for independent verification. Retrieval verifies the digest before returning the snapshot. Superseded status is derived from immutable links; the original content/digest remains unchanged. The committed retry response is frozen, while a subsequent retrieval provides current supersession status.

T13 implements issuance and snapshot views. Actual local PDF/print/Excel generation is T14. Physical printer and Android device checks remain at their documented release gates when hardware is unavailable. See [verification evidence](documents-evidence.md).
