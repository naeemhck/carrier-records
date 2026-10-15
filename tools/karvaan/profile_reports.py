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

SAFE_ERRORS={'57014':'canceling statement due to statement timeout','42501':'permission denied','PGRST301':'JWT verification failed','PGRST303':'JWT validation failed'}

def error_evidence(value):
 code=value.get('code',value.get('error_code','UNKNOWN')) if isinstance(value,dict) else 'UNKNOWN'
 if not isinstance(code,str) or re.fullmatch(r'[0-9A-Z]{5}|PGRST[0-9]{3}|INVALID_JSON|invalid_credentials|bad_jwt|over_request_rate_limit|refresh_token_not_found',code) is None:code='UNKNOWN'
 return {'code':code,'message':SAFE_ERRORS.get(code,'Unclassified backend error; raw response not logged')}

def http_request(path,body,public_key,token=None):
 require(path.startswith('/rest/v1/rpc/') or path.startswith('/auth/v1/token') or path.startswith('/functions/v1/staff-accounts'),'Unexpected local benchmark path')
 start=time.perf_counter();utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())
 req=urllib.request.Request(API+path,data=json.dumps(body).encode(),headers={'apikey':public_key,'Authorization':'Bearer '+(token or public_key),'Content-Type':'application/json'})
 try:
  try:response=urllib.request.urlopen(req,timeout=60)
  except urllib.error.HTTPError as error:response=error
  with response:
   headers_at=time.perf_counter();raw=response.read();read_at=time.perf_counter()
   try:value=json.loads(raw)
   except (ValueError,UnicodeError):value={'code':'INVALID_JSON'}
   parsed_at=time.perf_counter();status=response.status
   meta={'utc_start':utc,'headers_wait_ms':(headers_at-start)*1000,'body_read_ms':(read_at-headers_at)*1000,'json_parse_ms':(parsed_at-read_at)*1000,'total_ms':(parsed_at-start)*1000,'bytes':len(raw),'http_status':status}
   for key in ['X-Kong-Upstream-Latency','X-Kong-Proxy-Latency']:
    v=response.headers.get(key)
    if v is not None and re.fullmatch(r'[0-9.]+',v):meta[key.lower()+'_ms']=float(v)
   if status!=200 or value=={'code':'INVALID_JSON'}:
    meta['error']=error_evidence(value);value={'http_error':status,**meta['error']}
   return value,meta
 except (urllib.error.URLError,TimeoutError,OSError) as error:
  duration=(time.perf_counter()-start)*1000
  return {'http_error':0,'code':'TRANSPORT_ERROR'},{'utc_start':utc,'headers_wait_ms':duration,'body_read_ms':0,'json_parse_ms':0,'total_ms':duration,'bytes':0,'http_status':0,'error':{'code':'TRANSPORT_ERROR','exception_type':type(error).__name__}}

