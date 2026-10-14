"""Create/reuse only labelled local review data. Never log or package credentials."""
import copy,json,secrets,uuid,urllib.request,urllib.error
from local_environment import boundary,status,validate_defines,require,IDENTITY,sql,ROOT,API
boundary();cfg=status();folder=ROOT/'tools/.local'
defines_path=folder/'karvaan-test-defines.json';auth_path=folder/'karvaan-review-auth.json'
def request(path,body,token=None,priv=False):
 key=cfg['SERVICE_ROLE_KEY'] if priv else cfg['ANON_KEY']
 req=urllib.request.Request(API+path,data=json.dumps(body).encode(),headers={
  'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=30) as response:
   raw=response.read();return json.loads(raw) if raw else None
 except urllib.error.HTTPError as error:raise RuntimeError('Local synthetic setup request failed: HTTP '+str(error.code)) from None
def rpc(name,body=None,token=None,priv=False):return request('/rest/v1/rpc/'+name,body or {},token,priv)
require(rpc('karvaan_local_identity')==IDENTITY,'Wrong local identity.')
if defines_path.exists():
 validate_defines(json.loads(defines_path.read_text(encoding='utf-8')))
 require(auth_path.exists(),'Existing review credential file absent; do not duplicate accounts.')
 require(sql("select name from public.businesses;")=='SYNTHETIC KARVAAN REVIEW ONLY','Unlabelled data found.')
 print('PASS existing labelled synthetic review environment reused; no duplicate accounts.')
 raise SystemExit(0)
require(sql('select (select count(*) from public.businesses)+(select count(*) from auth.users);')=='0','Local fixture environment must be empty before review seed.')
uid=lambda:str(uuid.uuid4());business=uid();temporary='Temp!'+secrets.token_urlsafe(24);credentials={}
def login(username,password):return request('/auth/v1/token?grant_type=password',{'email':f'{username}.{business}@staff.invalid','password':password})['access_token']
def ready(username):
 token=login(username,temporary);profile=rpc('get_session_profile',token=token);password='Review!'+secrets.token_urlsafe(24)
 request('/functions/v1/staff-accounts',{'action':'change','current_password':temporary,'password':password,'expected_version':profile['version']},token)
 credentials[username]=password;return login(username,password)
admin=request('/auth/v1/admin/users',{'email':f'review_admin.{business}@staff.invalid','password':temporary,'email_confirm':True},priv=True)
rpc('bootstrap_staff_admin',{'business_id':business,'company_name':'SYNTHETIC KARVAAN REVIEW ONLY','auth_user_id':admin['id'],'username':'review_admin','display_name':'Synthetic review administrator'},priv=True)
token=ready('review_admin')
company_version=int(sql(f"select version from public.businesses where id='{business}';"))
rpc('save_master_record',{'kind':'COMPANY','target_id':business,'request_id':uid(),'expected_version':company_version,
 'payload':{'name':'SYNTHETIC KARVAAN REVIEW ONLY','contact_details':{}}},token)
def master(kind,payload):return rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':payload},token)
offices=[master('OFFICE',{'code':code,'name':name,'archived':False}) for code,name in [('KHI','Karachi — synthetic'),('ISB','Islamabad — synthetic')]]
profile=rpc('get_session_profile',token=token)
rpc('admin_manage_staff',{'target_id':profile['id'],'expected_version':profile['version'],'display_name':profile['display_name'],'account_role':'ADMIN','active':True,'office_ids':[o['id'] for o in offices]},token)
token=login('review_admin',credentials['review_admin'])
for username,office in zip(['review_khi','review_isb'],offices):
 request('/functions/v1/staff-accounts',{'action':'create','username':username,'display_name':'Synthetic '+username,'role':'STAFF','office_ids':[office['id']],'password':temporary},token)
 ready(username)
parties=[master('PARTY',{'code':code,'display_name':name,'roles':roles,'contact_details':{},'archived':False})
 for code,name,roles in [('U-OWNER','مصنوعی مالک Synthetic owner',['OWNER','DRIVER']),('U-CUSTOMER','Synthetic customer',['CUSTOMER']),('U-BROKER','Synthetic broker',['BROKER'])]]
vehicle=master('VEHICLE',{'registration':'U-TEST-001','current_owner_id':parties[0]['id'],'default_driver_id':parties[0]['id'],'archived':False})
trip=uid();review=rpc('review_trip_overlap',{'target_id':trip,'vehicle_id':vehicle['id'],'origin_office_id':offices[0]['id'],'destination_office_id':offices[1]['id']},token)
payload={'vehicle_id':vehicle['id'],'driver_id':parties[0]['id'],'origin_office_id':offices[0]['id'],'destination_office_id':offices[1]['id'],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'LABELLED SYNTHETIC KARVAAN REVIEW — no real operations','reason':'Local candidate fixture','stops':[],
 'consignments':[{'id':uid(),'customer_id':parties[1]['id'],'broker_id':parties[2]['id'],'car_count':1,'quoted_amount':'100000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'5000.00','notes':'Synthetic only','cars':[{'id':uid(),'identifier':'U-CAR-001','pickup_stop_id':None,'drop_stop_id':None}]}],
 'review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}
saved=rpc('save_trip',{'target_id':trip,'request_id':uid(),'expected_version':0,'payload':payload},token)
# A second labelled vehicle/trip earns through the normal reviewed dispatch RPC.
vehicle2=master('VEHICLE',{'registration':'U-DOC-002','current_owner_id':parties[0]['id'],'default_driver_id':parties[0]['id'],'archived':False})
doc_trip=uid();doc_payload=copy.deepcopy(payload);doc_payload['vehicle_id']=vehicle2['id'];doc_payload['consignments'][0]['id']=uid();doc_payload['consignments'][0]['cars'][0]['id']=uid()
r=rpc('review_trip_overlap',{'target_id':doc_trip,'vehicle_id':vehicle2['id'],'origin_office_id':offices[0]['id'],'destination_office_id':offices[1]['id']},token);doc_payload['review_token']=r['review_token']
doc_saved=rpc('save_trip',{'target_id':doc_trip,'request_id':uid(),'expected_version':0,'payload':doc_payload},token)
r=rpc('review_trip_overlap',{'target_id':doc_trip,'vehicle_id':vehicle2['id'],'origin_office_id':offices[0]['id'],'destination_office_id':offices[1]['id'],'planned_dispatch_date':'2026-10-13','return_of_trip_id':None},token)
rpc('dispatch_trip',{'target_id':doc_trip,'request_id':uid(),'expected_version':doc_saved['version'],'payload':{'dispatch_date':'2026-10-13','reason':'LABELLED SYNTHETIC document review only','review_token':r['review_token'],'overlap_confirmed':False,'overlap_reason':None}},token)
defines={'APP_ENV':'test','SUPABASE_URL':API,'SUPABASE_PUBLISHABLE_KEY':cfg['ANON_KEY'],'APP_BUSINESS_ID':business}
validate_defines(defines)
defines_path.write_text(json.dumps(defines),encoding='utf-8')
auth_path.write_text(json.dumps({'usernames':credentials,'document_trip_id':doc_trip,'owner_id':parties[0]['id'],'customer_id':parties[1]['id'],'broker_id':parties[2]['id'],'trip_id':trip,'trip_number':saved['trip_number'],'offices':[o['id'] for o in offices]}),encoding='utf-8')
print('PASS distinct synthetic review business, three accounts, two offices, labelled draft and guarded public-only defines. Credentials remain ignored locally.')
