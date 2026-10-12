# T12 verification evidence

All executed checks use the existing Flutter SDK and local Docker/Supabase stack. Test accounts, company labels, trips, payments and costs are synthetic and isolated in an otherwise empty loopback database. No production data, receipt bytes, credentials or raw test logs enter Git.

## Recipient and accounting cases

The mixed-customer trip has primary customer charge 80,000 / brokerage 4,000 / owner entitlement 76,000, plus a different customer's 20,000 / 1,000 / 19,000 consignment. Each has distinct car identifiers, stops and notes. Trusted fixture SQL establishes balanced dispatch journals. Actual financial RPCs receive 60,000 into broker custody, receive 20,000 into owner custody, settle 55,000 to the owner and post owner-paid expense 10,000.

Owner output shows earnings 95,000, cost 10,000, profit 85,000, cash settlement 55,000 and remaining settlement 40,000. Customer gross charges, brokerage, customer receipts and internal costs are absent recursively. The owner-held 20,000 customer receipt is not owner settlement and cannot be exposed as an owner settlement receipt. The actual owner receipt preview is 55,000.

Customer output contains only its 80,000 charge/receipts, one car and its own linked stop/note. Other customer/broker names, car IDs, stops and notes are absent. Broker output has its own 4,000 commission, without owner profit/costs or the other broker's cars. A real whole-trip advance 123.45, without a consignment ID, appears only in the actual customer's receipt/credit totals; the other customer's totals remain zero. Standalone synthetic maintenance on 61 vehicles provides disjoint fifty/eleven-row preview pages with identical cost totals 61.00. These pagination expenses are explicitly trusted confirmed fixture rows, not a claim of 61 production financial commands.

All-permitted and required-only previews have identical canonical recipient-safe financial totals and period/scope. Rows and catalogue contain only the chosen ordered keys. Required identity/total fields cannot be hidden. Preview calls create no journal, allocation, financial event or issued document. Company/issuer preview labels come from live explicit synthetic setup; the invoice covers only the selected customer's trip charge 80,000 and shows Not issued — preview.

## Direct calls and presets

Real managed staff HTTP calls reject forged forbidden fields, unknown/duplicate keys, missing required fields, unrelated recipient roles and embedded cached payloads in format options. Ordinary staff and administrator clients cannot read/write raw catalogue/preset tables or invoke private helpers. The customization definer role has no financial write privileges; search paths are pinned and migration-only grants revoked.

Personal presets are visible/manageable only to their creator. Shared creation/update/deletion requires the administrator; staff may use a currently valid shared layout. Actor-bound duplicate request UUIDs return the original result once; changed bodies are rejected. Expected versions detect stale and concurrent changes. Delete retries return the committed result. Trusted fixture corruption of an old shared preset injects a forbidden brokerage field and cached payload: listing marks it incompatible without returning either the forbidden configuration or cached data, and use rejects it. Administrator repair requires its new current version. A shared layout does not grant unrelated-office access.

## Executed checks and fixes

Clean fourteen-migration reset exits 0. SQL suite passes 182 assertions in eleven files; error-level lint has no errors. Analyzer reports no issues (58.0s). All 59 Flutter tests pass, including required/all/reset/order selection, hidden-column accounting invariance, desktop side-by-side and compact sequential preview, ambiguous preset retry with frozen UUID/body, and a current-scope guard removing an open form.

Initial lint errors from PL/pgSQL variable ambiguity were corrected before the final clean reset. An initial trusted stale-preset fixture failed its operational version guard; it now advances the version and repairs with the matching expected version. A compact pagination layout overflow was fixed by wrapping the controls. The first native Windows build succeeded (103.5s), but its test failed because it expected "Operating profit" while the actual catalogue label is "Vehicle operating profit"; that run is not counted as passing. The assertion is corrected. Test assertions use the actual `customer_credit` key, rather than an invented `credits` alias.

Final command `python tools/tests/t03_api.py --trips --lifecycle --finance --payments --expenses --corrections --reports --reports-functional --outputs --native-outputs` exits 0 with **1,268 PASS checks**, including complete synthetic cleanup. The real Windows output/preset test passes (141.5s build / 18s test): managed staff sign-in, select-all, exact vehicle profit 85,000, hidden cost column preserving profit, personal preset save/reload/use. An independent SQL check confirms exactly one committed personal preset excluding the hidden cost field. After native logout, the harness obtains a new session, reassigns the staff to a different office, and verifies that both the prior JWT and a fresh session cannot recover the old trip through the shared preset. Generic use of that layout returns no revoked-office rows or balances. Existing T05-T11 financial/lifecycle/correction regressions and transaction rollback guarantees pass.

Ordinary Windows and Android debug builds exit 0 (58.9s / 177.3s). Android SDK XML/native-access warnings are nonfatal. Ordinary Windows kernel assets exclude the native output fixture marker. Privileged-value audit passes across **744** APK entries, Windows files and tracked source files. Source/history audit reports no sensitive findings; logs, fixtures, keys, native config and build outputs remain excluded locally.

SHA-256: Windows runner `44ac3d7ed404dbac7ff50f34440f029c87c9b6c10bae23f1e70923c7e090dd87`; Windows kernel `c95dfbd70ffb759a844427dd3290f61fe593c5c83b8d4ca2d2ffe6828cc1d47a`; Android APK `378c46d5ba521d2349714009fe28bb50be0431c09d0e4f931aec67477e5a512a`.

Auth/REST/Storage health endpoints return HTTP 200, PostgreSQL is ready, fourteen migrations are applied, and all 27 public / 10 private tables plus Auth users/sessions/identities and Storage objects contain zero synthetic records. No triggers remain disabled, no temporary privileged-role SET grants remain, and native credential configuration is absent. No administrator action is needed. T12 completion checks pass and its status is DONE; it receives a separate local commit after T11 commit `d73bfc9516cb1b7dd79951530cc88958f9b5753a`. No GitHub push, production deployment, Android device/release or restoration is claimed.

## Boundaries

AT-23 and AT-25 cover the current field catalogue, required/order/reset behavior, recipient payload restrictions and preset permissions. AT-24's T12 portion concerns selected authorized payloads/order and unchanged accounting; actual PDF/Excel file parity and hidden-file metadata inspection remain T14. No permanent numbering, issuance, printing or file export is claimed. T11's annual benchmark is recorded separately; functional report regressions do not claim a second annual benchmark. No GitHub push is authorized for this work.
