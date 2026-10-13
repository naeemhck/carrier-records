"""Only apply/check the v2 migration on the pinned isolated backend."""
import json,subprocess
from local_environment import boundary,status,sql,require,IDENTITY,CLI,ROOT
boundary();status()
require(json.loads(sql('select public.karvaan_local_identity();'))==IDENTITY,'Wrong local backend.')
result=subprocess.run([str(CLI),'migration','up','--local'],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
(ROOT/'tools/.local/karvaan-document-migration-safe.log').write_text(
 '\n'.join(line for line in (result.stdout+'\n'+result.stderr).splitlines() if not line.startswith('{')),
 encoding='utf-8')
for line in result.stdout.splitlines():
 if line.startswith('{'):
  item=json.loads(line)
  if item.get('_tag')=='Error':raise RuntimeError(item['error']['message'].splitlines()[0])
result.check_returncode()
require(sql("select count(*) from supabase_migrations.schema_migrations where version='20261013150331';")=='1','Migration history missing.')
members=sql("select coalesce(jsonb_agg(jsonb_build_object('role',r.rolname,'grantor',g.rolname,'admin',m.admin_option,'inherit',m.inherit_option,'set',m.set_option)),'[]') from pg_auth_members m join pg_roles r on r.oid=m.roleid join pg_roles u on u.oid=m.member join pg_roles g on g.oid=m.grantor where u.rolname='postgres' and r.rolname in('carrier_documents','carrier_security');")
# PostgreSQL 17 automatically grants the creator ADMIN with SET/INHERIT false.
# Those baseline creator grants cannot execute as the role. The migration's
# temporary SET/INHERIT-capable grants must be absent, not the baseline entries.
expected=[{'role':role,'grantor':'supabase_admin','admin':True,'set':False,'inherit':False}
 for role in ('carrier_documents','carrier_security')]
require(sorted(json.loads(members),key=lambda x:x['role'])==expected,
        'Unexpected role membership or retained SET/INHERIT migration permissions.')
require(sql("select count(*) from pg_roles where rolname in('carrier_documents','carrier_security') and (rolcanlogin or rolbypassrls or rolsuper);")=='0','Privileged application role flags changed.')
print('PASS local migration history and revoked temporary owner-role memberships.')
