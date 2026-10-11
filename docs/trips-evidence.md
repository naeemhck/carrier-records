# T05 draft trips: implementation and executed evidence

Date: 2026-10-11. Local Windows workspace and loopback Supabase only. Synthetic fixtures are created only when the database has no businesses or Auth users, then removed. No production identities or operational records are involved.

## Implemented scope

- Staff trip list/detail and draft editor; search by trip, vehicle, customer/broker and recorded owner, with office/vehicle/state/date filters and 50-row pages. Dates filter actual dispatch date where present, otherwise planned date.
- Multiple customer consignments, each with its own count, fare, quote basis and fixed/percentage brokerage. Counts include unidentified cars. Optional identifiers and consignment/car pickup/drop links refer to ordered stops on the same trip. Pickup must precede drop.
- Exact local previews, explicit application of route fare suggestions, and canonical server amounts after saving. Draft figures are labelled potential fare, with no earnings or payment posting.
- Separate loaded/empty return drafts using the same vehicle, reversing offices and linking the original. Self-links, cycles and inconsistent parent changes are rejected.
- Conservative overlap warnings for any other DISPATCHED trip on the vehicle, regardless of planned date. Visible conflicts include trip number/date; hidden conflicts produce one generic restricted warning with no hidden IDs, numbers, dates, counts or money. An actor-bound, ten-minute review ticket, explicit confirmation and reason are required; changed conflict versions invalidate that review.

## Backend contracts and access

Migration `20261011000700_draft_trips.sql` adds consignment-level stop links and private retry/sequence/overlap-review tables. Authenticated endpoints are `list_trips`, `get_trip_detail`, `review_trip_overlap` and `save_trip`. Definers use the restricted NOLOGIN `carrier_security` owner with an empty search path. Private payload/context helpers and private tables are client-inaccessible. Direct client INSERT/UPDATE/DELETE remains denied on trips, stops, consignments and car records. The draft function owner has no financial-event/journal write privilege.

Reads require an assigned origin or destination office, or administrator status; RLS also filters direct table reads. Creation requires assigned origin access. Editing requires current and proposed origin access plus creator identity, unless administrator. Choosing a destination never assigns access. Existing aggregate versions, a reason, same-business role/reference validation and server audit actor/time are enforced. Live authorization is checked again after the account/vehicle advisory locks. Screens opened from the staff home hide when the verified identity, role or office set changes.

Save is one transaction, with a UUID request ID and expected version (zero on creation). Identical retries return the recorded result; changed retries and stale/concurrent versions fail. Network-failure retries retain the exact payload, UUID and overlap ticket. The editor retains entries and disables saving after a version conflict until the user closes, refreshes and reviews the record. Server numbers, owner/route snapshots and all children are saved atomically. Unchanged vehicle/route references retain existing snapshots and agreed amounts after master changes. An existing archived customer can remain on its agreement but cannot be newly selected.

Monetary inputs are decimal strings; JSON numbers, invalid precision/ranges and inconsistent brokerage are rejected. PostgreSQL calculates derived commission/customer charge/owner entitlement and disregards forged derived prices. Individual values retain numeric(18,2) limits; combined draft totals use numeric(20,2). Dart uses integer paisa and BigInt for aggregate previews.

T06 must use the same `trip-vehicle:<UUID>` advisory lock when changing dispatched state, and the account lock ordering when verifying permissions, so an overlap ticket cannot race a lifecycle command. Dispatch, arrival, consignment delivery/cancellation and financial posting are deliberately outside these draft endpoints.

## Executed checks

- Clean local reset applied all seven migrations: PASS.
- `supabase test db`: 95 assertions across four files: PASS.
- `supabase db lint --local`: no issues: PASS.
- `flutter analyze --no-pub`: no issues: PASS.
- `flutter test --no-pub`: 26 unit/widget tests: PASS. Includes exact multi-customer/maximum aggregate previews, optional identifiers/counts, stop ordering/inheritance, linked returns, asynchronous list loading, lost-response retry identity, retained conflict entries and open-editor access removal.
- `python tools/tests/t03_api.py --trips --trips-native`: 344 assertions PASS, including the real Windows scoped list/detail/editor/save workflow and an administrator read verifying the persisted native edit. The native test build took 65.2s and its test completed in 12s.
- Ordinary Windows debug build: exit 0, 66.6s. Android debug APK: exit 0, 67.0s. TLS 1.2/IPv4 JAVA_TOOL_OPTIONS retained for the local Java 25 environment. `python tools/tests/t03_package_audit.py` passes: 678 APK entries, ordinary Windows files and tracked source files scanned, with no actual local privileged values found.
- Auth, REST and Storage health: HTTP 200; PostgreSQL ready. Auth users, businesses, password operations, master retries, trip retries/sequences/reviews and storage objects: zero after cleanup. Seven applied migrations; temporary native credential configuration absent.

HTTP cases exercise real RPCs and direct backend calls: filtered trip/party searches, read-only destination access, unrelated/anonymous denial, creator/admin edits, origin spoofing, every direct aggregate write method for staff/admin/anonymous, manipulated derived prices, invalid inputs, aggregate rollback, audit attribution, retries, concurrent versions, history after owner/route changes, both return types, return cycles/dependencies, stop reordering/removal, empty conversion, archived-customer retention, visible/hidden overlaps and missing/expired/changed/other-actor review tickets. The suite also retains T03 account/JWT/revocation/signup/private-storage/scoped-balance attacks. Draft commands leave financial-event counts unchanged.

## Acceptance boundaries

- AT-08 draft portion: separate customer fares/counts, multiple stops and optional identifiers are verified. Actual office arrival, active-consignment delivery and cancelled-consignment propagation remain NOT RUN in T06, as the user explicitly requested.
- AT-09 draft return/overlap portion: loaded/empty links, reversed offices, required reviewed confirmation and zero empty-draft fare are verified. Expense posting and financial effects remain later tasks; no empty-trip expense-posting success is claimed.
- No Android device execution, hosted deployment, release build/signing, production import, scheduled backup or restoration is claimed.

## Failures corrected during verification

The first direct-write test used an empty PATCH, rejected before authorization; it was changed to send a valid column and assert permission error 42501. A synthetic dispatched fixture initially lacked the required owner snapshot name, and the archived-party fixture omitted the required roles; both test fixtures were corrected. Widget tests were changed to scroll the outer list, make the entire button visible, and use bounded frame pumping while a confirmation dialog intentionally leaves a progress indicator behind it. Native selectors now target a trip row by ID rather than the same text in the search field. One stalled native test process was stopped; the rerun uses bounded waits and waits for the confirmation button to rebuild after the reason is entered. These failed attempts are not counted as successful checks.

Temporary native configuration, synthetic passwords, logs, generated packages and caches remain ignored and are not project source. All scoped T05 completion checks pass. T05 is committed locally only; no T05 push is authorized by this task.

## Ordinary debug artifact hashes

SHA-256 (ignored local artifacts, no release signing/distribution):

- Windows `app/build/windows/x64/runner/Debug/carrier_records.exe`: `7040A70DFC5FB01749CA31AF9FE25585A3D1A3DB83BF858A39F2E3104B18BEC2`.
- Android `app/build/app/outputs/flutter-apk/app-debug.apk`: `F44FEEC120AD4CD3E9ADA20CAEA4A10C4C928E896DBC6AB35B010E4E76CFB731`.
