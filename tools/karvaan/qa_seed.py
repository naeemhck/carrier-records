"""Synthetic hosted TEST setup; privileged key stays in this trusted process only."""
import copy,json,secrets,shutil,subprocess,sys,uuid,urllib.request,urllib.error
from qa_preview import API,REF,FOLDER,ROOT,cli,query,guard,require

def protect(data,path):
 script="$v=[Console]::In.ReadToEnd(); $v | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString"
 r=subprocess.run([shutil.which('pwsh'),'-NoProfile','-Command',script],input=json.dumps(data),capture_output=True,text=True,check=True)
 path.write_text(r.stdout.strip(),encoding='utf-8')

def unprotect(path):
 script="$v=[Console]::In.ReadToEnd() | ConvertTo-SecureString; [System.Net.NetworkCredential]::new('', $v).Password"
 r=subprocess.run([shutil.which('pwsh'),'-NoProfile','-Command',script],input=path.read_text(encoding='utf-8-sig'),capture_output=True,text=True,check=True)
 return json.loads(r.stdout)

class Backend:
 def __init__(self):
  guard()
  keys=json.loads(cli('projects','api-keys','--project-ref',REF,'-o','json'))
  self.public=next(x['api_key'] for x in keys if x.get('type')=='publishable')
  self.secret=next(x['api_key'] for x in keys if x.get('name')=='service_role')
  require(self.public.startswith('sb_publishable_') and len(self.secret)>100,'Expected TEST key types absent')
 def call(self,path,body=None,token=None,priv=False,method='POST',expect=None):
  key=self.secret if priv else self.public
  req=urllib.request.Request(API+path,data=json.dumps(body).encode() if body is not None else None,method=method,headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'application/json'})
  try:
   with urllib.request.urlopen(req,timeout=45) as response:
    raw=response.read();status=response.status;result=json.loads(raw) if raw else None
  except urllib.error.HTTPError as error:
   status=error.code;raw=error.read()
   try:code=json.loads(raw).get('code','unknown')
   except Exception:code='unknown'
   if expect and status in expect:return {'http_status':status,'code':code}
   raise RuntimeError('TEST request '+path.split('?')[0]+' HTTP '+str(status)+' code '+str(code)) from None
  if expect:require(status in expect,'Expected rejection not observed: '+path)
  return result
 def rpc(self,name,body=None,token=None,priv=False):return self.call('/rest/v1/rpc/'+name,body or {},token,priv)
 def login(self,user,password,business):return self.call('/auth/v1/token?grant_type=password',{'email':user+'.'+business+'@staff.invalid','password':password})['access_token']

