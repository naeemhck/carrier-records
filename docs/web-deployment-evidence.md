# Web deployment evidence — 2026-10-12

Later browser-fix delivery: updated build6 web artifact built/audited locally and partially exercised; user stopped Computer Use before required local/native/live UI checks completed. **No new Pages upload** was performed; deployment below remains the last published version. See [browser QA evidence](browser-bugs-evidence.md) for current results and resume gates. Do not infer that installed Windows build6 is already hosted.

The user explicitly authorized public Flutter web hosting and explicitly waived the previously required database backup for this deployment. No database dump or Storage backup was completed. This web request supersedes the earlier deferred-web scope; T19 remains IN PROGRESS, T20 TODO and the Windows restart check deferred. No production migrations, data changes, backup scheduling or paid upgrades were performed.

## Build and compatibility

- Existing SDK: Flutter 3.47.4 stable / Dart 3.13.3. App version 0.1.0+4.
- Correct configuration names: APP_ENV=production, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and APP_BUSINESS_ID. Public-only configuration was read from the installed client configuration and written to ignored tools/.local/web-public-defines.json. Key values are omitted from evidence. No privileged key is compiled into the client.
- Added Flutter web scaffold, title/manifest and SPA fallback. Scaffold generation unexpectedly replaced the lockfile/platform metadata; restored the original lockfile and retained Android/Windows metadata while adding web.
- Initial release build failed after 243.4s: the NUMERIC(18,2) maximum-paisa integer literal cannot be represented exactly by dart2js. Money now stores integer paisa as BigInt throughout parsing, arithmetic, percentage calculations and allocation previews, retaining the same decimal-string interfaces and database range. No floating-point money fallback or reduced database limit.
- Guarded Windows installed configuration and administrator backup Process/File access with kIsWeb. Browser clients use compiled public configuration; backups remain available only through the trusted Windows helper.
- Intermediate analyzer/test run found one remaining BigInt.from(int-or-BigInt) allocation expression. Fixed it without changing allocation validation. Initial suite: 76 passed / three compilation-load failures. Final full `flutter test --no-pub`: **86 passed**, exit 0, 2m38s.
- Final `flutter analyze --no-pub`: **no issues**, exit 0, 29.9s. A later standalone probe initially triggered two relative-lib-import lint notices and one print notice; switched to package imports and explicitly documented test-tool stdout, then reran clean analysis and the 11 JavaScript checks.
- Final production `flutter build web --release --no-pub --dart-define-from-file=<ignored public defines>`: **PASS**, exit 0, 544.0s; output D:\portfolio\transport_project\app\build\web. Font tree shaking and successful Wasm dry-run notices only. JavaScript release used.
- `dart compile js -O2 app/tool/web_money_probe.dart -o tools/.local/web-money-probe.js` then Node: **11 exact-money checks PASS**. Tests include adjacent paisa above 2^53, negative values, NUMERIC maximum, percentage rounding, overflow rejection and exact allocation mismatch rejection.
- Two Flutter Chrome-runner attempts did not complete. First multi-file attempt stalled and was cancelled. Verbose single-file retry compiled, launched headless Chrome and reached “Running test suite” but stalled; cancelled without a PASS claim. This does not invalidate the separately executed JavaScript arithmetic probe or actual release browser smoke; full Chrome-runner coverage remains unresolved.

## Audit and smoke tests

