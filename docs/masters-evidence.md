# T04 implementation and executed evidence

Workspace: `D:\portfolio\transport_project`, local Supabase and local Git only. Verification date: 2026-10-11. No hosted deployment or GitHub publication. All business/account/document/expense records used below are synthetic test fixtures, not operational identities.

## Implemented behavior

Administrators maintain company identity, offices, multi-role parties (owners, brokers, customers and drivers), vehicles, route defaults and expense categories through version-checked transactional RPCs. The Flutter workspace has company/master tabs, searchable 50-row pages, create/edit forms, active owner/driver pickers, archive/restore controls and retained entries on failure. The same retry body/ID returns one committed result; conflicting retries and stale versions are rejected. Successful saves are reported only after the server response. A conflict requires refresh and review rather than an overwrite.

Labels for suggested offices/categories are help text. The database seeds no invented company, contact, vehicle or office identities. Company branding/contact details are optional. Saving actual company identity enables the backend `require_document_setup()` gate, which returns current verified issuer display values. T13 must call this gate within document issuance; no issuance/numbering/PDF feature is claimed here.

The existing NOLOGIN/NOBYPASSRLS command owner has only the additional master insert/update permissions required. Functions pin an empty search path, derive the business and administrator from a verified live session, whitelist payload fields and use the account-management business lock when saving. Ordinary administrator/staff clients cannot insert/update/delete master tables or financial records. Private retry records and internal helpers are client-closed. Staff active choice payloads omit contact details, Auth IDs, business/creation/version metadata and archived data. Office choices provide destinations and confer no trip permission. Trip reads retain T03 office RLS; snapshot preparation requires origin-office authority and active same-business references.

Archiving preserves used rows and historical role links. Office archive immediately removes its staff access; staff with no remaining active assigned office become unavailable. New draft defaults require active vehicles, owners, drivers, roles, offices and routes. Trip owners/route values, agreed quotes, expenses and issued snapshots never derive automatically from later master values. Historical document and trip insertion in these tests uses trusted SQL fixtures because T05 entry and T13 issuance remain unimplemented.

## Executed checks

| Check | Actual result |
|---|---|
| `flutter analyze --no-pub` | PASS, no issues |
| `flutter test --no-pub` | PASS, 15 unit/widget tests, including workspace/picker loading, exact fare payloads, multi-role payloads, retained failed edits/retry IDs and version-conflict handling |
| `supabase test db` | PASS, 83 assertions across preserved T02/T03 contracts and 14 T04 privilege/payload/session checks |
| `supabase db lint --local` | PASS, empty issue list |
| Native Windows `integration_test/master_records_test.dart` | PASS, actual administrator sign-in, category create/edit/archive and archived-record retrieval; build 122.0s, UI test 12s |
| Ordinary Windows debug build, `flutter build windows --debug --no-pub` | PASS, 150.5s |
| Ordinary Android debug build, `flutter build apk --debug --no-pub` | PASS, 151.1s; no Android device execution claimed |
| `supabase db reset --local --no-seed` | PASS, all six migrations applied from an empty database |
| `python tools/tests/t03_api.py --masters` | PASS, 302 assertions, including duplicate create/update replay, one audit for create retry and null-version denial |
| Local health and fixture cleanup | Auth/REST/Storage HTTP 200; PostgreSQL ready; Auth users, businesses, password operations, master retries and storage objects all zero; migration count six |
| Privileged-value package/source audit | PASS, 667 APK entries, Windows files and tracked source files; no actual local service/secret/JWT-signing/S3 credentials found |

AT-10/11 executed through authenticated REST commands: save a vehicle/route, capture server defaults, insert a historical trip/quote/issued owner snapshot, change current ownership/fare/origin, then capture defaults and insert a new trip fixture. The new trip uses the new owner and exact `9876.54` suggestion; the prior trip, agreed `1234.56` quote and issued owner/route snapshot remain byte-equivalent. Archiving used owners, vehicles, routes and categories preserves history and the existing exact `10.01` expense. Removing an OWNER role archives its historical role link and audits the previous role list.

Direct HTTP attacks cover staff and anonymous master RPCs; POST/PATCH/DELETE attempts against all seven master tables by administrator, staff and anonymous callers; forged actor/business fields; foreign-business records/owners; unrelated-origin defaults; revoked/unassigned staff; archived-choice and raw contact-table retrieval. Permission attacks are required to fail with actual access-denied responses, including SQLSTATE 42501 for direct writes. Stale/competing edits and conflicting request IDs return conflict errors. Numeric JSON fares, negative amounts, extra decimals and incorrect owner/driver roles are rejected. Search matches stable codes independently of names; 55 matching categories return disjoint 50/5-row pages. Master edits create no financial events. The preserved T03 suite reruns account, office, financial-write, private-receipt and global/scoped-balance attacks.

## Failed attempts corrected

- Initial manual migration application failed at ownership transfer because the restricted owner lacked temporary schema CREATE. The migration now grants CREATE only for transfer, revokes it afterwards, and clean reset applies it. SQL tests assert CREATE remains revoked.
- The first history fixture omitted required issued-document `format_options`; the fixture was corrected rather than relaxing the schema.
- A no-financial-side-effect assertion assumed one existing T03 event, although that harness creates two. It now compares a captured pre-master count with the final count.
- Analyzer reported 12 missing-brace style issues; these were corrected and analysis returned no issues.
- The first native run built successfully but could not open the master workspace: expression callbacks returned Futures inside `setState`. Both reload callbacks now update state synchronously, a widget test covers startup/picker loading, and the native rerun passed.
- Initial private-payload SQL tests correctly failed without helper execution privileges. Positive helper tests now use temporary test membership within the rolled-back transaction; client denial assertions and persistent grants remain unchanged.

The function security review follows [PostgreSQL SECURITY DEFINER guidance](https://www.postgresql.org/docs/current/sql-createfunction.html#SQL-CREATEFUNCTION-SECURITY): restricted ownership, trusted search path and explicit execute grants.

## Ordinary debug artifact SHA-256

- Android `app/build/app/outputs/flutter-apk/app-debug.apk`: `08DDF014E98D2E857471F686B91F2211637AA788A62134D60789AAE04D41B8B5`
- Windows Dart bundle `app/build/windows/x64/runner/Debug/data/flutter_assets/kernel_blob.bin`: `F2954AC24AD3AFFDB4A23EFFEFDAFF5A71F614093AC1A8D1D8CD1D59DAC33B67`

These ordinary builds replace the native-test artifacts and contain no test configuration.

## Limits

No real company/fleet/staff data has been entered. No administrator action is required for T04 setup. Actual trip entry, operational transitions, financial posting, report rendering and document issuance remain ordered T05 onward. No release build, signing, installer, Android device execution, hosted deployment, backup or restore is claimed. Local logs/builds and temporary test configuration are ignored; test credentials are removed along with synthetic identities.
