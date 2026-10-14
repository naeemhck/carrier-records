"""Run actual T11 financial/history/permission cases without resetting review data."""
import json,secrets,sys,uuid,subprocess,urllib.request,urllib.error
from local_environment import boundary,ROOT,status,validate_defines,sql,API
sys.path.insert(0,str(ROOT/'tools/tests'))
import t11_reports
boundary();cfg=status();d=json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text());validate_defines(d)
a=json.loads((ROOT/'tools/.local/karvaan-review-auth.json').read_text());b=d['APP_BUSINESS_ID'];prefix='ur'+uuid.uuid4().hex[:8];password='Temp!'+secrets.token_urlsafe(24);real='Check!'+secrets.token_urlsafe(24)
def request(path,body,token=None):
 req=urllib.request.Request(API+path,data=json.dumps(body).encode(),headers={'apikey':cfg['ANON_KEY'],'Authorization':'Bearer '+(token or cfg['ANON_KEY']),'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=30) as r:return r.status,json.load(r)
 except urllib.error.HTTPError as e:return e.code,json.load(e)
def rpc(name,body=None,token=None):
 if name=='save_master_record' and body and body.get('kind') in ['PARTY','VEHICLE']:
  key='code' if body['kind']=='PARTY' else 'registration';body['payload'][key]+='-'+prefix
 if name=='save_master_record' and body and body.get('kind')=='CATEGORY':body['payload']['name']+='-'+prefix
 return request('/rest/v1/rpc/'+name,body or {},token)
def login(name,pw=None):return request('/auth/v1/token?grant_type=password',{'email':f'{name}.{b}@staff.invalid','password':pw or password})
def good(r):
 if r[0]!=200:raise RuntimeError('Synthetic regression request failed HTTP '+str(r[0]))
 return r[1]
at=good(login('review_admin',a['usernames']['review_admin']))['access_token'];ap=good(rpc('get_session_profile',token=at))
def profile(token):return good(rpc('get_session_profile',token=token))
def edge(body,token):return request('/functions/v1/staff-accounts',body,token)
def change(token):return good(edge({'action':'change','current_password':password,'password':real,'expected_version':profile(token)['version']},token))
def ok(name,condition):
 if not condition:raise AssertionError(name)
 print('PASS '+name,flush=True)
o=good(rpc('save_master_record',{'kind':'OFFICE','target_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'expected_version':0,'payload':{'code':'U-OUT-'+prefix,'name':'Synthetic unrelated regression office','archived':False}},at))
good(edge({'action':'create','username':prefix+'outside','display_name':'Synthetic unrelated regression staff','role':'STAFF','office_ids':[o['id']],'password':password},at));change(good(login(prefix+'outside'))['access_token'])
(ROOT/'tools/.local'/('karvaan-report-regression-'+prefix+'.json')).write_text(json.dumps({'prefix':prefix,'temporary_password':password,'password':real}),encoding='utf-8')
users=[];sys.argv.append('--reports-functional')
env={'ROOT':ROOT,'rpc':rpc,'sql':sql,'ok':ok,'b':b,'at':at,'ap':ap,'office':[*a['offices'],o['id']],'report_username_prefix':prefix,'outside_username':prefix+'outside','expected_office_name':next(o['name'] for o in ap['offices'] if o['id']==a['offices'][0]),'edge':edge,'password':password,'users':users,'change':change,'login':login,'real':real,'profile':profile,'subprocess':subprocess,'container':'supabase_db_karvaan_bilingual_u20261013'}
try:
 t11_reports.verify(env)
finally:
 accounts=good(rpc('list_staff_accounts',token=at))
 for account in accounts:
  if account['username'].startswith(prefix):
   good(rpc('admin_manage_staff',{'target_id':account['id'],'expected_version':account['version'],'display_name':account['display_name'],'account_role':'STAFF','active':False,'office_ids':[]},at))
print('PASS current-source T11 report financial/history/office cases; labelled synthetic history retained, no reset/deletion.',flush=True)
