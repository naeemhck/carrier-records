"""T06 real transactional RPC acceptance; invoked by empty-loopback t03 harness."""
import copy, json, uuid, sys, subprocess
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc, request, sql, ok = [env[k] for k in ('rpc','request','sql','ok')]
    b, at, offices = [env[k] for k in ('b','at','office')]
    uid=lambda:str(uuid.uuid4())
    def success(name,result):
        if result[0]!=200: raise AssertionError(f'{name}: {result}')
        ok(name,True);return result[1]
    tokens={}; accounts={}
    for name in ['lifecycle','dispatcher','arrivalpeer']:
        assigned=offices[1] if name=='arrivalpeer' else offices[0]
        account=success('T06 managed synthetic '+name,env['edge']({'action':'create','username':name,'display_name':'Synthetic '+name,'role':'STAFF','office_ids':[assigned],'password':env['password']},at))
        accounts[name]=account
        env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{account['id']}';"))
        auth=success('T06 temporary login',env['login'](name));env['change'](auth['access_token'])
        tokens[name]=success('T06 ready login',env['login'](name,env['real']))['access_token']
    for name in ['destination','outside']:
        tokens[name]=success('T06 existing scope login',env['login'](name,env['real']))['access_token']
    st,dt,xt,peer=tokens['lifecycle'],tokens['destination'],tokens['outside'],tokens['dispatcher']
    def master(kind,payload): return success('T06 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':payload},at))
    parties=[]
    for name,roles in [('owner',['OWNER','DRIVER']),('customer1',['CUSTOMER']),('customer2',['CUSTOMER']),('cancelled',['CUSTOMER']),('broker',['BROKER'])]:
        parties.append(master('PARTY',{'code':'T06-'+name,'display_name':'Synthetic '+name,'roles':roles,'contact_details':{},'archived':False}))
    owner,c1,c2,cancelled,broker=parties
    vehicle=master('VEHICLE',{'registration':'T06-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':owner['id'],'archived':False})
    def body(empty=False):
        stops=[{'id':uid(),'kind':k,'address':'Synthetic '+k} for k in ['PICKUP','DROP']]
        cs=[{'id':uid(),'customer_id':c['id'],'broker_id':broker['id'],'car_count':n,'quoted_amount':q,'quote_mode':mode,'commission_method':method,'commission_value':v,
             'pickup_stop_id':stops[0]['id'],'drop_stop_id':stops[1]['id'],'notes':'Synthetic consignment','cars':[{'id':uid(),'identifier':'Synthetic '+str(i)} for i in range(n-1)]}
            for c,n,q,mode,method,v in [(c1,3,'100000.00','DEDUCTED','PERCENTAGE','5.00'),(c2,2,'1234.56','ADDED','FIXED','10.01'),(cancelled,1,'200.00','DEDUCTED','FIXED','0.00')]]
        return {'vehicle_id':vehicle['id'],'driver_id':owner['id'],'origin_office_id':offices[0],'destination_office_id':offices[1],'route_id':None,'planned_dispatch_date':'2026-01-29','load_kind':'EMPTY' if empty else 'LOADED','return_of_trip_id':None,'notes':'T06 synthetic','reason':'Synthetic entry','stops':[] if empty else stops,'consignments':[] if empty else cs}
    def create(empty=False):
        p=body(empty);target=uid()
        w=success('T06 draft overlap review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':offices[0],'destination_office_id':offices[1],'planned_dispatch_date':p['planned_dispatch_date'],'return_of_trip_id':None},st))
        p.update(review_token=w['review_token'],overlap_confirmed=w['requires_confirmation'],overlap_reason='Synthetic draft overlap reviewed' if w['requires_confirmation'] else None)
        return success('T06 save draft',rpc('save_trip',{'target_id':target,'request_id':uid(),'expected_version':0,'payload':p},st)),p
    def get(t,token=st): return rpc('get_trip_detail',{'trip_id':t['id']},token)
    def command(action,t,payload,token=st,rid=None,version=None):
        name='dispatch_trip' if action=='DISPATCH' else 'arrive_trip' if action=='ARRIVE' else 'correct_trip_operation'
        args={'target_id':t['id'],'request_id':rid or uid(),'expected_version':t['version'] if version is None else version,'payload':payload}
        if name=='correct_trip_operation':args['action']=action
        return rpc(name,args,token)
    def review(t,date='2026-01-30',token=st):
        return success('T06 server overlap review',rpc('review_trip_overlap',{'target_id':t['id'],'vehicle_id':vehicle['id'],'origin_office_id':offices[0],'destination_office_id':offices[1],'planned_dispatch_date':date,'return_of_trip_id':t['return_of_trip_id']},token))
    def dispatch_payload(t,date='2026-01-30',token=st):
        w=review(t,date,token)
        return {'dispatch_date':date,'reason':'Recorded synthetic actual dispatch','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic overlap reviewed' if w['requires_confirmation'] else None}
    def ledger(t): return sql(f"select coalesce(jsonb_object_agg(purpose,amount),'{{}}') from (select account_purpose purpose,sum(signed_amount)::numeric(20,2)::text amount from public.journal_lines where trip_id='{t['id']}' group by account_purpose)x;")
    t,p=create(); cancelled_id=p['consignments'][2]['id']
    ok('AT-12 origin lifecycle controls',t['can_dispatch'] and not t['can_arrive'])
    ok('AT-12 destination read-only fare/draft controls',not get(t,dt)[1]['can_edit'] and not get(t,dt)[1]['can_dispatch'])
    for token in [dt,xt,peer,None]:
        ok('AT-12/15 denied unauthorized/other-creator draft cancellation',command('CANCEL_CONSIGNMENT',t,{'consignment_id':cancelled_id,'reason':'Bypass'},token)[0] in (401,403))
    t=success('AT-08 cancel one draft consignment',command('CANCEL_CONSIGNMENT',t,{'consignment_id':cancelled_id,'reason':'Load withdrawn before dispatch'}))
    ok('AT-08 cancelled quote excluded, evidence retained',len(t['consignments'])==3 and t['totals']['customer_charge']=='101244.57' and next(c for c in t['consignments'] if c['id']==cancelled_id)['state']=='CANCELLED')
    edit_args={'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p}
    changed=copy.deepcopy(p);changed['consignments']=changed['consignments'][:2]
    ok('AT-08 draft save cannot remove cancelled evidence',rpc('save_trip',dict(edit_args,payload=changed),st)[1].get('message')=='CANCELLED_CONSIGNMENT_RETAINED')
    changed=copy.deepcopy(p);changed['consignments'][2]['quoted_amount']='999.00'
    ok('AT-08 draft save cannot rewrite cancelled agreed fare',rpc('save_trip',dict(edit_args,request_id=uid(),payload=changed),st)[1].get('message')=='CANCELLED_CONSIGNMENT_RETAINED')
    ok('AT-08 rejected cancelled edits roll back aggregate version',get(t)[1]['version']==t['version'])
    ok('AT-07 planned draft posts no earnings',sql(f"select count(*) from public.financial_events where trip_id='{t['id']}';")=='0' and not t['earnings_recognized'])
    for token in [dt,xt,None]:ok('AT-12 destination/outside/anonymous cannot dispatch',command('DISPATCH',t,{'dispatch_date':'2026-01-30','reason':'Bypass'},token)[0] in (401,403))
    for payload in [{'dispatch_date':None,'reason':'Missing'},{'dispatch_date':'2026-02-30','reason':'Invalid'},{'dispatch_date':'2026-01-30','reason':''},{'dispatch_date':'2026-01-30','reason':'Inject','actor_id':accounts['dispatcher']['id']},{'dispatch_date':'2026-01-30','reason':'Inject','advance_applications':[]}]:
        ok('T06 invalid date/reason/actor/unsupported advance fields rejected',command('DISPATCH',t,payload)[0]==400)
    ok('T06 arrival before dispatch rejected',command('ARRIVE',t,{'arrival_date':'2026-02-02','reason':'Invalid'},dt)[0]==400)
    dp=dispatch_payload(t,token=peer);rid=uid()
    original=t
    t=success('AT-07/12 origin colleague dispatches reviewed draft',command('DISPATCH',t,dp,peer,rid))
    ok('AT-07 actual dispatch recognized atomically',t['state']=='DISPATCHED' and t['dispatch_date']=='2026-01-30' and t['planned_dispatch_date']=='2026-01-29' and t['earnings_recognized'])
    ok('T06 dispatch retry returns one committed result',command('DISPATCH',original,dp,peer,rid)==(200,t))
    ok('T06 changed retry rejected',command('DISPATCH',original,dict(dp,reason='Changed'),peer,rid)[0]==409)
    ok('T06 exactly two active consignment dispatch events',sql(f"select count(*) from public.financial_events where trip_id='{t['id']}' and kind='DISPATCH';")=='2')
    ok('T06 every dispatch journal balanced',sql(f"select count(*) from(select event_id from public.journal_lines where trip_id='{t['id']}' group by event_id having sum(signed_amount)<>0)x;")=='0')
    balances=ledger(t)
    ok('T06 exact debt/owner/broker recognition split',json.loads(balances)=={'CUSTOMER_RECEIVABLE':'101244.57','OWNER_PAYABLE':'-96234.56','BROKER_COMMISSION_PAYABLE':'-5010.01'})
    events_before=sql(f"select jsonb_agg(to_jsonb(e) order by id) from public.financial_events e where trip_id='{t['id']}';")
    for token in [st,xt,None]:ok('AT-12 origin/outside/anonymous cannot arrive',command('ARRIVE',t,{'arrival_date':'2026-02-02','reason':'Bypass'},token)[0] in (401,403))
    for d in [None,'2026-01-29','2026-02-30']:
        ok('T06 missing/early/impossible arrival date rejected',command('ARRIVE',t,{'arrival_date':d,'reason':'Invalid'},dt)[0]==400)
    ok('AT-12 direct cross-office fare edit denied',rpc('save_trip',{'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p},dt)[0]==403)
    ok('AT-15 confirmed fare cannot use draft edits',rpc('save_trip',{'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p},st)[0]==400)
    arrived=success('AT-08 destination arrival',command('ARRIVE',t,{'arrival_date':'2026-02-02','reason':'Recorded actual arrival'},dt))
    ok('AT-08 active delivered, cancelled stays cancelled',arrived['state']=='ARRIVED' and {c['id']:c['state'] for c in arrived['consignments']}=={p['consignments'][0]['id']:'DELIVERED',p['consignments'][1]['id']:'DELIVERED',cancelled_id:'CANCELLED'})
    ok('AT-08 all stops/counts/car IDs and prices preserved',arrived['stops']==t['stops'] and arrived['totals']==t['totals'] and all(c['cars']==next(a for a in t['consignments'] if a['id']==c['id'])['cars'] for c in arrived['consignments']))
    ok('Arrival leaves customer/owner/broker balances byte-equivalent',ledger(arrived)==balances)
    ok('Arrival creates no receipt, settlement or financial event',events_before==sql(f"select jsonb_agg(to_jsonb(e) order by id) from public.financial_events e where trip_id='{t['id']}';"))
    ok('Arrival cannot repeat as a fresh transition',command('ARRIVE',arrived,{'arrival_date':'2026-02-03','reason':'Repeated'},dt)[0]==400)
    ok('AT-15 trip creator cannot correct colleague dispatch date',command('CORRECT_DISPATCH_DATE',arrived,{'dispatch_date':'2026-01-31','reason':'Bypass'},st)[0]==403)
    ok('AT-15 other destination creator cannot correct arrival',command('CORRECT_ARRIVAL_DATE',arrived,{'arrival_date':'2026-02-03','reason':'Bypass'},tokens['arrivalpeer'])[0]==403)
    ok('AT-15 arrival creator needs current destination permission',command('CORRECT_ARRIVAL_DATE',arrived,{'arrival_date':'2026-02-03','reason':'Bypass'},peer)[0]==403)
    arrived=success('AT-15 arrival creator correction',command('CORRECT_ARRIVAL_DATE',arrived,{'arrival_date':'2026-02-03','reason':'Corrected destination date'},dt))
    ok('Arrival date correction leaves money untouched',ledger(arrived)==balances)
    ok('AT-15 colleague cannot correct trip creator notes',command('CORRECT_OPERATION',arrived,{'notes':'Bypass','reason':'Bypass'},peer)[0]==403)
    arrived=success('AT-15 own operational correction',command('CORRECT_OPERATION',arrived,{'notes':'Audited correction','reason':'Corrected trip note'}))
    ok('Operational edit cannot inject fare/date/state/owner',all(command('CORRECT_OPERATION',arrived,dict(notes='Bypass',reason='Bypass',**{k:v}))[0]==400 for k,v in [('quoted_amount','1.00'),('dispatch_date','2026-02-01'),('state','DRAFT'),('owner_id',c1['id'])]))
    old_events=events_before
    original=arrived;correction={'dispatch_date':'2026-02-01','reason':'Corrected actual departure month'};rid=uid()
    arrived=success('AT-07/15 append dispatch date reversal/replacement',command('CORRECT_DISPATCH_DATE',arrived,correction,peer,rid))
    ok('AT-15 corrected date retry creates no extra postings',command('CORRECT_DISPATCH_DATE',original,correction,peer,rid)==(200,arrived))
    ok('AT-15 original dispatch event data immutable',old_events==sql(f"select jsonb_agg(to_jsonb(e) order by id) from public.financial_events e where trip_id='{t['id']}' and kind='DISPATCH';"))
    ok('AT-15 one exact reversal and replacement per source',sql(f"select jsonb_build_array(count(*) filter(where kind='REVERSAL'),count(*) filter(where kind='REPLACEMENT')) from public.financial_events where trip_id='{t['id']}';")=='[2, 2]')
    ok('AT-07 historical monthly earnings move with correction',sql(f"select jsonb_object_agg(period_key,amount) from(select to_char(e.effective_date,'YYYY-MM') AS period_key,sum(l.signed_amount)::numeric(20,2)::text amount from public.financial_events e join public.journal_lines l on l.event_id=e.id where e.trip_id='{t['id']}' and l.account_purpose='OWNER_PAYABLE' group by 1)x;")=='{"2026-01": "0.00", "2026-02": "-96234.56"}')
    ok('AT-07 correction changes date basis, not lifetime owner debt',ledger(arrived)==balances)
    ok('T06 dispatch cannot be corrected beyond arrival',command('CORRECT_DISPATCH_DATE',arrived,{'dispatch_date':'2026-02-04','reason':'Invalid'},peer)[0]==400)
    with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(lambda _:command('CORRECT_OPERATION',arrived,{'notes':'Concurrent correction','reason':'Concurrent'}),range(2)))
    ok('AT-15 concurrent edits one commit, one conflict',sorted(r[0] for r in results)==[200,409])
    arrived=next(r[1] for r in results if r[0]==200)
    history=success('T06 scoped audit history',rpc('get_trip_history',{'trip_id':t['id']},dt))['rows']
    ok('AT-07/15 history explains effective-date correction',any(h['action']=='CORRECT_DISPATCH_DATE' and h['before']['dispatch_date']=='2026-01-30' and h['after']['dispatch_date']=='2026-02-01' and h['reason']==correction['reason'] and h['actor_name']=='Synthetic dispatcher' for h in history))
    ok('T06 history has no Auth/business/request IDs or hidden snapshots',all(set(h)=={'action','actor_name','recorded_at','reason','before','after'} and not any(k in h['after'] for k in ['business_id','created_by','linked_returns','owner_snapshot']) for h in history))
    ok('T06 outside/anonymous audit history denied',rpc('get_trip_history',{'trip_id':t['id']},xt)[0]==403 and rpc('get_trip_history',{'trip_id':t['id']})[0] in (401,403))
    # A dependent financial fixture must block corrections without altering history.
    dependency=uid()
    sql(f"insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,amount,request_id) values('{dependency}','{b}','CUSTOMER_RECEIPT','2026-03-05','{env['ap']['id']}','{offices[0]}','{vehicle['id']}','{t['id']}',0,'{uid()}');")
    ok('AT-15 dependent receipt blocks date repost',command('CORRECT_DISPATCH_DATE',arrived,{'dispatch_date':'2026-01-31','reason':'Would affect dependent receipt'},peer)[1].get('message')=='DEPENDENT_SETTLEMENTS')
    ok('AT-07 receipt fixture retains independent March effective date',sql(f"select effective_date from public.financial_events where id='{dependency}';")=='2026-03-05')
    ok('T06 confirmed cancellation requires later financial adjustment',command('CANCEL_DRAFT',arrived,{'reason':'Cannot silently erase earnings'})[1].get('message')=='FINANCIAL_ADJUSTMENT_REQUIRED')
    # Deferred commit failure proves no state/audit/retry success can survive it.
    rollback,_=create(empty=True);dp=dispatch_payload(rollback)
    sql("create function public.t06_fail_commit() returns trigger language plpgsql as $$ begin raise exception 'T06_INJECTED_COMMIT_FAILURE'; end $$;create constraint trigger t06_commit_failure after insert on public.financial_events deferrable initially deferred for each row execute function public.t06_fail_commit();")
    # Empty dispatch intentionally has no journal: use a loaded draft for this case.
    rollback,p2=create();dp=dispatch_payload(rollback);rid=uid()
    try:
        failed=command('DISPATCH',rollback,dp,rid=rid)
        ok('T06 deferred commit failure is an HTTP failure',failed[0]>=400 and failed[1].get('message')=='T06_INJECTED_COMMIT_FAILURE')
        ok('T06 failed posting rolls back state, journal, batch, audit and retry',get(rollback)[1]['state']=='DRAFT' and sql(f"select (select count(*) from public.financial_events where trip_id='{rollback['id']}')+(select count(*) from private.trip_recognition where trip_id='{rollback['id']}')+(select count(*) from public.audit_events where trip_id='{rollback['id']}' and action='DISPATCH')+(select count(*) from private.lifecycle_requests where request_id='{rid}');")=='0')
    finally:sql('drop trigger t06_commit_failure on public.financial_events;drop function public.t06_fail_commit();')
    rolled=success('T06 same request succeeds once after commit failure removed',command('DISPATCH',rollback,dp,rid=rid))
    # The first review must become stale after another trip dispatches.
    first,_=create(empty=True);second,_=create(empty=True)
    pfirst=dispatch_payload(first);psecond=dispatch_payload(second)
    first=success('T06 empty dispatch creates no fare',command('DISPATCH',first,pfirst))
    ok('T06 empty dispatch has recognition marker but no financial events',first['earnings_recognized'] and first['totals']['customer_charge']=='0.00' and sql(f"select count(*) from public.financial_events where trip_id='{first['id']}';")=='0')
    ok('T06 second dispatch cannot reuse pre-dispatch overlap review',command('DISPATCH',second,psecond)[0]==409)
    ok('T06 acknowledged draft flag alone cannot dispatch overlap',command('DISPATCH',second,{'dispatch_date':'2026-01-30','reason':'Bypass','overlap_confirmed':True,'overlap_reason':'Unreviewed'})[0]==400)
    second=success('T06 refreshed reviewed overlap dispatch',command('DISPATCH',second,dispatch_payload(second)))
    with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(lambda _:command('ARRIVE',second,{'arrival_date':'2026-02-02','reason':'Concurrent arrival'},dt),range(2)))
    ok('AT-08/15 concurrent arrival one commit one conflict',sorted(r[0] for r in results)==[200,409])
    draft,_=create(empty=True);draft=success('T06 draft cancellation retains record',command('CANCEL_DRAFT',draft,{'reason':'Draft withdrawn'}))
    ok('T06 cancelled draft has no actual dates or financial success',draft['state']=='CANCELLED' and draft['dispatch_date'] is None and not draft['earnings_recognized'])
    ok('T06 cancelled draft cannot dispatch',command('DISPATCH',draft,{'dispatch_date':'2026-01-30','reason':'Invalid'})[0]==400)
    # Current office permissions, even for the operation creator, remain live.
    profile=env['profile'](peer)
    success('T06 revoke dispatcher origin assignment',rpc('admin_manage_staff',{'target_id':profile['id'],'expected_version':profile['version'],'display_name':profile['display_name'],'account_role':'STAFF','active':True,'office_ids':[offices[2]]},at))
    ok('AT-15 revoked creator JWT cannot correct own dispatch',command('CORRECT_DISPATCH_DATE',arrived,{'dispatch_date':'2026-01-31','reason':'Bypass'},peer)[0]==403)
    admin_result=success('AT-15 administrator corrects another creator notes',command('CORRECT_OPERATION',arrived,{'notes':'Admin verified correction','reason':'Administrator correction'},at))
    ok('T06 null expected version rejected',rpc('arrive_trip',{'target_id':first['id'],'request_id':uid(),'expected_version':None,'payload':{'arrival_date':'2026-02-02','reason':'Invalid'}},dt)[0]==400)
    if '--lifecycle-native' in sys.argv:
        native,_=create();native=success('T06 native cancelled consignment fixture',command('CANCEL_CONSIGNMENT',native,{'consignment_id':next(c['id'] for c in native['consignments'] if c['customer_id']==cancelled['id']),'reason':'Native synthetic load withdrawn'}))
        cfg=env['ROOT']/'tools/.local/t06-native-config.json'
        cfg.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'lifecycle','TEST_DESTINATION_USERNAME':'destination','TEST_PASSWORD':env['real'],'TEST_TRIP_ID':native['id']}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t06-native.log').open('w',encoding='utf-8') as log:
                built=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/trip_lifecycle_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(cfg)],cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('T06 native committed dispatch, destination arrival and history',built.returncode==0)
            result=get(native,at)[1]
            ok('T06 native persisted arrival preserves cancelled consignment',result['state']=='ARRIVED' and [c['state'] for c in result['consignments']].count('DELIVERED')==2 and [c['state'] for c in result['consignments']].count('CANCELLED')==1)
        finally:cfg.unlink(missing_ok=True)
    print('T06 lifecycle acceptance PASS; full allocation/settlement/expense/report and dependent correction workflows remain later tasks.',flush=True)