def seed():
 b=Backend();target=json.loads((FOLDER/'target.json').read_text());business=target['business_id'];authfile=FOLDER/'tester-credentials.dpapi';statefile=FOLDER/'seed-state.json'
 require(not statefile.exists(),'Seed already started; inspect recorded progress, do not recreate users')
 require(query('select count(*) n from auth.users;')[0]['n']==0,'TEST Auth must be empty')
 credentials={u:{'temporary':'Qa!'+secrets.token_urlsafe(24),'password':'Qa!'+secrets.token_urlsafe(24)} for u in ['qa_admin','qa_khi','qa_isb']};protect(credentials,authfile)
 state={'stage':'started','users':{}};statefile.write_text(json.dumps(state),encoding='utf-8')
 def checkpoint(stage):state['stage']=stage;statefile.write_text(json.dumps(state,indent=2),encoding='utf-8');print('PASS TEST '+stage,flush=True)
 def ready(user):
  c=credentials[user];token=b.login(user,c['temporary'],business);profile=b.rpc('get_session_profile',token=token)
  b.call('/functions/v1/staff-accounts',{'action':'change','current_password':c['temporary'],'password':c['password'],'expected_version':profile['version']},token)
  return b.login(user,c['password'],business)
 user=b.call('/auth/v1/admin/users',{'email':'qa_admin.'+business+'@staff.invalid','password':credentials['qa_admin']['temporary'],'email_confirm':True},priv=True)
 state['users']['qa_admin']=user['id'];checkpoint('admin-auth-created')
 b.rpc('bootstrap_staff_admin',{'business_id':business,'company_name':'SYNTHETIC KARVAAN TEST ONLY','auth_user_id':user['id'],'username':'qa_admin','display_name':'Synthetic QA administrator'},priv=True)
 token=ready('qa_admin');checkpoint('admin-ready')
 def master(kind,payload):return b.rpc('save_master_record',{'kind':kind,'target_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'expected_version':0,'payload':payload},token)
 offices=[master('OFFICE',{'code':code,'name':name,'archived':False}) for code,name in [('KHI','Karachi — synthetic'),('ISB','Islamabad — synthetic'),('LHR','Lahore — synthetic')]]
 state['offices']=offices
 profile=b.rpc('get_session_profile',token=token)
 b.rpc('admin_manage_staff',{'target_id':profile['id'],'expected_version':profile['version'],'display_name':profile['display_name'],'account_role':'ADMIN','active':True,'office_ids':[x['id'] for x in offices]},token)
 token=b.login('qa_admin',credentials['qa_admin']['password'],business)
 for name,office in zip(['qa_khi','qa_isb'],offices):
  b.call('/functions/v1/staff-accounts',{'action':'create','username':name,'display_name':'Synthetic '+name,'role':'STAFF','office_ids':[office['id']],'password':credentials[name]['temporary']},token)
  ready(name);checkpoint(name+'-ready')
 parties=[master('PARTY',{'code':code,'display_name':name,'roles':roles,'contact_details':{},'archived':False}) for code,name,roles in [('QA-OWNER','مصنوعی مالک Synthetic owner',['OWNER','DRIVER']),('QA-CUSTOMER','Synthetic customer',['CUSTOMER']),('QA-BROKER','Synthetic broker',['BROKER'])]]
 state['parties']=parties;trips=[]
 for i,(origin,dest) in enumerate([(offices[0],offices[1]),(offices[1],offices[2])]):
  vehicle=master('VEHICLE',{'registration':'QA-ONLY-00'+str(i+1),'current_owner_id':parties[0]['id'],'default_driver_id':parties[0]['id'],'archived':False})
  trip=str(uuid.uuid4());review=b.rpc('review_trip_overlap',{'target_id':trip,'vehicle_id':vehicle['id'],'origin_office_id':origin['id'],'destination_office_id':dest['id']},token)
  payload={'vehicle_id':vehicle['id'],'driver_id':parties[0]['id'],'origin_office_id':origin['id'],'destination_office_id':dest['id'],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'LABELLED SYNTHETIC HOSTED QA ONLY — no real operations','reason':'Synthetic testing fixture','stops':[],'consignments':[{'id':str(uuid.uuid4()),'customer_id':parties[1]['id'],'broker_id':parties[2]['id'],'car_count':1,'quoted_amount':'100000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'5000.00','notes':'Synthetic only','cars':[{'id':str(uuid.uuid4()),'identifier':'QA-CAR-001','pickup_stop_id':None,'drop_stop_id':None}]}],'review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}
  request={'target_id':trip,'request_id':str(uuid.uuid4()),'expected_version':0,'payload':payload}
  saved=b.rpc('save_trip',request,token);retried=b.rpc('save_trip',request,token)
  require(saved==retried,'Draft retry changed result');trips.append({'id':trip,'saved':saved,'payload':payload})
 state['trips']=trips;checkpoint('synthetic-fixtures-and-draft-retries-ready')
 identity={'project_ref':REF,'business_id':business,'purpose':'synthetic-only'}
 query("create function public.karvaan_qa_identity() returns jsonb language sql stable security invoker set search_path='' as $$ select '"+json.dumps(identity)+"'::jsonb $$; revoke all on function public.karvaan_qa_identity() from public; grant execute on function public.karvaan_qa_identity() to anon,authenticated; notify pgrst,'reload schema';")
 cfg={'APP_ENV':'test','SUPABASE_URL':API,'SUPABASE_PUBLISHABLE_KEY':b.public,'APP_BUSINESS_ID':business,'KARVAAN_QA_PREVIEW':True,'KARVAAN_LOCAL_ONLY':True,'use_arabic':True}
 (FOLDER/'web-public-defines.json').write_text(json.dumps(cfg),encoding='utf-8')
 checkpoint('complete');print('PASS new synthetic records only; tester passwords Windows DPAPI protected, privileged key not persisted.')

if __name__=='__main__':
 try:seed()
 except Exception as e:print(str(e),file=sys.stderr);sys.exit(1)
