"""Reproducible synthetic-only annual report profiling; preserves review records.
Uses the established T11 seed SQL verbatim, not a reduced workload. Secrets are
read/written only in ignored local fixture files and never included in evidence.
"""
import ast,base64,hashlib,json,math,secrets,statistics,subprocess,time,uuid,urllib.request,urllib.error,sys,re
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from local_environment import ROOT,PROJECT,API,boundary,status,validate_defines,sql,require

def pct(values):
 s=sorted(values);return {'n':len(s),'p50_ms':statistics.median(s),'p95_ms':s[math.ceil(.95*len(s))-1],'max_ms':max(s)}

def main():
 boundary();cfg=status();defines=json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text());validate_defines(defines)
 auth=json.loads((ROOT/'tools/.local/karvaan-review-auth.json').read_text());b=defines['APP_BUSINESS_ID'];folder=ROOT/'tools/.local'
 require(sql('select name from public.businesses;')=='SYNTHETIC KARVAAN REVIEW ONLY','Synthetic business required.')
 def request(path,body,token=None):
  data=json.dumps(body).encode();start=time.perf_counter()
  req=urllib.request.Request(API+path,data=data,headers={'apikey':cfg['ANON_KEY'],'Authorization':'Bearer '+(token or cfg['ANON_KEY']),'Content-Type':'application/json'})
  try:
   response=urllib.request.urlopen(req,timeout=60)
  except urllib.error.HTTPError as error:response=error
  with response:
   headers_at=time.perf_counter();raw=response.read();read_at=time.perf_counter();value=json.loads(raw);parsed_at=time.perf_counter()
   if response.status!=200:value={'http_error':response.status,'error_code':value.get('code','UNKNOWN')}
  return value,{'headers_wait_ms':(headers_at-start)*1000,'body_read_ms':(read_at-headers_at)*1000,'json_parse_ms':(parsed_at-read_at)*1000,'total_ms':(parsed_at-start)*1000,'bytes':len(raw),'http_status':response.status}
 def rpc(name,body,token):return request('/rest/v1/rpc/'+name,body,token)[0]
 def login(name,password):return request('/auth/v1/token?grant_type=password',{'email':f'{name}.{b}@staff.invalid','password':password})[0]['access_token']
 admin=login('review_admin',auth['usernames']['review_admin']);ap=rpc('get_session_profile',{},admin)
 fixture_path=folder/'karvaan-performance-auth.json'
 if fixture_path.exists():creds=json.loads(fixture_path.read_text())
 else:
  creds={};require(sql("select count(*) from public.staff_profiles where username like 'uperf%';")=='0','Existing perf accounts require preserved credential file.')
  for i in range(5):
   name='uperf'+str(i);temporary='Temp!'+secrets.token_urlsafe(24);password='Perf!'+secrets.token_urlsafe(24)
   request('/functions/v1/staff-accounts',{'action':'create','username':name,'display_name':'SYNTHETIC annual performance '+str(i),'role':'STAFF','office_ids':[auth['offices'][0]],'password':temporary},admin)
   token=login(name,temporary);p=rpc('get_session_profile',{},token)
   request('/functions/v1/staff-accounts',{'action':'change','current_password':temporary,'password':password,'expected_version':p['version']},token)
   creds[name]=password;fixture_path.write_text(json.dumps(creds),encoding='utf-8')
 tokens=[login(n,p) for n,p in creds.items()];require(len(tokens)==5,'Five distinct users required.')
 for token in tokens:
  p=rpc('get_session_profile',{},token);require(p['role']=='STAFF','Real restricted users required.')
 count=int(sql(f"select count(*) from public.trips where business_id='{b}' and trip_number like 'BENCH-%';"))
 if count==0:
  cat=rpc('save_master_record',{'kind':'CATEGORY','target_id':str(uuid.uuid4()),'request_id':str(uuid.uuid4()),'expected_version':0,'payload':{'name':'SYNTHETIC annual benchmark cost','archived':False}},admin)
  context={'b':b,'owner':{'id':auth['owner_id']},'customer':{'id':auth['customer_id']},'broker':{'id':auth['broker_id']},'category':cat,'off':auth['offices'],'env':{'ap':ap}}
  tree=ast.parse((ROOT/'tools/tests/t11_reports.py').read_text())
  seeds=[n.args[0] for n in ast.walk(tree) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='sql' and n.args and isinstance(n.args[0],ast.JoinedStr) and 'create temporary table bench' in ast.unparse(n.args[0])]
  require(len(seeds)==1,'Exact established T11 fixture seed required.')
  query=eval(compile(ast.Expression(seeds[0]),'<established T11 seed>','eval'),{'__builtins__':{}},context)
  sql(query);print('PASS preserved review records; exact annual T11 seed inserted.',flush=True)
 require(sql(f"select count(*)||':'||count(distinct vehicle_id) from public.trips where business_id='{b}' and trip_number like 'BENCH-%';")=='12000:20','Annual workload mismatch.')
 args={'report_kind':'MONTHLY_VEHICLE','filters':{'from':'2026-12-01','to':'2026-12-31','search':'BENCH'},'page_offset':0}
 def validate(value):
  require(value['totals']['dispatched']=='1000.00' and value['totals']['owner_earnings']=='95000000.00' and value['totals']['vehicle_cost']=='100000.00' and value['row_count']==20,'Exact benchmark report mismatch.')
 if '--db-only' in sys.argv:
  def database_worker(token):
   claims=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='))
   claim_sql=json.dumps(claims).replace("'","''");filter_sql=json.dumps(args['filters']).replace("'","''")
   statement=f"begin;select set_config('request.jwt.claims','{claim_sql}',true);set role authenticated;"+f"explain(analyze,buffers,format json,timing off) select public.get_scoped_report('MONTHLY_VEHICLE','{filter_sql}',0);"*11+'rollback;'
   trace=subprocess.run(['docker','exec','-i','supabase_db_'+PROJECT,'psql','-U','supabase_admin','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=statement,capture_output=True,text=True,encoding='utf-8')
   require(trace.returncode==0,'Concurrent restricted SQL profile failed.')
   times=[float(x) for x in re.findall(r'"Execution Time": ([0-9.]+)',trace.stdout)]
   require(len(times)==11,'One warm-up and ten DB samples required.')
   return times[1:]
  samples=[v for group in ThreadPoolExecutor(max_workers=5).map(database_worker,tokens) for v in group]
  result={'trips':12000,'months':12,'vehicles':20,'users':5,'samples_ms':samples,'measurements':pct(samples),'cache':'one unmeasured SQL warm-up per user in each connection, no cache eviction; eleven repeated queries per user; TIMING OFF for node instrumentation, total execution includes authorization/function/JSON creation','network':'SQL through pinned isolated container; excludes client process startup and HTTP transfer','source_sha256':hashlib.sha256(sql("select pg_get_functiondef('private.report_facts(jsonb,boolean)'::regprocedure);").encode()).hexdigest()}
  out=folder/('karvaan-db-profile-'+time.strftime('%Y%m%d-%H%M%S')+'.json');out.write_text(json.dumps(result,indent=2),encoding='utf-8')
  print(json.dumps({'evidence':str(out),'database':result['measurements']}),flush=True);return
 stamp=time.strftime('%Y%m%d-%H%M%S')
 # Actual nested restricted-role SQL, session-local instrumentation and rollback.
 claims=json.loads(base64.urlsafe_b64decode(tokens[0].split('.')[1]+'==='));escaped=json.dumps(claims).replace("'","''");filters=json.dumps(args['filters']).replace("'","''")
 statement=("begin;set plan_cache_mode=force_generic_plan;" if "--generic-plan" in sys.argv else "begin;")+f"select set_config('request.jwt.claims','{escaped}',true);load 'auto_explain';set client_min_messages=log;set auto_explain.log_min_duration=0;set auto_explain.log_analyze=true;set auto_explain.log_buffers=true;set auto_explain.log_timing=true;set auto_explain.log_nested_statements=true;set role authenticated;select public.get_scoped_report('MONTHLY_VEHICLE','{filters}',0);rollback;"
 trace=subprocess.run(['docker','exec','-i','supabase_db_'+PROJECT,'psql','-U','supabase_admin','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=statement,capture_output=True,text=True,encoding='utf-8')
 require(trace.returncode==0,'Restricted query profile failed.');safe=trace.stderr
 for value in [*cfg.values(),*creds.values(),*tokens]:
  if isinstance(value,str) and value:safe=safe.replace(value,'<redacted>')
 (folder/('karvaan-report-plan-'+stamp+'.log')).write_text(safe,encoding='utf-8')
 print('PASS actual restricted-role nested plan captured.',flush=True)
 if '--plan-only' in sys.argv:return
 # One documented warm-up per user; do not clear shared OS/database caches.
 for token in tokens:validate(rpc('get_scoped_report',args,token))
 def db_counter():
  return json.loads(sql("select jsonb_build_object('calls',coalesce(sum(calls),0),'execution_ms',coalesce(sum(total_exec_time),0)) from extensions.pg_stat_statements where query like '%get_scoped_report%' and query like '%pgrst_source%';"))
 before=db_counter()
 def worker(token):
  rows=[]
  for i in range(10):
   value,summary=request('/rest/v1/rpc/get_scoped_report',args,token)
   if summary['http_status']==200:validate(value)
   screen,screen_time=request('/rest/v1/rpc/list_trips',{'search_text':'BENCH','page_offset':0},token);
   if screen_time['http_status']==200:require(len(screen['rows'])==50,'Pagination mismatch.')
   rows.append({'summary':summary,'screen':screen_time})
  return rows
 measured=[r for group in ThreadPoolExecutor(max_workers=5).map(worker,tokens) for r in group]
 after=db_counter();delta={'calls':after['calls']-before['calls'],'execution_ms':after['execution_ms']-before['execution_ms']}
 delta['mean_execution_ms']=delta['execution_ms']/delta['calls'] if delta['calls'] else None
 result={'database_http_statement_delta':delta,'source_commit':subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip(),'report_source_sha256':hashlib.sha256(sql("select pg_get_functiondef('private.report_facts(jsonb,boolean)'::regprocedure);").encode()).hexdigest(),'source_dirty':bool(subprocess.run(['git','status','--porcelain'],cwd=ROOT,capture_output=True,text=True,check=True).stdout),'trips':12000,'months':12,'vehicles':20,'users':5,'samples_per_operation':50,'cache':'5 per-user summary warm-ups; existing OS/Postgres caches retained; no cache eviction; no concurrent candidate build','network':API,'samples':measured,'measurements':{kind:{key:pct([r[kind][key] for r in measured]) for key in ['headers_wait_ms','body_read_ms','json_parse_ms','total_ms']} for kind in ['summary','screen']},'ui_rendering':'Not measured by this HTTP benchmark; separate candidate UI instrumentation required.'}
 out=folder/('karvaan-report-profile-'+stamp+'.json');out.write_text(json.dumps(result,indent=2),encoding='utf-8')
 failures=sum(r[kind]['http_status']!=200 for r in measured for kind in ['summary','screen'])
 result['failed_requests']=failures
 out.write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({'evidence':str(out),'measurements':result['measurements'],'sql_plan':'karvaan-report-plan-'+stamp+'.log'}),flush=True)
 require(not failures,'Measured requests failed; evidence retained.')
 require(result['measurements']['summary']['total_ms']['p95_ms']<=5000,'Monthly five-second gate failed; evidence retained.')
 require(result['measurements']['screen']['total_ms']['p95_ms']<=2000,'Screen two-second gate failed; evidence retained.')
if __name__=='__main__':main()