def main():
 boundary();cfg=status();defines=json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text());validate_defines(defines)
 auth=json.loads((ROOT/'tools/.local/karvaan-review-auth.json').read_text());b=defines['APP_BUSINESS_ID'];folder=ROOT/'tools/.local'
 require(sql('select name from public.businesses;')=='SYNTHETIC KARVAAN REVIEW ONLY','Synthetic business required.')
 def request(path,body,token=None):return http_request(path,body,cfg['ANON_KEY'],token)
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
 session_checks=[];principals=set()
 for token in tokens:
  p=rpc('get_session_profile',{},token);require(p['role']=='STAFF' and [office['id'] for office in p['offices']]==[auth['offices'][0]],'Real correctly scoped restricted users required.')
  principals.add(p['id']);claims=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='));session_checks.append({'role':'STAFF','assigned_office_count':len(p['offices']),'remaining_jwt_seconds':claims['exp']-int(time.time()),'session_id':claims.get('session_id')})
 require(len(principals)==5 and len({p['session_id'] for p in session_checks})==5,'Five distinct Auth sessions required.')
 for p in session_checks:p.pop('session_id')
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
 warmups=[]
 for token in tokens:
  value,measurement=request('/rest/v1/rpc/get_scoped_report',args,token);warmups.append(measurement)
  if measurement['http_status']==200 and 'error' not in measurement:
   try:validate(value)
   except (RuntimeError,KeyError,TypeError):measurement['error']={'code':'ACCOUNTING_MISMATCH','message':'Exact warm-up report assertion failed'}
 def db_counter():
  return json.loads(sql("select jsonb_build_object('calls',coalesce(sum(calls),0),'execution_ms',coalesce(sum(total_exec_time),0)) from extensions.pg_stat_statements where query like '%get_scoped_report%' and query like '%pgrst_source%';"))
 before=db_counter()
 def worker(token):
  rows=[]
  for i in range(10):
   value,summary=request('/rest/v1/rpc/get_scoped_report',args,token)
   if summary['http_status']==200 and 'error' not in summary:
    try:validate(value)
    except (RuntimeError,KeyError,TypeError):summary['error']={'code':'ACCOUNTING_MISMATCH','message':'Exact report assertion failed'}
   screen,screen_time=request('/rest/v1/rpc/list_trips',{'search_text':'BENCH','page_offset':0},token);
   if screen_time['http_status']==200 and 'error' not in screen_time and (not isinstance(screen,dict) or len(screen.get('rows',[]))!=50):screen_time['error']={'code':'PAGINATION_MISMATCH','message':'Expected fifty rows'}
   rows.append({'user_index':tokens.index(token),'sample_index':i,'summary':summary,'screen':screen_time})
  return rows
 from report_monitor import ReportMonitor
 with ReportMonitor(enabled='--observe' in sys.argv) as monitor:
  measured=[r for group in ThreadPoolExecutor(max_workers=5).map(worker,tokens) for r in group]
 after=db_counter();delta={'calls':after['calls']-before['calls'],'execution_ms':after['execution_ms']-before['execution_ms']}
 delta['mean_execution_ms']=delta['execution_ms']/delta['calls'] if delta['calls'] else None
 result={'session_checks':session_checks,'warmups':warmups,'observation':monitor.result,'database_http_statement_delta':delta,'source_commit':subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip(),'report_source_sha256':hashlib.sha256(sql("select pg_get_functiondef('private.report_facts(jsonb,boolean)'::regprocedure);").encode()).hexdigest(),'source_dirty':bool(subprocess.run(['git','status','--porcelain'],cwd=ROOT,capture_output=True,text=True,check=True).stdout),'trips':12000,'months':12,'vehicles':20,'users':5,'samples_per_operation':50,'cache':'5 per-user summary warm-ups; existing OS/Postgres caches retained; no cache eviction; no concurrent candidate build','network':API,'samples':measured,'measurements':{kind:{key:pct([r[kind][key] for r in measured]) for key in ['headers_wait_ms','body_read_ms','json_parse_ms','total_ms']} for kind in ['summary','screen']},'ui_rendering':'Not measured by this HTTP benchmark; separate candidate UI instrumentation required.'}
 out=folder/('karvaan-report-profile-'+stamp+'.json');out.write_text(json.dumps(result,indent=2),encoding='utf-8')
 failures=sum(r[kind]['http_status']!=200 or 'error' in r[kind] for r in measured for kind in ['summary','screen'])
 result['request_counts']={kind:{'attempted':len(measured),'successful':sum(r[kind]['http_status']==200 and 'error' not in r[kind] for r in measured),'failure_codes':dict(__import__('collections').Counter(r[kind].get('error',{}).get('code','HTTP_'+str(r[kind]['http_status'])) for r in measured if r[kind]['http_status']!=200 or 'error' in r[kind]))} for kind in ['summary','screen']}
 result['success_only_latency']={kind:pct([r[kind]['total_ms'] for r in measured if r[kind]['http_status']==200 and 'error' not in r[kind]]) if any(r[kind]['http_status']==200 and 'error' not in r[kind] for r in measured) else None for kind in ['summary','screen']}
 require(len(measured)==50,'All five users and fifty samples must be retained.')
 result['failed_requests']=failures
 result['warmup_failures']=sum(w['http_status']!=200 or 'error' in w for w in warmups)
 out.write_text(json.dumps(result,indent=2),encoding='utf-8')
 print(json.dumps({'evidence':str(out),'measurements':result['measurements'],'sql_plan':'karvaan-report-plan-'+stamp+'.log'}),flush=True)
 require(not failures and not result['warmup_failures'],'Measured or warm-up requests failed; evidence retained.')
 require(result['measurements']['summary']['total_ms']['p95_ms']<=5000,'Monthly five-second gate failed; evidence retained.')
 require(result['measurements']['screen']['total_ms']['p95_ms']<=2000,'Screen two-second gate failed; evidence retained.')
if __name__=='__main__':main()
