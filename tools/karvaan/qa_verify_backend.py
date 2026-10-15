"""Restricted-role/direct HTTP verification for the dedicated synthetic TEST project."""
import base64,datetime,json,sys,uuid
from qa_seed import Backend,unprotect
from qa_preview import FOLDER,REF,query,require
results=[]
def record(name,ok):
 require(ok,name);results.append({'check':name,'passed':True});print('PASS '+name,flush=True)
def main():
 b=Backend();credentials=unprotect(FOLDER/'tester-credentials.dpapi');target=json.loads((FOLDER/'target.json').read_text());s=json.loads((FOLDER/'seed-state.json').read_text());business=target['business_id']
 tokens={u:b.login(u,c['password'],business) for u,c in credentials.items()}
 identity=b.rpc('karvaan_qa_identity');record('exact synthetic TEST identity',identity=={'project_ref':REF,'business_id':business,'purpose':'synthetic-only'})
 b.call('/auth/v1/signup',{'email':'never-created@example.invalid','password':'SyntheticNonSecretValidationOnly!'},expect=[400,422]);record('public signup denied',True)
 for user,index in [('qa_khi',0),('qa_isb',1)]:
  token=tokens[user];profile=b.rpc('get_session_profile',token=token)
  record(user+' live STAFF/one assigned office',profile['role']=='STAFF' and [x['id'] for x in profile['offices']]==[s['offices'][index]['id']] and profile['must_change_password'] is False)
  b.call('/rest/v1/rpc/list_staff_accounts',{},token,expect=[403]);record(user+' account admin denied',True)
  b.call('/rest/v1/rpc/get_balance_summary',{'scope':'ALL'},token,expect=[403]);record(user+' complete business balance denied',True)
  scoped=b.rpc('get_balance_summary',{'scope':'ASSIGNED'},token);record(user+' scoped balance labelled incomplete',scoped['complete'] is False)
  for operation,allowed in [('EDIT_FARE',index==0),('DISPATCH',index==0),('ARRIVAL',index==1)]:
   body={'trip_id':s['trips'][0]['id'],'operation':operation}
   if allowed:record(user+' '+operation+' authorized',b.rpc('authorize_trip_operation',body,token) is True)
   else:b.call('/rest/v1/rpc/authorize_trip_operation',body,token,expect=[403]);record(user+' '+operation+' cross-office denied',True)
  b.call('/rest/v1/trips?id=eq.'+s['trips'][0]['id'],{'notes':'must not save'},token,method='PATCH',expect=[403]);record(user+' direct table writes denied',True)
 b.call('/rest/v1/rpc/get_trip_detail',{'trip_id':s['trips'][1]['id']},tokens['qa_khi'],expect=[403]);record('unassigned trip direct read denied',True)
 page=b.rpc('list_trips',{'search_text':'','page_offset':0},tokens['qa_khi']);record('Karachi list excludes ISB/LHR trip',s['trips'][1]['id'] not in [r['id'] for r in page['rows']])
 row=s['trips'][0];token=tokens['qa_khi'];detail=b.rpc('get_trip_detail',{'trip_id':row['id']},token)
 if detail['state']=='DRAFT':
  payload=row['payload'];review=b.rpc('review_trip_overlap',{'target_id':row['id'],'vehicle_id':payload['vehicle_id'],'origin_office_id':payload['origin_office_id'],'destination_office_id':payload['destination_office_id'],'planned_dispatch_date':'2026-10-15','return_of_trip_id':None},token)
  command={'target_id':row['id'],'request_id':str(uuid.uuid4()),'expected_version':detail['version'],'payload':{'dispatch_date':'2026-10-15','reason':'Synthetic hosted QA exact-once verification','review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}}
  result=b.rpc('dispatch_trip',command,token);retry=b.rpc('dispatch_trip',command,token);record('permitted dispatch retry returns one committed result',result==retry)
 report=b.rpc('get_scoped_report',{'report_kind':'MONTHLY_VEHICLE','filters':{'from':'2026-10-01','to':'2026-10-31'},'page_offset':0},tokens['qa_admin'])
 record('monthly authoritative owner earnings remain exact',report['totals']['owner_earnings']=='95000.00')
 security=query("select (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) unprotected_tables,(select count(*) from storage.buckets where public) public_buckets,(select count(*) from storage.buckets where id='receipts' and not public and file_size_limit=5242880) private_receipts;")[0]
 record('RLS and private five-MB receipt bucket',security=={'unprotected_tables':0,'public_buckets':0,'private_receipts':1})
 for user,token in tokens.items():b.call('/auth/v1/logout?scope=local',{},token);record(user+' probe logout',True)
 (FOLDER/'backend-verification.json').write_text(json.dumps({'project_ref':REF,'checks':results,'security':security},indent=2),encoding='utf-8')
if __name__=='__main__':
 try:main()
 except Exception as e:
  (FOLDER/'backend-verification-failure.json').write_text(json.dumps({'passed_checks':results,'error':str(e)},indent=2),encoding='utf-8');print(str(e),file=sys.stderr);sys.exit(1)
