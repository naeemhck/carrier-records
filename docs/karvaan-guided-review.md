# Candidate12 guided local GUI review

Baseline preserved: 662da7e607815c52eb5f9feb117d277cbe9f08a5. Compiled source: c976b9732c2e030b67cf23e262990a5ebc59467e. Version 0.2.0+12. GUI acceptance does not authorize deployment.

## Safe entry

Use http://127.0.0.1:8769/ only. Before opening it, the local-environment preflight passed: project karvaan_bilingual_u20261013, backend http://127.0.0.1:60321, business SYNTHETIC KARVAAN REVIEW ONLY. Served main.dart.js matches candidate hash 181b24ac0b7cd09fbb0918bc5b66ac6610cfe06b40ead35ca4080c24ca83a687. All 91 review-pack hashes matched. Credentials remain in ignored tools/.local/karvaan-review-auth.json: usernames maps each local username to its password. Use review_admin for administration or review_khi for Karachi staff. Never paste the password into chat; do not use hosted pilot credentials.

Prefer browser review. If manually reviewing native, open only tools/.local/candidates/0.2.0+12/windows/payload/carrier_records.exe beneath this worktree, never the installed shortcut or installer. Verified executable SHA-256: 4118f42502bd731a1dd91f774f310c309e3d8bab1e98d06fa5e929be426f6e06. Stop if the expected synthetic account/backend is absent. No native executable was launched in this guided-review pass. Browser/file panel requests returned queued; visible opening is not independently confirmed.

Earlier accidental plain-path launcher started the installed app. No inputs were sent to it; startup network traffic remains unverified. This uncertainty is preserved, not described as zero hosted traffic.

## Feedback ledger and checklist

Record Accept or screen-specific changes after each group. Screenshot acceptance is distinct from keyboard/native/device verification. Initial pass is read-only: do not save, dispatch, post money, cancel trips, issue documents or run backup/setup actions.

| Group | Review instructions | Feedback / result |
|---|---|---|
| Navigation and Trips | English above Urdu, green accent, spacing, trip rows, selected destination | ACCEPTED by owner 2026-10-15; visual approval only |
| Journey / Consignments / Review | Open synthetic draft; inspect vehicle/driver/offices, stops/car IDs, Latin digits, wrapping; Back retains values. Example customer100000.00 / brokerage5000.00 / owner95000.00. Leave without saving. | Pending owner feedback; local login guidance supplied |
| Trip detail | Summary and four tabs; arrival is separate from payment; explicitly named financial figures; history available | Pending |
| Expenses | What / Whose money / Where / Proof; payer versus cost bearer; receipt failure language; no posting | Pending |
| Money | Customer debt, held funds, owner settlement, commission and reimbursement remain distinct; no ambiguous combined outstanding | Pending |
| Reports and Documents | Scope, recipient, selected-field order, preview; compare synthetic samples; inspect issued identity separately from branding | Pending; pagination and performance blockers below |
| Masters / imports / Backups / auth | Grouping, errors, role/platform restrictions; inspect only, no account or scheduling changes | Pending |
| Narrow / accessibility | Wide and narrow browser, 200% text, focus/tab order, Escape closes active overlay; Urdu joins and mixed text wraps | Pending owner interaction; browser resizing is not Android validation |

Existing screenshots and samples: tools/.local/candidates/0.2.0+12/review-pack/. Journey/Consignments/Review screenshots are under verification/gui12-trip-smoke-2/ and verification/gui12-native-20261015-150140/. Native framework captures are not OS-input evidence. Six reference mockups remain unavailable; no matching claim.

## Independent investigations, 2026-10-15

Frozen-template pagination reproduced from preserved sample bytes and visually inspected fresh last-page renders: unit_wide.pdf page21 of21 contains explanatory text without table rows; broker_v2.pdf page7 of7 contains continuation text while totals remain on page6. Renderer output_pdf_v2.dart matches baseline. Its trailing Padding/Column follows the table independently, allowing orphaned notes. No PDF, snapshot, template or renderer was modified. A future correction needs a separately registered template version plus boundary-height/privacy/exact-total and unchanged-legacy tests; current defect remains unresolved. Initial diagnostic incorrectly assumed totals always occur on the last page and mishandled collapsed whitespace; corrected inspection records this failed attempt explicitly. Reproduction/hashes and new renders: tools/.local/gui12-guided-review/.

Same representative local five-user benchmark retained all100 measured requests: summaries48/50 successful, two HTTP500/code57014 statement timeouts; screens50/50 successful; five warmups passed. Summary p50/p95/max2.360/7.453/8.325s including failures; success-only n48 p957.341s. Screen p50/p95/max0.817/3.977/4.326s. BOTH latency targets and zero-error gate fail. No request excluded from primary distributions. See performance evidence for attribution/limits.

Native OS-input and Android-device verification remain pending. Preserve T19 acceptance, exceptions and waivers; T20 remains unstarted. No broad design changes, push, merge, installation, deployment, hosted-backend access or scheduling changes in this pass.
