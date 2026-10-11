"""Real T10 receipts, immutable claim kernel and transactional race checks."""
import base64, copy, json, uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,offices=env['b'],env['at'],env['office']
    uid=lambda:str(uuid.uuid4())
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    user=success('T10 managed origin staff',env['edge']({'action':'create','username':'corrections','display_name':'Synthetic finance','role':'STAFF','office_ids':[offices[0]],'password':env['password']},at))
    env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{user['id']}';"))
    temp=success('T10 temporary login',env['login']('corrections'));env['change'](temp['access_token'])
    st=success('T10 ready login',env['login']('corrections',env['real']))['access_token']
    dt=success('T10 destination login',env['login']('destination',env['real']))['access_token']
    xt=success('T10 unrelated login',env['login']('outside',env['real']))['access_token']
    def master(kind,p):return success('T10 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    parties=[master('PARTY',{'code':'T10-'+name,'display_name':'Synthetic '+name,'roles':[role],'contact_details':{},'archived':False}) for name,role in [('owner','OWNER'),('customer','CUSTOMER'),('other','CUSTOMER'),('broker','BROKER')]]
    owner,customer,other,broker=parties
    vehicle=master('VEHICLE',{'registration':'T10-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False})
    def draft(mode='DEDUCTED',q='100000.00',c='5000.00',origin=0,dest=1):
        target=uid();w=success('T10 draft review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':offices[origin],'destination_office_id':offices[dest]},at))
        p={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':offices[origin],'destination_office_id':offices[dest],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic T10','reason':'Synthetic entry','stops':[],
           'consignments':[{'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':1,'quoted_amount':q,'quote_mode':mode,'commission_method':'FIXED','commission_value':c,'notes':'','cars':[]}],
           'review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed overlap' if w['requires_confirmation'] else None}
        return success('T10 save draft',rpc('save_trip',{'target_id':target,'request_id':uid(),'expected_version':0,'payload':p},at))
    def dispatch(t):
        w=success('T10 actual dispatch review',rpc('review_trip_overlap',{'target_id':t['id'],'vehicle_id':vehicle['id'],'origin_office_id':t['origin_office_id'],'destination_office_id':t['destination_office_id'],'planned_dispatch_date':'2026-01-30'},at))
        p={'dispatch_date':'2026-01-30','reason':'Synthetic dispatch','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed dispatch' if w['requires_confirmation'] else None}
        args={'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p}
        result=success('T10 existing atomic dispatch',rpc('dispatch_trip',args,at))
        ok('AT-16 dispatch retry does not duplicate earnings',rpc('dispatch_trip',args,at)==(200,result) and sql(f"select count(*) from public.financial_events where trip_id='{t['id']}' and kind='DISPATCH';")=='1')
        return result
    def ledger(t,token=st):return rpc('get_trip_financials',{'trip_id':t['id']},token)
    def claim(t,purpose,party=None):return next(x for x in ledger(t,at)[1]['claims'] if x['account_purpose']==purpose and (party is None or x['party_id']==party))
    def alloc(c,amount,source=None):
        a={'target_line_id':c['line_id'],'target_version':c['version'],'amount':amount}
        if source:a.update(source_line_id=source['line_id'],source_version=source['version'])
        return a
    def payload(amount,allocations,payer=customer['id'],payee=broker['id'],office=0):return {'payer_id':payer,'payee_id':payee,'office_id':offices[office],'effective_date':'2026-03-05','amount':amount,'reason':'Synthetic reviewed movement','allocations':allocations}
    def post(p,token=st,rid=None,kind='CUSTOMER_RECEIPT',version=0):return rpc('post_financial_event',{'event_kind':kind,'request_id':rid or uid(),'expected_version':version,'payload':p},token)
    def balances(t):
        from decimal import Decimal
        totals={}
        for x in ledger(t,at)[1]['balances']:totals[x['account_purpose']]=totals.get(x['account_purpose'],Decimal(0))+Decimal(x['balance'])
        return {k:format(v,'.2f') for k,v in totals.items()}
    def movement(kind,p,token=st,rid=None):return success('T10 '+kind,post(p,token,rid,kind))
    import base64,copy,hashlib
    from decimal import Decimal
    category=master('CATEGORY',{'name':'T10 Diesel and maintenance','archived':False})
    def ea(c,amount,component='OFFSET'):return {'line_id':c['line_id'],'version':c['version'],'amount':amount,'component':component}
    def ep(t=None,funding='SELF_FUNDED_COST',payer=None,bearer=None,amount='10000.00',allocations=None,office=0):return {'vehicle_id':vehicle['id'],'trip_id':t['id'] if t else None,'office_id':offices[office],'category_id':category['id'],'effective_date':'2026-03-05','amount':amount,'payer_id':payer or owner['id'],'cost_bearer_id':bearer or owner['id'],'funding_source':funding,'reason':'Synthetic T10 expense','allocations':allocations or [],'offset_confirmed':True}
    def expense(p,token=st,rid=None):return post(p,token,rid,kind='EXPENSE')
    def costs(t=None,month=True,token=at):return rpc('get_expense_totals',{'vehicle_id':vehicle['id'],'from_date':'2026-03-01','to_date':'2026-03-31','trip_id':t['id'] if t else None},token)
    def collect(t):return movement('CUSTOMER_RECEIPT',payload('100000.00',[alloc(claim(t,'CUSTOMER_RECEIVABLE'),'100000.00')]))
    def event(result):return result.get('event_id',result['record_id'])
    def review(e,token=st):return rpc('review_financial_correction',{'event_id':e},token)
    def correction(e,replacement=None,unwind=None,token=st,rid=None,r=None):
        r=r or success('T10 correction review',review(e,token))
        return rpc('correct_financial_event',{'event_id':e,'request_id':rid or uid(),'expected_version':1,'payload':{'reason':'Synthetic reviewed correction','review_token':r['review_token'],'unwind_event_ids':unwind or [],'replacement':replacement}},token)
    a=dispatch(draft());recv=movement('CUSTOMER_RECEIPT',payload('60000.00',[alloc(claim(a,'CUSTOMER_RECEIVABLE'),'60000.00')]))
    eid=event(recv);original=sql(f"select row_to_json(e)::text from public.financial_events e where id='{eid}';")
    ok('AT15 unrelated/destination creator correction denied',review(eid,dt)[0]==403 and review(eid,xt)[0]==403)
    r=success('T10 root review',review(eid));rid=uid();result=success('T10 original receipt reversed',correction(eid,rid=rid,r=r))
    ok('AT15 same reversal retry original result',correction(eid,rid=rid,r=r)==(200,result))
    ok('AT21 second reversal rejected',correction(eid)[0]==409)
    ok('AT15 source immutable and balances restored',original==sql(f"select row_to_json(e)::text from public.financial_events e where id='{eid}';") and balances(a)['CUSTOMER_RECEIVABLE']=='100000.00' and balances(a)['CUSTODY_RECEIVABLE']=='0.00')
    # Dependency plans must explicitly unwind actual settlements first.
    a=dispatch(draft());recv=collect(a);eid=event(recv)
    settle=movement('OWNER_SETTLEMENT',payload('50000.00',[alloc(claim(a,'OWNER_PAYABLE'),'50000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
    ok('AT15 dependent settlement cannot disappear implicitly',correction(eid)[0]==400)
    r=success('T10 explicit dependent review',review(eid));rid=uid();cr=success('T10 atomic settlement unwind then receipt reversal',correction(eid,unwind=[event(settle)],rid=rid,r=r))
    ok('AT15 dependency retry returns committed plan',correction(eid,unwind=[event(settle)],rid=rid,r=r)==(200,cr))
    ok('AT15 source and target restored once',balances(a)['CUSTOMER_RECEIVABLE']=='100000.00' and balances(a)['OWNER_PAYABLE']=='-95000.00' and balances(a)['CUSTODY_RECEIVABLE']=='0.00')
    held=dispatch(draft());recv=collect(held)
    hp=ep(held,'HELD_TRIP_FUNDS',broker['id'],allocations=[ea(claim(held,'OWNER_PAYABLE'),'10000.00'),ea(claim(held,'CUSTODY_RECEIVABLE'),'10000.00','CASH')])
    he=success('T10 actual held-funds expense dependency',expense(hp))
    ok('AT21 financial source cannot silently unwind actual dependent expense',correction(event(recv),unwind=[event(he)])[0]==400)
    success('AT15 independently reviewed erroneous expense void',correction(event(he)))
    success('AT15 funding source corrected only after expense explicit void',correction(event(recv)))
    ok('AT21 original held expense preserved with effective void',sql(f"select count(*) from public.expenses where id='{he['record_id']}';")=='1' and costs(held)[1]['vehicle_cost']=='0.00')
    # Receipt replacement uses exact restored versions, on the corrected date.
    a=dispatch(draft());c=claim(a,'CUSTOMER_RECEIVABLE');recv=movement('CUSTOMER_RECEIPT',payload('60000.00',[alloc(c,'60000.00')]))
    cp=payload('55000.00',[alloc(claim(a,'CUSTOMER_RECEIVABLE'),'55000.00')]);cp['effective_date']='2026-02-10'
    repl=correction(event(recv),replacement=cp)
    if repl[0]!=200:raise AssertionError(f'replacement: {repl}')
    ok('AT07 linked replacement February effective date',sql(f"select effective_date::text from public.financial_events where replacement_of_id='{event(recv)}';")=='2026-02-10')
    ok('AT07 March receipt cancelled February receipt55000 debt45000',balances(a)['CUSTOMER_RECEIVABLE']=='45000.00' and balances(a)['CUSTODY_RECEIVABLE']=='55000.00')
    # Independent actual expense correction, preserving the original record.
    ex=success('T10 standalone actual expense',expense(ep(amount='2500.00')));ee=event(ex)
    exid=ex['record_id'];success('T10 expense void',correction(ee))
    ok('AT21 original expense retained and effective cost excluded',sql(f"select count(*) from public.expenses where id='{exid}';")=='1' and costs()[1]['vehicle_cost']=='0.00')
    # Cancellation leaves actual money in place and creates identified claims.
    a=dispatch(draft());collect(a)
    movement('OWNER_SETTLEMENT',payload('95000.00',[alloc(claim(a,'OWNER_PAYABLE'),'95000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
    movement('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(claim(a,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
    ex=success('T10 incurred diesel retained',expense(ep(a)))
    def cancel(t,fee='10000.00',commission='1000.00',token=at,rid=None,r=None):
        r=r or success('T10 cancellation review',rpc('review_cancellation',{'trip_id':t['id']},token))
        cons=json.loads(sql(f"select jsonb_agg(id)::text from public.consignments where trip_id='{t['id']}';"))
        return rpc('cancel_and_adjust',{'trip_id':t['id'],'request_id':rid or uid(),'expected_version':t['version'],'payload':{'reason':'Synthetic agreed cancellation fee','review_token':r['review_token'],'effective_date':'2026-04-01','consignments':[{'id':i,'quoted_amount':fee,'quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':commission} for i in cons]}},token)
    ok('AT15 destination cannot cancel origin trip',rpc('review_cancellation',{'trip_id':a['id']},dt)[0]==403)
    r=success('T10 cancellation snapshot',rpc('review_cancellation',{'trip_id':a['id']},at));rid=uid();res=success('AT21 cancellation after all actual settlements',cancel(a,rid=rid,r=r))
    ok('AT21 cancellation retry once',cancel(a,rid=rid,r=r)==(200,res))
    bs=balances(a)
    ok('AT21 fee10000 credit90000 owner recovery86000 broker recovery4000',bs['CUSTOMER_ADVANCE_CREDIT']=='-90000.00' and bs['OWNER_PAYABLE']=='86000.00' and bs['BROKER_COMMISSION_PAYABLE']=='4000.00' and bs['CUSTODY_RECEIVABLE']=='0.00')
    ok('AT21 actual diesel not erased and no automatic refund',costs(a)[1]['vehicle_cost']=='10000.00' and sql(f"select count(*) from public.financial_events where trip_id='{a['id']}' and kind='REFUND';")=='0')
    ok('AT21 cancelled load preserved',sql(f"select state from public.consignments where trip_id='{a['id']}';")=='CANCELLED')
    ok('AT21 unbacked refund cannot use nonexistent custody',not any(c['account_purpose']=='CUSTODY_RECEIVABLE' for c in ledger(a,at)[1]['claims']))
    # Recover actual overpaid entitlements before a separately funded refund.
    owner_recovery=claim(a,'OWNER_PAYABLE',owner['id']);broker_recovery=claim(a,'BROKER_COMMISSION_PAYABLE',broker['id'])
    rp=payload('86000.00',[alloc(owner_recovery,'86000.00')],owner['id'],broker['id']);rp['effective_date']='2026-04-02';rrid=uid()
    rr=movement('RECOVERY_RECEIPT',rp,rid=rrid)
    ok('AT21 owner recovery repeated retry once',post(rp,rid=rrid,kind='RECOVERY_RECEIPT')==(200,rr))
    ok('AT21 recovery claim cannot consume twice',post(rp,kind='RECOVERY_RECEIPT')[0]==409)
    brp=payload('4000.00',[alloc(broker_recovery,'4000.00')],broker['id'],broker['id']);brp['effective_date']='2026-04-02';brec=movement('RECOVERY_RECEIPT',brp)
    credit=claim(a,'CUSTOMER_ADVANCE_CREDIT');sources=[c for c in ledger(a,at)[1]['claims'] if c['account_purpose']=='CUSTODY_RECEIVABLE']
    fp=payload('90000.00',[alloc(credit,c['remaining'],c) for c in sources],broker['id'],customer['id'])
    fp['effective_date']='2026-04-03';refund=movement('REFUND',fp)
    ok('AT21 actual funded refund separately closes credit recoveries custody',all(v=='0.00' for v in balances(a).values()) and costs(a)[1]['vehicle_cost']=='10000.00')
    ok('AT21 duplicate refund claim consumption denied',post(fp,kind='REFUND')[0]==409)
    ok('AT21 no correction can silently invalidate a cancelled trip plan',correction(event(refund),token=at)[0]==400)
    # Partial cancellation: applied customer payment becomes identified credit;
    # uncollected earnings close while physical custody remains available.
    partial=dispatch(draft());movement('CUSTOMER_RECEIPT',payload('20000.00',[alloc(claim(partial,'CUSTOMER_RECEIVABLE'),'20000.00')]))
    success('AT21 partial cancellation with fee split',cancel(partial))
    pbs=balances(partial)
    ok('AT21 partial credit10000 held20000 owner9000 broker1000',pbs['CUSTOMER_ADVANCE_CREDIT']=='-10000.00' and pbs['CUSTODY_RECEIVABLE']=='20000.00' and pbs['OWNER_PAYABLE']=='-9000.00' and pbs['BROKER_COMMISSION_PAYABLE']=='-1000.00')
    partial_adjustment=sql(f"select id from public.financial_events where trip_id='{partial['id']}' and kind='ADJUSTMENT';")
    cq={'quoted_amount':'15000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'1500.00','effective_date':'2026-04-02'}
    success('AT15 cancellation fee corrected append-only',correction(partial_adjustment,cq,token=at))
    ok('AT21 fee replacement recomputes identified credit not cash',balances(partial)['CUSTOMER_ADVANCE_CREDIT']=='-5000.00' and balances(partial)['OWNER_PAYABLE']=='-13500.00' and balances(partial)['CUSTODY_RECEIVABLE']=='20000.00')
    final_adjustment=sql(f"select id from public.financial_events where trip_id='{a['id']}' and kind='ADJUSTMENT';")
    ok('AT15 settled cancellation correction needs explicit unwind',correction(final_adjustment,cq,token=at)[0]==400)
    success('AT15 explicit refund and recovery unwind then fee replacement',correction(final_adjustment,cq,unwind=[event(rr),event(brec),event(refund)],token=at))
    ok('AT21 revised recovery claims remain available on replacements',claim(a,'OWNER_PAYABLE',owner['id'])['remaining']=='81500.00' and claim(a,'BROKER_COMMISSION_PAYABLE',broker['id'])['remaining']=='3500.00' and claim(a,'CUSTOMER_ADVANCE_CREDIT')['remaining']=='85000.00' and costs(a)[1]['vehicle_cost']=='10000.00')
    # Creator fare corrections need origin rights and a complete explicit plan.
    fare=dispatch(draft());earnings=sql(f"select id from public.financial_events where trip_id='{fare['id']}' and kind='DISPATCH';")
    q={'quoted_amount':'120000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'6000.00','effective_date':'2026-01-30'}
    ok('AT15 destination fare correction directly denied',correction(earnings,q,token=dt,r={'review_token':'forged'})[0]==403)
    fq=success('AT07 admin fare linked correction January',correction(earnings,q,token=at))
    ok('AT07 historical January fare114000 commission6000 reconciled',balances(fare)['CUSTOMER_RECEIVABLE']=='120000.00' and balances(fare)['OWNER_PAYABLE']=='-114000.00' and balances(fare)['BROKER_COMMISSION_PAYABLE']=='-6000.00')
    ok('AT15 original fare before-after audited',sql(f"select count(*) from public.audit_events where trip_id='{fare['id']}' and action='CORRECT_FARE' and reason is not null;")=='1')
    # Real concurrent clients: one original reversal, including ambiguous retries.
    race=dispatch(draft());recv=movement('CUSTOMER_RECEIPT',payload('1000.00',[alloc(claim(race,'CUSTOMER_RECEIVABLE'),'1000.00')]))
    r=success('T10 race snapshot',review(event(recv)));rid=uid()
    with ThreadPoolExecutor(2) as pool:results=list(pool.map(lambda _:correction(event(recv),rid=rid,r=r),range(2)))
    ok('AT15 same UUID concurrent reversal one event',results[0]==results[1] and results[0][0]==200 and sql(f"select count(*) from public.financial_events where reversal_of_id='{event(recv)}';")=='1')
    recv=movement('CUSTOMER_RECEIPT',payload('1000.00',[alloc(claim(race,'CUSTOMER_RECEIVABLE'),'1000.00')]))
    r=success('T10 competing snapshot',review(event(recv)))
    with ThreadPoolExecutor(2) as pool:results=list(pool.map(lambda _:correction(event(recv),r=r),range(2)))
    ok('AT15 distinct UUID stale concurrent correction denied',sorted(x[0] for x in results)==[200,409])
    # A deferred commit failure must roll back journals, claims, audit and retry.
    recv=movement('CUSTOMER_RECEIPT',payload('1000.00',[alloc(claim(race,'CUSTOMER_RECEIVABLE'),'1000.00')]))
    eid=event(recv);r=success('T10 deferred snapshot',review(eid));rid=uid();before=balances(race)
    sql(f"create function public.t10_commit_failure() returns trigger language plpgsql as $$ begin if new.reversal_of_id='{eid}'::uuid then raise exception 'synthetic deferred failure' using errcode='23514';end if;return new;end $$;create constraint trigger t10_commit_failure after insert on public.financial_events deferrable initially deferred for each row execute function public.t10_commit_failure();")
    try:
        ok('T06 T10 no success before failing commit',correction(eid,rid=rid,r=r)[0]==400)
        ok('T06 T10 complete financial rollback',balances(race)==before and sql(f"select count(*) from public.financial_events where reversal_of_id='{eid}';")=='0' and sql(f"select count(*) from public.idempotency_records where request_id='{rid}';")=='0')
    finally:sql('drop trigger t10_commit_failure on public.financial_events;drop function public.t10_commit_failure();')
    success('T06 T10 original failed UUID safe retry',correction(eid,rid=rid,r=r))
    # Replacement costs preserve historical classification and evidence sources.
    ex=success('T10 expense replacement original',expense(ep(amount='2500.00')));ee=event(ex)
    raw=b'\x89PNG\r\n\x1a\nsynthetic-T10-evidence'
    evidence=success('T10 original expense private evidence',env['request']('/functions/v1/expense-receipts',{'expense_id':ex['record_id'],'request_id':uid(),'expected_version':1,'mime_type':'image/png','base64':base64.b64encode(raw).decode()},st))
    rp=ep(amount='3500.00');rp['effective_date']='2026-02-15'
    exr=success('AT07 expense February replacement',correction(ee,rp))
    replacement_id=exr['replacement']['record_id']
    ok('AT07 expense dates correct cost once old source retained',costs()[1]['vehicle_cost']=='10000.00' and sql(f"select amount::text||'/'||expense_date::text from public.expenses where replaces_expense_id='{ex['record_id']}';")=='3500.00/2026-02-15')
    ok('AT21 replacement preserves original evidence bytes',env['request']('/storage/v1/object/authenticated/receipts/'+evidence['object_path'],token=st,method='GET')==(200,raw))
    # Explicit personal refund financing creates a separate recoverable advance.
    funded=dispatch(draft());collect(funded)
    movement('OWNER_SETTLEMENT',payload('95000.00',[alloc(claim(funded,'OWNER_PAYABLE'),'95000.00',claim(funded,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
    movement('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(claim(funded,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(funded,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
    success('AT21 zero fee cancellation recovery funding',cancel(funded,'0.00','0.00'))
    credit=claim(funded,'CUSTOMER_ADVANCE_CREDIT');fundp=payload('100000.00',[alloc(credit,'100000.00')],other['id'],customer['id']);fundp['effective_date']='2026-04-02';fundrid=uid()
    fund=movement('REFUND_FUNDING',fundp,rid=fundrid)
    ok('AT21 personal refund funding retry once no customer claim consumption',post(fundp,rid=fundrid,kind='REFUND_FUNDING')==(200,fund) and claim(funded,'CUSTOMER_ADVANCE_CREDIT')['remaining']=='100000.00' and balances(funded)['TRIP_FUNDING_PAYABLE']=='-100000.00')
    fp=payload('100000.00',[alloc(credit,'100000.00',claim(funded,'CUSTODY_RECEIVABLE',other['id']))],other['id'],customer['id']);fp['effective_date']='2026-04-03';movement('REFUND',fp)
    ok('AT21 personally financed refund retains recovery and funding debt',balances(funded)['CUSTOMER_ADVANCE_CREDIT']=='0.00' and balances(funded)['TRIP_FUNDING_PAYABLE']=='-100000.00' and balances(funded)['OWNER_PAYABLE']=='95000.00')
    for purpose,party,n in [('OWNER_PAYABLE',owner['id'],'95000.00'),('BROKER_COMMISSION_PAYABLE',broker['id'],'5000.00')]:
        rp=payload(n,[alloc(claim(funded,purpose,party),n)],party,broker['id']);rp['effective_date']='2026-04-04';movement('RECOVERY_RECEIPT',rp)
    funding=claim(funded,'TRIP_FUNDING_PAYABLE',other['id']);sources=[x for x in ledger(funded,at)[1]['claims'] if x['account_purpose']=='CUSTODY_RECEIVABLE'];rp=payload('100000.00',[alloc(funding,c['remaining'],c) for c in sources],broker['id'],other['id']);rp['effective_date']='2026-04-05';movement('FUNDING_RECOVERY',rp)
    ok('AT21 actual recoveries repay personal refund funding separately',all(v=='0.00' for v in balances(funded).values()))
    import sys,subprocess
    if '--native-corrections' in sys.argv:
        config_path=env['ROOT']/'tools/.local/t10-native-config.json'
        latest_event=sql(f"select id from public.financial_events where expense_id='{replacement_id}' and kind='REPLACEMENT';")
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'corrections','TEST_PASSWORD':env['real'],'TEST_EVENT_ID':latest_event}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t10-native.log').open('w',encoding='utf-8') as log:
                built=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/corrections_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('T10 real Windows creator correction review commit UI',built.returncode==0)
            ok('T10 native persisted linked correction exact amount',sql(f"select x.amount::text||'/'||f.kind from public.expenses x join public.financial_events f on f.expense_id=x.id where x.replaces_expense_id='{replacement_id}';")=='3600.13/REPLACEMENT')
        finally:config_path.unlink(missing_ok=True)
        st=success('T10 post-native fresh creator session',env['login']('corrections',env['real']))['access_token']
    hist=success('T10 permitted scoped financial history',rpc('list_financial_history',{'trip_id':race['id']},st))
    ok('AT15 history contains source links and no private actor/request metadata',any(x['reversal_of_id'] for x in hist) and all('business_id' not in x and 'auth_user_id' not in x and 'request_id' not in x for x in hist))
    ok('AT15 unrelated history direct backend denied',rpc('list_financial_history',{'trip_id':race['id']},xt)[0]==403)
    ok('T10 client cannot forge correction capability',env['request']('/rest/v1/correction_context',{'transaction_id':1,'reason':'forged'},st)[0]>=400 and sql("select has_table_privilege('authenticated','private.correction_context','INSERT');")=='f')
    ok('T10 direct financial evidence deletion denied',env['request']('/rest/v1/expenses?id=eq.'+ex['record_id'],token=st,method='DELETE')[0]>=400)
    # Revocation applies to old URLs and same-ID cached correction results.
    p=env['profile'](st)
    success('T10 revoke creator office',rpc('admin_manage_staff',{'target_id':p['id'],'expected_version':p['version'],'display_name':p['display_name'],'account_role':'STAFF','active':True,'office_ids':[]},at))
    ok('AT15 revoked creator cannot retrieve correction retry',correction(eid,rid=rid,r=r)[0]==403)
    ok('T10 every event balanced',sql(f"select count(*) from(select event_id from public.journal_lines where business_id='{b}' group by event_id having sum(signed_amount)<>0) q;")=='0')
    ok('T10 capability never survives commit',sql('select count(*) from private.correction_context;')=='0')
