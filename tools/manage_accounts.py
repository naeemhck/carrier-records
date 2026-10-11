"""Trusted LOCAL-only first-admin bootstrap / locked-password recovery.
Run interactively. Passwords are prompted without echo and never saved.
"""
import argparse,getpass,json,re,subprocess,urllib.request,urllib.error,uuid
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('action',choices=['bootstrap','recover'])
args=parser.parse_args()
status=subprocess.run(['powershell','-NoProfile','-File',str(root/'tools/supabase.ps1'),'status','-o','json'],capture_output=True,text=True,check=True)
cfg=json.loads(status.stdout);base=cfg['API_URL'];key=cfg['SERVICE_ROLE_KEY']
if base!='http://127.0.0.1:54321':raise SystemExit('Only the local loopback backend is permitted.')
def sql(query):
 r=subprocess.run(['docker','exec','-i','supabase_db_transport_project','psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=query,text=True,capture_output=True,check=True)
 return r.stdout.strip()
def api(path,body,method='POST'):
 req=urllib.request.Request(base+path,data=json.dumps(body).encode(),headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'},method=method)
 with urllib.request.urlopen(req,timeout=30) as response:
  data=response.read();return json.loads(data) if data else None
def username(prompt):
 value=input(prompt).strip().lower()
 if not re.fullmatch(r'[a-z][a-z0-9_.-]{2,31}',value):raise SystemExit('Username must start with a letter and contain 3–32 lowercase letters, digits, dots, underscores or hyphens.')
 return value
def password():
 value=getpass.getpass('Temporary password (12–128 characters): ')
 if not 12<=len(value)<=128 or value!=getpass.getpass('Confirm temporary password: '):raise SystemExit('Passwords do not match or have invalid length.')
 return value
try:
 if args.action=='bootstrap':
  if sql('select count(*) from public.businesses;')!='0':raise SystemExit('Already configured. Use the administrator account screen.')
  business=str(uuid.uuid4());company=input('Actual company name: ').strip();name=username('Administrator username: ');display=input('Administrator display name: ').strip()
  if not company or not display:raise SystemExit('Company and display name are required.')
  pw=password();identity=api('/auth/v1/admin/users',{'email':f'{name}.{business}@staff.invalid','password':pw,'email_confirm':True})
  try:api('/rest/v1/rpc/bootstrap_staff_admin',{'business_id':business,'company_name':company,'auth_user_id':identity['id'],'username':name,'display_name':display})
  except Exception:
   try:api('/auth/v1/admin/users/'+identity['id'],{},'DELETE')
   except Exception:pass
   raise
  public={'APP_ENV':'local','SUPABASE_URL':base,'SUPABASE_PUBLISHABLE_KEY':cfg['ANON_KEY'],'APP_BUSINESS_ID':business}
  (root/'config/local.json').write_text(json.dumps(public,indent=2)+'\n',encoding='utf-8')
  print('Administrator created. Public installation configuration written to ignored config/local.json. Sign in and change the temporary password. Office setup follows in T04.')
 else:
  name=username('Locked account username: ');admin=username('Active administrator username for recovery audit: ')
  rows=json.loads(sql("select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'auth_user_id',p.auth_user_id,'business_id',p.business_id,'version',p.version,'pending',p.auth_change_pending,'role',p.role,'active',p.active)),'[]') from public.staff_profiles p where p.username='"+name+"';"))
  if len(rows)!=1 or not rows[0]['pending']:raise SystemExit('Exactly one locked account is required.')
  target=rows[0];actor=sql(f"select id from public.staff_profiles where username='{admin}' and business_id='{target['business_id']}' and role='ADMIN' and active;")
  if not actor:raise SystemExit('An active administrator in the same business is required.')
  pw=password()
  api('/auth/v1/admin/users/'+target['auth_user_id'],{'password':pw},'PUT')
  api('/rest/v1/rpc/recover_staff_password',{'target_id':target['id'],'expected_version':target['version'],'actor_id':actor})
  print('Recovery completed and audited. All old sessions are revoked. Staff must sign in with the temporary password and change it.')
except (urllib.error.HTTPError,subprocess.CalledProcessError):
 raise SystemExit('Backend operation failed. Do not assume completion; inspect account status and use recovery for a locked password operation. No secrets were printed.')