- Existing source/history credential audit: initial **260 tracked files, 11 intended untracked files, 493 historical blobs, zero findings**; final pre-commit repeat **260 tracked / 14 intended untracked / 493 historical blobs / zero findings**. Subsequent planning notes contain only deployment scope/evidence.
- `python tools/tests/web_artifact_audit.py app/build/web`: **PASS**, 43 files / 45,076,926 bytes, zero findings. Checks private/privileged keys, non-anon JWTs, connection credentials, dumps/signing/private filenames and Pages size/count limits. Main JavaScript SHA-256: **b92bf17399326f6e0d0aa82ebbb1eeb0eb1d6f8a83ee6791decab7be8811ac43**.
- Initial artifact audit rejected CRLF in _redirects; wrote exact UTF-8/LF `/* /index.html 200\n` to source and output, then audit passed. Added .wrangler/ exclusion; builds, ignored public defines, local diagnostics, backups and credentials remain outside Git.
- Local static server bound only to 127.0.0.1:8765. In-app browser rendered the authenticated administrator dashboard against the hosted backend; captured console error/warning list empty. No records or payments were created by this smoke test. No credentials or operational screenshots saved in Git.
- Public fresh-origin browser rendered **Carrier Records / Staff sign-in**; captured console error/warning list empty. Public sign-in itself and full web field workflows are not claimed tested.

## Hosting and verification

- Host: **Cloudflare Pages**, direct upload, production branch main. No Workers function, card, upgrade, Git integration or alternative host configured.
- URL: **https://carrier-records.pages.dev**.
- Deployment: **9b1fcaf9-b04d-4251-a08a-dfef8472d2b3**, immutable URL https://9b1fcaf9.carrier-records.pages.dev.
- Wrangler 4.149.0. OS-keyring dependency @napi-rs/keyring 1.3.0 installed; OAuth credentials stored in OS keyring. Scopes limited to account:read, user:read, pages:write and offline_access. Original authorization expired; fresh user-approved authorization succeeded.
- Empty project list verified before creation. Current CLI first delegated creation to Workers and failed to detect a static directory. Verified implementation's Pages-only creation option and used `pages project create carrier-records --production-branch main --force` to bypass delegation (not a Git force push; no existing project overwritten). First Pages API attempt rejected unverified email 8000077. After user verification, next attempt failed 8000000; dashboard also showed a refresh error. Verified no partial project, refreshed and one controlled retry succeeded.
- `npx --yes wrangler@4.149.0 pages deploy app/build/web --project-name carrier-records --branch main --commit-dirty=true`: **exit 0**, 42 assets uploaded in 22.84s plus _redirects. Deployment metadata records base b069db3 with dirty source; the web source changes are preserved in the accompanying local commit.
- `pages deployment list --project-name carrier-records`: actual **Production / main** deployment verified.
- Initial Python urllib GET returned HTTP403. Curl and the browser succeeded; no security protection changed. First curl verification omitted following the canonical /index.html redirect and incorrectly assumed status200; corrected verification uses `--location --write-out` with actual final status.
- Final curl GET verification: `/`, `/index.html`, `/flutter.js`, `/flutter_bootstrap.js`, `/main.dart.js`, `/trips`: **all HTTP200, all bytes match the audited local assets**. HTML 1,588 bytes; flutter.js 12,136; bootstrap 13,094; main.js 4,575,467. curl HEAD independently confirmed application/javascript for flutter.js.

## Manual follow-up and release boundaries

1. If OAuth is introduced, manually add the site URL to Supabase Authentication → URL Configuration → Redirect URLs. Current app uses administrator-managed username/password and disables session detection in URIs; no OAuth redirect flow is configured.
2. Manually confirm RLS policies for every table used by the public client and private Storage access policies. Public project configuration is not authorization. Do not grant additional anonymous writes or ship privileged credentials.
3. Sign in using existing accounts on the public site and carry out office-scoped field checks. Browser sessions belong to the browser origin; Windows protected-session evidence does not prove browser/device field gates. Never post while offline.
4. Windows helper manual backup remains Windows-only. Browser PDF/Excel/import/device/printing/pilot checks beyond smoke are not claimed passed. T19's clean-PC, physical-printer, pilot/recovery sign-off and restart gates remain outstanding; T20 remains TODO.

Official provider references: [Pages direct upload](https://developers.cloudflare.com/pages/get-started/direct-upload/), [Pages limits](https://developers.cloudflare.com/pages/platform/limits/). Local source is committed; no automatic GitHub push for this deployment work.
