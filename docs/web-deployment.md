# Free web deployment

Public app: https://carrier-records.pages.dev. Provider: Cloudflare Pages direct upload. See web-deployment-evidence.md for actual executed results and remaining web/release checks.

## Build

Use the installed SDK through tools/flutter.ps1. Create an ignored public-only JSON defines file outside source control with APP_ENV (`production`), SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and APP_BUSINESS_ID. These are the app's actual configuration names; SUPABASE_ANON_KEY is not read. Use a publishable key or legacy anon-role key only. Never put database credentials, secret/service-role keys, user passwords or receipt data into this file or build.

From D:\portfolio\transport_project\app:

```powershell
& ..\tools\flutter.ps1 build web --release --dart-define-from-file=..\tools\.local\web-public-defines.json
```

Ensure build/web/_redirects is UTF-8 without BOM and contains exactly `/* /index.html 200` plus a final LF. The source copy is app/web/_redirects. From the repository root:

```powershell
python tools/tests/web_artifact_audit.py app/build/web
```

Smoke-test the actual release directory in a browser on localhost before uploading. Confirm the sign-in screen and console health. Keep local servers bound to loopback. The administrator backup helper cannot run in a browser.

## Upload an update

Cloudflare sign-in is required. Credentials belong in OS keyring, never source or chat. The current installation uses Wrangler 4.149.0 and @napi-rs/keyring 1.3.0.

```powershell
npx --yes wrangler@4.149.0 login --use-keyring --scopes account:read user:read pages:write
npx --yes wrangler@4.149.0 pages project list --json
npx --yes wrangler@4.149.0 pages deploy app/build/web --project-name carrier-records --branch main
```

The intended project already exists. Do not create a replacement project, use paid services or alter unrelated projects. No GitHub auto-deployment is configured. Commit intended code locally before future uploads so deployment metadata identifies the build's source; never upload .env, backups, receipts or staff packages.

## Verify after upload

```powershell
curl.exe --location --fail --head https://carrier-records.pages.dev
curl.exe --location --fail --head https://carrier-records.pages.dev/flutter.js
curl.exe --location --fail --head https://carrier-records.pages.dev/trips
npx --yes wrangler@4.149.0 pages deployment list --project-name carrier-records
```

Open the live site and confirm it renders. Verify JavaScript responses are JavaScript, rather than HTML from a fallback. Pages canonically redirects /index.html, so follow redirects. Do not equate successful static hosting with the Windows/Android or office-pilot release gates.

Manual Supabase checks: add the URL to Auth Redirect URLs if OAuth is introduced; confirm table RLS and private receipt policies before operational use. Current username/password authentication does not use OAuth redirects. Do not disable authorization to resolve a login issue.
