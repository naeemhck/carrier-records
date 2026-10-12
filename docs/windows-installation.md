# Windows pilot installation and updates

This is a pilot package, not authorization for broader rollout. T19 remains in progress until actual installation and office reconciliation/sign-off are recorded. T20 is not started. The ordinary installer never installs the administrator backup helper or a scheduled task.

Current supplemental instructions: use [the practical six-stage field checklist](windows-field-checks.md). The latest task requires **physical** customer, owner, broker and internal printing. PDF/virtual-print testing is useful preparation but does not replace paper inspection. The published build-3 installer is preserved unchanged; this supplemental checklist and the corrected Storage bucket wording in the source backend guide are newer than its bundled manuals.

## Requirements and administrator setup

Use Windows 10 build 19041 or later on x64, an active Internet connection, and the Microsoft Visual C++ v14 x64 runtime at least as recent as the build tools (14.44.35207). If launch reports a missing MSVCP140/VCRUNTIME140 library, an administrator must download the x64 redistributable from [Microsoft's official page](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist), verify its Microsoft signature, run it, select Install/Repair and approve UAC. Reboot if requested. Do not download individual DLLs from third parties. Flutter/Visual Studio/Docker are not staff-PC prerequisites.

Before staff sign-in, the administrator must configure the intended HTTPS Supabase backend using all 19 tracked migrations and the documented grants/RLS, private receipt bucket, disabled public signup and managed-account Edge Functions. Follow [accounts setup](accounts-setup.md), [master setup](masters-setup.md), and the feature setup documents. Verify actual company name/contact and issuer/staff display names before issuance. Create administrator and staff mappings with actual office assignments, password changes and disabled-account tests. Do not use synthetic test identities or the local Docker project as a production backend. No hosted backend or real company setup is claimed by this installer build.

Use [hosted backend preflight](windows-backend-prerequisites.md) for the exact administrator sequence; its hosted results remain unverified. Core linked setup/pilot/recovery guides are supplied beside this file. No backup helper or recovery material is supplied with them.

Keep database/service-role/secret/storage credentials entirely in the trusted administrator environment. Staff PCs receive only the HTTPS URL, public publishable/legacy anon key and business UUID. Configure each staff Windows account locally (do not send credentials in chat):

1. Close Carrier Records. Sign into the Windows account that will run it.
2. Open PowerShell normally and run:

```powershell
$configDirectory = Join-Path $env:LOCALAPPDATA 'CarrierRecords'
New-Item -ItemType Directory -Force $configDirectory | Out-Null
$publicConfig = @{
    version = 1
    url = Read-Host 'HTTPS Supabase project URL'
    publishableKey = Read-Host 'PUBLIC publishable or anon key only'
    businessId = Read-Host 'Business UUID supplied by administrator'
}
$publicConfig | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $configDirectory 'client.json') -Encoding UTF8
```

3. Start Carrier Records. Invalid/extra configuration fields, HTTP URLs, privileged keys and malformed UUIDs fail closed. Settings are public connection information, never passwords or session tokens. Do not add database strings or helper secrets. Correct the file and restart if setup is refused.

The versioned schema accepts exactly `version`, `url`, `publishableKey`, `businessId`. Production configuration is HTTPS-only. Sessions use the existing native protected store and are namespaced by backend/business, independent of app version. Changing backend/business does not reuse the prior session. Windows-account changes cannot transfer protected sessions; sign in freshly.

## Install and update

1. Obtain the versioned installer and SHA-256 from the release evidence through the trusted distribution channel. Use `Get-FileHash -Algorithm SHA256 -LiteralPath '<installer path>'` and compare the entire hash. The pilot installer is unsigned; no purchased signing certificate is assumed. Verify provenance/hash before proceeding through any Windows reputation prompt.
2. Run the installer as the intended ordinary Windows user, without Run as administrator. Default location: `%LOCALAPPDATA%\Programs\CarrierRecords`. Start menu: Carrier Records. Backend settings live separately at `%LOCALAPPDATA%\CarrierRecords\client.json`.
3. Start it from the installed Start-menu shortcut, sign in with the administrator-issued username/password and complete any required password change. Never substitute a development-runner launch for this check.
4. For updates, close the app and run the newer versioned installer under the same Windows account and in the same installation directory. The fixed installer AppId identifies the update. Verify installed file version and configuration SHA-256 before/after; settings and secure-session namespace are not version-dependent. Reopen and verify refreshed authorized access. No database migration or backup scheduling occurs on a staff-PC update.
5. Uninstall removes program files/shortcuts. It deliberately leaves public configuration and protected sessions alone; sign out before handing the PC to another person. An administrator changing or disabling an account must verify server-side revocation. Do not manually delete receipts, backups or financial records as an uninstall step.

## Exact checks for a separate clean PC

Record PC/OS/runtime versions, Windows account, installer hash, backend/project identifier without keys, date and tester in a private checklist. A VM must be separate and clean, with no Flutter/VS development runner. Record failures honestly.

1. Install as non-administrator; verify launch and setup refusal before configuration. Configure the public file, restart, perform login/password change, sign out/in and restart to verify secure-session persistence. Inspect the config for public fields only; never put token contents in evidence.
2. Use actual administrator and two staff accounts assigned to different offices. Confirm allowed draft/dispatch/arrival/report operations and visible scope labels; deny cross-office fares, reports/receipts, disabled accounts and revoked assignments through direct backend requests as in T18. A hidden menu alone is insufficient. Record request status/record IDs privately, without credentials.
3. Disconnect the network before a save; verify an error and no success confirmation. Reconnect and retry the same command identity, then verify exactly one committed operation. For a lost reply after commit, use the existing controlled T18 fault-proxy procedure in an isolated test backend, never arbitrarily corrupt the pilot backend. Verify no false acknowledgement and canonical retry. Check session refresh failure and fresh login.
4. Install the next intended release over the existing version. Compare public config SHA-256 and backend/business before/after; verify unchanged protected session scope, allowed login/access and persisted records. Do not call reinstalling the same version a cross-version upgrade test.
5. Generate customized PDF and XLSX statements with reordered/hidden fields, long party names, wide tables, optional car identifiers and enough rows for multiple pages. Open both actual files: repeated headings, A4 orientation, wrapping, pagination, summaries, totals and selected-field order must be correct. Inspect XLSX hidden sheets/columns and both formats' metadata for forbidden fields; fewer columns must not change accounting. Reprint an issued document after company/preset changes and compare its original digest/snapshot.
6. For the user's PDF-print workflow, select Microsoft Print to PDF where offered and inspect the resulting multi-page PDF. This verifies a virtual print path; it does not prove physical hardware printing. Record the documented physical-printer check separately as pending unless actually performed: select the office printer, print the customized multi-page statement, inspect every paper page for clipping/order/totals and record printer/driver and result.

## Office pilot and recovery approval

Begin with new records only; no opening-balance or historical import. Use [pilot checklist](windows-pilot-checklist.md). Operators review new representative trips, multiple customers/stops, actual dispatch/arrival, linked returns, expenses, partial receipts, custody/remittance, commission, credits/refunds, corrections and customized immutable statements. Independently reconcile customer debt, owner settlement, broker earnings, held money and profit; these are different balances.

The synthetic technical restoration evidence is [T17](restoration-evidence.md), with exact recovery instructions in [restore setup](restoration-setup.md); it is not office recovery sign-off. The administrator must review the verified encrypted database/Auth/receipt backup, separately held recovery material and actual recovery results before signing the pilot. No installer enables production backup scheduling. Broader rollout remains gated by actual recorded pilot/recovery approval and unresolved checks.

## Rebuild

From the source root, run `powershell -NoProfile -File tools/windows/package-release.ps1 -Compiler '<signed ISCC.exe path>'`. It builds with `APP_ENV=production`, stages only release files plus these instructions, excludes PDBs, creates the per-user installer and a hash manifest under ignored `app/build/windows/installer/<version>+<build>/`. Existing artifacts are preserved; use a new pubspec version/build for another published pilot candidate. Run credential/artifact audits before distribution. Public configuration is supplied on each PC, not compiled test definitions.

Packaging references: [Flutter Windows deployment](https://docs.flutter.dev/platform-integration/windows/building), [Inno per-user privileges](https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm), [Inno download verification](https://jrsoftware.org/isdl-verify.php).
