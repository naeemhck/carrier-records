# Administrator backend preflight for the Windows pilot

These are manual setup instructions, **not a deployment result**. No hosted backend is configured by T19 packaging. Execute only on the administrator's intended empty pilot project after verifying its identity; do not overwrite an existing environment. Do not use production data to run the fixture acceptance harness. The current local helper `manage_accounts.py` deliberately supports loopback only; do not remove that restriction.

1. Select an existing authorized free project, or create an empty free pilot project in the administrator's own account. Do not enable paid upgrades. Keep credentials in the provider/administrator credential store, never staff config, Git or chat. Check project identity, active database, HTTPS endpoint and current resource limits before proceeding.
2. On the trusted source/administrator workstation, use the installed CLI's `login` browser flow, then `link --project-ref <intended-ref>`. Enter database credentials only in its local hidden prompt, never command-line `--password`, source files or logs. Review `db push --linked --skip-vault --dry-run`: an empty target must show the 19 tracked migrations in order. Then apply `db push --linked --skip-vault`, without seed/include-all/reset/prune. These flags were checked against installed CLI 2.120.0 help. If managed-role/grant/extension/runtime compatibility fails, stop and record it; do not bypass RLS or function-body validation. Validate migration versions and function owners/ACLs before real records.
3. In Authentication configuration, disable **Allow new users to sign up**, anonymous users and unused external/SMS providers; retain administrator-managed password sign-in. Under Authentication → Hooks, enable Custom Access Token using `public.staff_access_token_hook`. Preserve its migration-owned permissions; never replace it with a permissive hook. See [general Auth configuration](https://supabase.com/docs/guides/auth/general-configuration) and [custom access token hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook).
4. Data API must not expose `private` or automatically grant newly created application tables. Keep intended RPCs and their migration permissions; verify raw financial writes are denied. Verify the migration-created `receipt_files` bucket is private and five-megabyte/type restrictions and live receipt authorization apply. Do not create public receipt URLs/buckets to resolve access failures.
5. Deploy **only** `staff-accounts` and `expense-receipts` to the verified project with `functions deploy <name> --project-ref <intended-ref> --no-verify-jwt`. The repository intentionally verifies bearer tokens inside both functions through Auth and live database staff/session checks; this flag matches its existing configuration and is not removal of application authorization. Built-in SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY remain in the provider's Edge runtime only. Verify anonymous, malformed/expired JWT and disabled staff requests fail before real use. [CLI reference](https://supabase.com/docs/reference/cli/global-flags).
6. Bootstrap the first administrator on the empty backend: generate a business UUID locally, choose the actual company name, administrator username (3–32 lowercase letters/digits/dot/underscore/hyphen, starts with a letter) and display name. In the trusted Auth Users dashboard, add a confirmed password user whose internal email is exactly `<username>.<business-uuid>@staff.invalid`; use a new temporary 12–128-character password locally. Record the returned Auth user UUID privately. This is an administrator creation, not public signup or email invitation to the non-deliverable address.
7. In the trusted SQL dashboard, invoke the existing service-only bootstrap in one transaction with the actual identifiers/names. The following is a **placeholder**, not an executed statement; substitute actual values securely and quote SQL text correctly:

```sql
begin;
set local role service_role;
select public.bootstrap_staff_admin(
  business_id := '<business-uuid>'::uuid,
  company_name := '<actual company name>',
  auth_user_id := '<created-auth-user-uuid>'::uuid,
  username := '<administrator username>',
  display_name := '<actual issuer display name>'
);
commit;
```

Stop on any failure; the existing transaction rejects a populated business or mismatched Auth identity. If bootstrap rolls back, inspect the Auth identity/business state and resolve the unlinked administrator-created identity before retrying; never infer success or loosen grants. SQL dashboard membership/managed-role behavior is a hosted prerequisite still to be verified, not a claimed local test result.

8. Give staff PCs only the HTTPS URL, **public** key and business UUID in windows-installation.md. Sign into the installed app as the first administrator, change the temporary password, configure actual company/issuer, offices and master records, then create named staff and real office assignments. Test reset/disable/revoke with administrator-controlled accounts before new operational entries. Confirm staff totals are scoped and recipient fields/receipt objects stay restricted through altered direct requests.
9. Verify backend availability, complete the clean-PC/PDF-print/pilot checklist and reconcile new records before broader rollout. Include T17 actual recovery evidence and separately held recovery material. Configure no production scheduled backup as part of these steps; scheduling remains a separately authorized administrator operation. Report provider inactivity/quota failures and backup-traffic usage without artificial keepalive or paid upgrades.

Hosted provisioning, first real identities, direct authorization verification and provider/runtime compatibility remain **PENDING**. Setup instructions and local release bytes do not prove them. Preserve the isolated local development environment and prior recovery artifacts.
