# Karvaan local text-fix review

This is local synthetic review only. It does not authorize deployment. Both hosted sites, the installed Carrier Records app and production scheduling remain unchanged. T19 dispositions are preserved; T20 is unstarted.

## Identify the candidate first

Use the new candidate directory named in the final text-QA evidence and its manifest.json. Check version/source_commit and SHA-256 before opening a file. The copied Windows executable is windows/payload/carrier_records.exe; the installer is compiled only and must not be run over the installed app. Native OS-input checks remain pending. If manually launching the copied executable, verify the running process image path is the candidate path before any input; stop if it forwards to the installed application. Historical accidental-launch startup traffic remains unverified.

The final local browser artifact is served at http://127.0.0.1:8771/ after its hash/configuration checks. Use a fresh private browser window. Only backend127.0.0.1:60321 and synthetic business identity karvaan_bilingual_u20261013 are allowed. Never enter production credentials. Local test usernames are review_admin, review_khi and review_isb; existing local credentials remain in the ignored tools/.local/karvaan-review-auth.json file, outside Git/artifacts. View them only locally and enter them only in the local app; do not paste them into chat. Do not use the hosted-QA password helper for this local candidate.

## Screen checklist

1. Sign-in/change password: English above Urdu, descenders intact, full helper text at100/200%, normal obscuring. Use invalid synthetic text for mask/selection probes; never capture a real password. A failed sign-in must show safe bilingual feedback in view and announce it. Do not reset existing accounts for this review.
2. Navigation/account: complete Expenses and reimbursements label, visible focus and button semantics, no duplicate footer. Administrator destinations stay absent for staff. Account heading must not clip.
3. Trips: Karachi origin remains left of Islamabad destination; names/IDs/dates stay unchanged, Latin digits remain LTR. Inspect actual consignment quote, active/load/lifecycle labels and optional stop/car details.
4. Journey → Consignments → Review: check retained unsaved notes, full wrapping and grouped100,000.00/5,000.00/95,000.00 examples. Review/acknowledgement is mandatory for dispatch; invalid date blocks it. Cancel/Escape must leave the labelled review draft unchanged. Do not dispatch the shared review fixture.
5. Expenses: category/date; owner guidance; optional trip/expense office; icon/label separation. Payer, cost bearer, funding, custody spending and owner offsets remain distinct. For visual review, leave the form unposted.
6. Money/corrections/import drafts: grouped exact amounts, percentages unchanged, counts integral, invalid fractional counts flagged. Authoritative values and input strings must not change. Fault tests use new labelled synthetic records only; archive them through normal audited commands, never delete money/evidence.
7. Documents: empty message and pagination occupy separate scroll regions; unavailable pages stay disabled. Trip tabs reveal their selected content below the bar. Imports explain file/office prerequisites. Local/web backup action stays unavailable with a visible reason; absent backup timestamps never imply success.
8. Reports/exports: scope/recipient labels, selected order, grouped values, authoritative totals and privacy. Inspect the provided synthetic PDF/XLSX samples and actual browser downloads. Frozen v1/v2 renderers remain unchanged; the known wide continuation-only final page remains an unresolved issue.

## Feedback and open gates

Record screen, viewport/text scale, observed result and exact wording/layout change. Screenshots must contain synthetic data only. Quote-mode wording is provisional: DEDUCTED → کرائے میں شامل کمیشن; ADDED → کرائے کے علاوہ کمیشن. Existing approved glossary terms retain priority. The prior raw quote code/empty-stop None observations were fixed in candidate17 source; they are retained in historical evidence.

Monthly-summary latency/timeouts and frozen-template pagination remain separate unresolved release gates. Framework/browser resizing is not native OS-input or Android-device validation. Android output is a test-signed candidate, never T20 release acceptance. Broader rollout, installation, merge, push and deployment require separate authorization.

## Candidate17 hold

Builds and88manifest hashes pass, but final strict credential audit and release-browser smoke are blocked by unresponsive Docker CLI after disk recovery. Do not launch/distribute candidate17 as a verified review build yet. Restart Windows when safe, recover Docker without reset/purge, then follow the exact resume checks in karvaan-text-qa-evidence.md. Existing candidate12 review artifacts remain preserved.
