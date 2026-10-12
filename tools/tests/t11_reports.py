"""Isolated local report acceptance and five-user annual benchmark; no real data."""
import base64,copy,json,time,uuid,platform,statistics,math
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,off=env['b'],env['at'],env['office'];uid=lambda:str(uuid.uuid4())
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    tokens=[]
    for i in range(5):
        name='reports'+str(i);u=success('T11 managed benchmark staff',env['edge']({'action':'create','username':name,'display_name':'Synthetic reports','role':'STAFF','office_ids':[off[0]],'password':env['password']},at))
        env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{u['id']}';"))
        env['change'](success('T11 temporary staff login',env['login'](name))['access_token']);tokens.append(success('T11 ready staff login',env['login'](name,env['real']))['access_token'])
    st=tokens[0];xt=success('T11 unrelated office login',env['login']('outside',env['real']))['access_token']
    def master(kind,p):return success('T11 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    owner,customer,broker=[master('PARTY',{'code':'T11-'+role,'display_name':'Synthetic T11 '+role,'roles':[role],'contact_details':{},'archived':False}) for role in ['OWNER','CUSTOMER','BROKER']]
    vehicle=master('VEHICLE',{'registration':'T11-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False});category=master('CATEGORY',{'name':'Synthetic T11 costs','archived':False})
    target=uid();w=success('T11 draft review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':off[0],'destination_office_id':off[1]},at))
    cp={'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':1,'quoted_amount':'100000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'5000.00','notes':'','cars':[]}
    payload={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':off[0],'destination_office_id':off[1],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic T11','reason':'Synthetic entry','stops':[],'consignments':[cp],'review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic review' if w['requires_confirmation'] else None}
    t=success('T11 save draft',rpc('save_trip',{'target_id':target,'request_id':uid(),'expected_version':0,'payload':payload},at))
    w=success('T11 dispatch review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':off[0],'destination_office_id':off[1],'planned_dispatch_date':'2026-01-30'},at))
    t=success('T11 January dispatch',rpc('dispatch_trip',{'target_id':target,'request_id':uid(),'expected_version':t['version'],'payload':{'dispatch_date':'2026-01-30','reason':'Synthetic actual date','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic review' if w['requires_confirmation'] else None}},at))
    t=success('T11 February arrival',rpc('arrive_trip',{'target_id':target,'request_id':uid(),'expected_version':t['version'],'payload':{'arrival_date':'2026-02-02','reason':'Synthetic actual arrival'}},at))
    def post(kind,p):return success('T11 '+kind,rpc('post_financial_event',{'event_kind':kind,'request_id':uid(),'expected_version':0,'payload':p},st))
    ep={'vehicle_id':vehicle['id'],'trip_id':target,'office_id':off[0],'category_id':category['id'],'effective_date':'2026-02-10','amount':'10000.00','payer_id':owner['id'],'cost_bearer_id':owner['id'],'funding_source':'SELF_FUNDED_COST','reason':'Synthetic old-trip diesel','allocations':[],'offset_confirmed':False}
    expense=post('EXPENSE',ep);stand=copy.deepcopy(ep);stand.update(trip_id=None,amount='2000.00');post('EXPENSE',stand)
    def report(month,kind='MONTHLY_VEHICLE',token=st,extra=None,offset=0):
        dates={'01':'31','02':'28','03':'31','04':'30','12':'31'}
        p={'from':'2026-'+month+'-01','to':'2026-'+month+'-'+dates[month],'vehicle_id':vehicle['id']};p.update(extra or {})
        return rpc('get_scoped_report',{'report_kind':kind,'filters':p,'page_offset':offset},token)
    jan=success('AT07 January report',report('01'));feb=success('AT19 February report',report('02'))
    ok('AT07 January dispatch earnings only',jan['totals']['customer_fare']=='100000.00' and jan['totals']['owner_earnings']=='95000.00' and jan['totals']['brokerage']=='5000.00' and jan['totals']['receipts']=='0.00' and jan['totals']['vehicle_cost']=='0.00')
    ok('AT19 older-trip and standalone February expenses',feb['totals']['vehicle_cost']=='12000.00' and feb['totals']['owner_profit']=='-12000.00' and feb['totals']['owner_due']=='95000.00' and feb['totals']['arrived']=='1.00')
    life=success('AT19 lifetime trip report',report('02','TRIP_PROFIT',extra={'trip_id':target}))
    ok('AT19 lifetime excludes standalone costs and settlement',life['totals']['owner_profit']=='85000.00' and life['totals']['vehicle_cost']=='10000.00' and life['totals']['owner_due']=='95000.00')
    c=success('T11 receivable claim',rpc('get_trip_financials',{'trip_id':target},st))['claims'];c=next(x for x in c if x['account_purpose']=='CUSTOMER_RECEIVABLE')
    rp={'payer_id':customer['id'],'payee_id':broker['id'],'office_id':off[0],'effective_date':'2026-03-05','amount':'100000.00','reason':'Synthetic receipt','allocations':[{'target_line_id':c['line_id'],'target_version':c['version'],'amount':'100000.00'}]}
    receipt=post('CUSTOMER_RECEIPT',rp);march=success('AT07 March receipt report',report('03'))
    ok('AT07 cash distinct from profit and owner settlement',march['totals']['receipts']=='100000.00' and march['totals']['custody']=='100000.00' and march['totals']['owner_due']=='95000.00' and march['totals']['customer_outstanding']=='0.00' and march['totals']['owner_earnings']=='0.00')
    def correct(event,replacement):
        r=success('T11 correction review',rpc('review_financial_correction',{'event_id':event},st))
        return success('T11 linked correction',rpc('correct_financial_event',{'event_id':event,'request_id':uid(),'expected_version':1,'payload':{'reason':'Synthetic cross-month correction','review_token':r['review_token'],'unwind_event_ids':[],'replacement':replacement}},st))
    rp.update(effective_date='2026-02-15');rp['allocations'][0]['target_version']+=1;correct(receipt['record_id'],rp)
    feb=success('AT07 corrected February receipt',report('02'));march=success('AT07 corrected March receipt',report('03'))
    ok('AT07 old-month reversal and corrected receipt date',feb['totals']['receipts']=='100000.00' and march['totals']['receipts']=='0.00' and feb['totals']['custody']=='100000.00')
    ep.update(effective_date='2026-04-10',amount='11000.00');correct(expense['event_id'],ep)
    feb=success('AT19 corrected February expense',report('02'));apr=success('AT19 corrected April expense',report('04'));life=success('AT19 corrected lifetime',report('04','TRIP_PROFIT',extra={'trip_id':target}))
    ok('AT19 effective expense dates and no duplicated cost',feb['totals']['vehicle_cost']=='2000.00' and apr['totals']['vehicle_cost']=='11000.00' and life['totals']['owner_profit']=='84000.00')
    ok('AT22 scoped completeness labels',not jan['complete'] and 'not a complete' in jan['scope'] and jan['offices']==['Test Office 0'] and success('T11 admin complete report',report('01',token=at))['complete'])
    ok('AT22 forbidden office filter',report('01',extra={'office_id':off[2]})[0]==403)
    ok('AT22 unrelated trip direct report',report('01','TRIP_PROFIT',xt,{'trip_id':target})[0]==403)
    outside=success('AT22 unrelated empty scoped report',report('01',token=xt));ok('AT22 totals cannot reveal hidden trip',outside['totals']['customer_fare']=='0.00' and outside['rows']==[])
    ok('AT22 unknown fields do not broaden scope',report('01',extra={'business_id':b})[0]==400)
    archived=uid();sql(f"insert into public.offices(id,business_id,code,name,archived_at) values('{archived}','{b}','T11-ARCHIVE','Synthetic archived office',now());")
    archived_report=success('AT22 admin archived-office history filter',report('01',token=at,extra={'office_id':archived}));ok('AT22 selected-office label and archived staff denial',not archived_report['complete'] and 'Selected-office' in archived_report['scope'] and report('01',extra={'office_id':archived})[0]==403)
    ok('T11 raw facts not callable',rpc('report_facts',{'filters':{'from':'2026-01-01','to':'2026-01-31'}},st)[0] in(403,404))
    changed=uid();newp=copy.deepcopy(payload);newp['consignments'][0]['id']=uid()
    w=success('T11 additional dispatch review',rpc('review_trip_overlap',{'target_id':changed,'vehicle_id':vehicle['id'],'origin_office_id':off[0],'destination_office_id':off[1]},at));newp.update(review_token=w['review_token'],overlap_confirmed=w['requires_confirmation'],overlap_reason='Synthetic review' if w['requires_confirmation'] else None)
    nt=success('T11 additional draft',rpc('save_trip',{'target_id':changed,'request_id':uid(),'expected_version':0,'payload':newp},at))
    w=success('T11 additional actual date review',rpc('review_trip_overlap',{'target_id':changed,'vehicle_id':vehicle['id'],'origin_office_id':off[0],'destination_office_id':off[1],'planned_dispatch_date':'2026-01-30'},at))
    nt=success('T11 additional January dispatch',rpc('dispatch_trip',{'target_id':changed,'request_id':uid(),'expected_version':nt['version'],'payload':{'dispatch_date':'2026-01-30','reason':'Synthetic date','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic review' if w['requires_confirmation'] else None}},at))
    success('T11 dispatch date linked repost',rpc('correct_trip_operation',{'action':'CORRECT_DISPATCH_DATE','target_id':changed,'request_id':uid(),'expected_version':nt['version'],'payload':{'dispatch_date':'2026-02-01','reason':'Synthetic cross-month earnings correction'}},at))
    ok('AT07 earnings correction moves January to February once',success('T11 January after date correction',report('01'))['totals']['owner_earnings']=='95000.00' and success('T11 February after date correction',report('02'))['totals']['owner_earnings']=='95000.00')
    newowner=master('PARTY',{'code':'T11-NEWOWNER','display_name':'Synthetic changed owner','roles':['OWNER'],'contact_details':{},'archived':False})
    success('T11 current owner changed',rpc('save_master_record',{'kind':'VEHICLE','target_id':vehicle['id'],'request_id':uid(),'expected_version':vehicle['version'],'payload':{'registration':'T11-SYNTHETIC','current_owner_id':newowner['id'],'default_driver_id':None,'archived':False}},at))
    oldowner=success('AT19 historical owner summary',report('04','MONTHLY_OWNER',extra={'owner_id':owner['id']}));ok('AT19 current master does not move historical earnings or costs',oldowner['totals']['owner_cost']=='11000.00' and oldowner['rows'][0]['name']=='Synthetic T11 OWNER')
    env['t11']={'token':st,'tokens':tokens,'vehicle':vehicle,'owner':owner,'customer':customer,'broker':broker,'trip':target,'category':category}
    def revoke_report_access():
        p=env['profile'](tokens[4])
        success('AT22 remove report staff assignments',rpc('admin_manage_staff',{'target_id':p['id'],'expected_version':p['version'],'display_name':p['display_name'],'account_role':'STAFF','active':True,'office_ids':[]},at))
        ok('AT22 old report JWT cannot restore revoked office scope',report('01',token=tokens[4])[0]==403)
    import sys
    if '--reports-functional' in sys.argv:
        revoke_report_access()
        print('T11 performance NOT RUN in this functional-only pass; the full annual benchmark is separate.',flush=True)
        return
    # One year, 1,000 dispatched/arrived trips each month, twenty vehicles.
    # Only this empty loopback business exists; fixtures never enter source control.
    seed_start=time.perf_counter()
    sql(f"""begin;
    insert into public.vehicles(id,business_id,registration,current_owner_id) select gen_random_uuid(),'{b}','BENCH-'||i,'{owner['id']}' from generate_series(1,20)i;
    create temporary table bench as select gen_random_uuid() tid,gen_random_uuid() eid,gen_random_uuid() cid,gen_random_uuid() xid,gen_random_uuid() xeid,w.id vid,i,(date '2026-01-01'+((i-1)/1000)*interval '1 month')::date as business_day from generate_series(1,12000)i join (select id,row_number()over(order by registration) n from public.vehicles where business_id='{b}' and registration like 'BENCH-%')w on w.n=1+(i-1)%20;
    insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,owner_id,owner_snapshot,load_kind,state,dispatch_date,arrival_date) select tid,'{b}','BENCH-'||i,vid,'{off[0]}','{off[1]}','{owner['id']}',jsonb_build_object('display_name','Synthetic T11 OWNER'),'LOADED','ARRIVED',business_day,business_day+1 from bench;
    analyze public.trips;
    insert into public.consignments(id,business_id,trip_id,customer_id,broker_id,car_count,quoted_amount,quote_mode,commission_method,commission_value,commission,customer_charge,owner_entitlement) select cid,'{b}',tid,'{customer['id']}','{broker['id']}',1,100000,'DEDUCTED','FIXED',5000,5000,100000,95000 from bench;
    analyze public.consignments;
    insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id) select eid,'{b}','DISPATCH',business_day,'{env['ap']['id']}','{off[0]}',vid,tid,cid,100000,gen_random_uuid() from bench;
    analyze public.financial_events;
    insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount) select '{b}',eid,z.party,'{off[0]}',vid,tid,cid,z.purpose,z.amount from bench cross join(values('{customer['id']}'::uuid,'CUSTOMER_RECEIVABLE',100000),('{owner['id']}'::uuid,'OWNER_PAYABLE',-95000),('{broker['id']}'::uuid,'BROKER_COMMISSION_PAYABLE',-5000))z(party,purpose,amount);
    insert into public.expenses(id,business_id,vehicle_id,trip_id,office_id,category_id,expense_date,amount,payer_id,cost_bearer_id,funding_source,state,owner_id) select xid,'{b}',vid,tid,'{off[0]}','{category['id']}',business_day+2,100,'{owner['id']}','{owner['id']}','SELF_FUNDED_COST','CONFIRMED','{owner['id']}' from bench;
    analyze public.expenses;
    insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,expense_id,amount,request_id) select xeid,'{b}','EXPENSE',business_day+2,'{env['ap']['id']}','{off[0]}',vid,tid,xid,100,gen_random_uuid() from bench;
    analyze public.trips;analyze public.financial_events;analyze public.journal_lines;analyze public.expenses;commit;""")
    args={'report_kind':'MONTHLY_VEHICLE','filters':{'from':'2026-12-01','to':'2026-12-31','search':'BENCH'},'page_offset':0}
    seed_seconds=time.perf_counter()-seed_start
    measured=success('T11 annual fixture exact summary',rpc('get_scoped_report',args,st));ok('T11 benchmark counts and amounts',measured['totals']['dispatched']=='1000.00' and measured['totals']['owner_earnings']=='95000000.00' and measured['totals']['vehicle_cost']=='100000.00' and measured['row_count']==20)
    if '--reports-diagnose' in sys.argv:
        claims=json.loads(base64.urlsafe_b64decode(st.split('.')[1]+'==='))
        statement="begin;select set_config('request.jwt.claims',"+"'"+json.dumps(claims).replace("'","''")+"',true);load 'auto_explain';set client_min_messages=log;set auto_explain.log_min_duration=0;set auto_explain.log_analyze=true;set auto_explain.log_buffers=true;set auto_explain.log_timing=false;set auto_explain.log_nested_statements=true;set role authenticated;select public.get_scoped_report('MONTHLY_VEHICLE','"+json.dumps(args['filters']).replace("'","''")+"',0);rollback;"
        trace=env['subprocess'].run(['docker','exec','-i','supabase_db_transport_project','psql','-U','supabase_admin','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=statement,text=True,capture_output=True)
        safe=trace.stderr
        for value in [env['secret'],env['anon'],st,env['real'],env['cfg'].get('JWT_SECRET','')]:
            if value:safe=safe.replace(value,'<redacted>')
        Path(env['ROOT']/'tools/.local/t18-query-plan.log').write_text(safe,encoding='utf-8')
        ok('T18 nested EXPLAIN actual restricted-role report captured',trace.returncode==0)
        return
    def worker(token):
        times={'summary':[],'screen':[]}
        for _ in range(10):
            start=time.perf_counter();r=rpc('get_scoped_report',args,token);times['summary'].append(time.perf_counter()-start);assert r[0]==200,('summary',r[0],r[1].get('message'))
            start=time.perf_counter();r=rpc('list_trips',{'search_text':'BENCH','page_offset':0},token);times['screen'].append(time.perf_counter()-start);assert r[0]==200,('screen',r[0],r[1].get('message'));assert len(r[1]['rows'])==50
        return times
    results=list(ThreadPoolExecutor(max_workers=5).map(worker,tokens));measure={}
    for key in ['summary','screen']:
        values=sorted(v for r in results for v in r[key]);measure[key]={'requests':len(values),'p50_seconds':round(statistics.median(values),4),'p95_seconds':round(values[math.ceil(len(values)*.95)-1],4),'max_seconds':round(max(values),4),'percentile_method':'nearest rank ceil(0.95*N)'}
    cpu=env['subprocess'].run(['powershell','-NoProfile','-Command','Get-CimInstance Win32_Processor | Select-Object Name,NumberOfLogicalProcessors | ConvertTo-Json -Compress'],capture_output=True,text=True).stdout.strip()
    evidence={'fixture_trips':12000,'months':12,'trips_per_month':1000,'vehicles':20,'concurrent_users':5,'network':'HTTP loopback 127.0.0.1:54321; active local Docker backend; not a hosted network benchmark','platform':platform.platform(),'cpu':cpu,'measurements':measure}
    evidence['database_bytes']=int(sql('select pg_database_size(current_database())'))
    evidence['fixture_setup_seconds']=round(seed_seconds,3)
    evidence['docker_resources']=env['subprocess'].run(['docker','info','--format','CPUs={{.NCPU}} MemoryBytes={{.MemTotal}}'],capture_output=True,text=True,check=True).stdout.strip()
    samples={key:[round(v,6) for r in results for v in r[key]] for key in ['summary','screen']}
    Path(env['ROOT']/'tools/.local/t11-performance.json').write_text(json.dumps(evidence|{'latencies_seconds':samples},indent=2),encoding='utf-8');print('T11 measured '+json.dumps(evidence),flush=True)
    ok('T11 monthly summary p95 <=5s',measure['summary']['p95_seconds']<=5)
    ok('T11 paginated screen p95 <=2s',measure['screen']['p95_seconds']<=2)
    # More than one report page, preserving canonical whole-filter totals.
    sql(f"insert into public.vehicles(id,business_id,registration,current_owner_id) select gen_random_uuid(),'{b}','PAGE-'||i,'{owner['id']}' from generate_series(1,61)i; insert into public.expenses(business_id,vehicle_id,office_id,category_id,expense_date,amount,payer_id,cost_bearer_id,funding_source,state,owner_id) select '{b}',id,'{off[0]}','{category['id']}','2026-12-04',1,'{owner['id']}','{owner['id']}','SELF_FUNDED_COST','CONFIRMED','{owner['id']}' from public.vehicles where business_id='{b}' and registration like 'PAGE-%';")
    args['filters'].pop('search');args['filters']['owner_id']=owner['id'];first=success('T11 first report page',rpc('get_scoped_report',args,st));args['page_offset']=50;second=success('T11 second report page',rpc('get_scoped_report',args,st))
    ok('T11 fixed 50-row pages no duplicates and constant totals',len(first['rows'])==50 and first['has_more'] and len(second['rows'])==32 and not second['has_more'] and not({r['id'] for r in first['rows']}&{r['id'] for r in second['rows']}) and first['totals']==second['totals'])
    env['t11']={'token':st,'tokens':tokens,'vehicle':vehicle,'owner':owner,'customer':customer,'broker':broker,'trip':target,'category':category}
    import sys
    if '--native-reports' in sys.argv:
        config_path=env['ROOT']/'tools/.local/t11-native-config.json'
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'reports0','TEST_PASSWORD':env['real']}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t11-native.log').open('w',encoding='utf-8') as log:
                built=env['subprocess'].run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/reports_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],cwd=env['ROOT']/'app',stdout=log,stderr=env['subprocess'].STDOUT)
            ok('T11 native scoped report UI',built.returncode==0)
        finally:config_path.unlink(missing_ok=True)
        env['t11']['token']=success('T11 login after native global logout',env['login']('reports0',env['real']))['access_token']
    revoke_report_access()
