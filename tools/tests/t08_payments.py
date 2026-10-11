"""Real T08 receipts, immutable claim kernel and transactional race checks."""
import base64, copy, json, uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,offices=env['b'],env['at'],env['office']
    uid=lambda:str(uuid.uuid4())
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    user=success('T08 managed origin staff',env['edge']({'action':'create','username':'payments','display_name':'Synthetic finance','role':'STAFF','office_ids':[offices[0]],'password':env['password']},at))
    env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{user['id']}';"))
    temp=success('T08 temporary login',env['login']('payments'));env['change'](temp['access_token'])
    st=success('T08 ready login',env['login']('payments',env['real']))['access_token']
    dt=success('T08 destination login',env['login']('destination',env['real']))['access_token']
    xt=success('T08 unrelated login',env['login']('outside',env['real']))['access_token']
    def master(kind,p):return success('T08 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    parties=[master('PARTY',{'code':'T08-'+name,'display_name':'Synthetic '+name,'roles':[role],'contact_details':{},'archived':False}) for name,role in [('owner','OWNER'),('customer','CUSTOMER'),('other','CUSTOMER'),('broker','BROKER')]]
    owner,customer,other,broker=parties
    vehicle=master('VEHICLE',{'registration':'T08-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False})
    def draft(mode='DEDUCTED',q='100000.00',c='5000.00',origin=0,dest=1):
        target=uid();w=success('T08 draft review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':offices[origin],'destination_office_id':offices[dest]},at))
        p={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':offices[origin],'destination_office_id':offices[dest],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic T08','reason':'Synthetic entry','stops':[],
           'consignments':[{'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':1,'quoted_amount':q,'quote_mode':mode,'commission_method':'FIXED','commission_value':c,'notes':'','cars':[]}],
           'review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed overlap' if w['requires_confirmation'] else None}
        return success('T08 save draft',rpc('save_trip',{'target_id':target,'request_id':uid(),'expected_version':0,'payload':p},at))
    def dispatch(t):
        w=success('T08 actual dispatch review',rpc('review_trip_overlap',{'target_id':t['id'],'vehicle_id':vehicle['id'],'origin_office_id':t['origin_office_id'],'destination_office_id':t['destination_office_id'],'planned_dispatch_date':'2026-01-30'},at))
        p={'dispatch_date':'2026-01-30','reason':'Synthetic dispatch','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed dispatch' if w['requires_confirmation'] else None}
        args={'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p}
        result=success('T08 existing atomic dispatch',rpc('dispatch_trip',args,at))
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
    def movement(kind,p,token=st,rid=None):return success('T08 '+kind,post(p,token,rid,kind))
    a=dispatch(draft());movement('CUSTOMER_RECEIPT',payload('60000.00',[alloc(claim(a,'CUSTOMER_RECEIVABLE'),'60000.00')]))
    p=payload('5000.00',[alloc(claim(a,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']);rid=uid()
    result=movement('COMMISSION_SETTLEMENT',p,rid=rid)
    ok('AT-04 retained commission retry consumes once',post(p,rid=rid,kind='COMMISSION_SETTLEMENT')==(200,result))
    movement('OWNER_SETTLEMENT',payload('55000.00',[alloc(claim(a,'OWNER_PAYABLE'),'55000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
    ok('AT-04 public partial receipt retention remittance',balances(a)=={'CUSTOMER_RECEIVABLE':'40000.00','OWNER_PAYABLE':'-40000.00','BROKER_COMMISSION_PAYABLE':'0.00','CUSTODY_RECEIVABLE':'0.00'})
    ok('AT-04 repeated consumed source denied',post(p,kind='COMMISSION_SETTLEMENT')[0]==409)
    personal=dispatch(draft());op=payload('95000.00',[alloc(claim(personal,'OWNER_PAYABLE'),'95000.00')],broker['id'],owner['id']);rid=uid()
    for token in [xt,None]:ok('T08 direct personal payment outside scope denied',post(op,token,kind='PERSONAL_FUNDING')[0] in (401,403))
    funded=movement('PERSONAL_FUNDING',op,rid=rid)
    ok('AT-18 personal owner payment leaves customer debt and commission unchanged',balances(personal)=={'CUSTOMER_RECEIVABLE':'100000.00','OWNER_PAYABLE':'0.00','BROKER_COMMISSION_PAYABLE':'-5000.00','TRIP_FUNDING_PAYABLE':'-95000.00'})
    ok('AT-18 funding retry exactly once',post(op,rid=rid,kind='PERSONAL_FUNDING')==(200,funded))
    movement('CUSTOMER_RECEIPT',payload('100000.00',[alloc(claim(personal,'CUSTOMER_RECEIVABLE'),'100000.00')]))
    movement('FUNDING_RECOVERY',payload('95000.00',[alloc(claim(personal,'TRIP_FUNDING_PAYABLE'),'95000.00',claim(personal,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
    movement('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(claim(personal,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(personal,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
    ok('AT-18 recovered funding is not second fare',all(v=='0.00' for v in balances(personal).values()) and sql(f"select count(*) from public.financial_events where trip_id='{personal['id']}' and kind='DISPATCH';")=='1')
    advance=draft();consignment=advance['consignments'][0]['id'];p=payload('20000.00',[{'trip_id':advance['id'],'consignment_id':consignment,'amount':'20000.00'}]);p['effective_date']='2026-01-20';rid=uid()
    received=movement('ADVANCE',p,rid=rid)
    ok('AT-06 draft advance has no earnings',balances(advance)=={'CUSTODY_RECEIVABLE':'20000.00','CUSTOMER_ADVANCE_CREDIT':'-20000.00'})
    ok('AT-06 advance duplicate retry one event',post(p,rid=rid,kind='ADVANCE')==(200,received))
    cancelled=rpc('correct_trip_operation',{'action':'CANCEL_DRAFT','target_id':advance['id'],'request_id':uid(),'expected_version':advance['version'],'payload':{'reason':'Cannot erase funded draft'}},at)
    ok('T08 funded draft cancellation blocked until T10',cancelled[0]==400 and cancelled[1].get('message') in ('FINANCIAL_DEPENDENCIES','DEPENDENT_SETTLEMENTS'))
    advance=dispatch(advance)
    apply=payload('20000.00',[alloc(claim(advance,'CUSTOMER_RECEIVABLE'),'20000.00',claim(advance,'CUSTOMER_ADVANCE_CREDIT'))],customer['id'],customer['id']);rid=uid()
    applied=movement('ADVANCE_APPLICATION',apply,rid=rid)
    ok('AT-06 explicit credit application reduces debt only',balances(advance)['CUSTOMER_RECEIVABLE']=='80000.00' and balances(advance)['CUSTODY_RECEIVABLE']=='20000.00' and balances(advance)['CUSTOMER_ADVANCE_CREDIT']=='0.00')
    ok('AT-06 repeated application rejects new request but original retry succeeds',post(apply,kind='ADVANCE_APPLICATION')[0]==409 and post(apply,rid=rid,kind='ADVANCE_APPLICATION')==(200,applied))
    trip_credit=draft(q='100.00',c='0.00');movement('ADVANCE',payload('2.00',[{'trip_id':trip_credit['id'],'amount':'2.00'}]))
    trip_credit=dispatch(trip_credit)
    credit_apply=payload('2.00',[alloc(claim(trip_credit,'CUSTOMER_RECEIVABLE'),'2.00',claim(trip_credit,'CUSTOMER_ADVANCE_CREDIT'))],customer['id'],customer['id'])
    ok('T08 non-cash application cannot spoof a different recipient',post(dict(credit_apply,payee_id=broker['id']),kind='ADVANCE_APPLICATION')[1].get('message')=='INVALID_PARTIES')
    movement('ADVANCE_APPLICATION',credit_apply)
    ok('AT-06 trip-level credit is explicitly attributed to selected consignment',balances(trip_credit)['CUSTOMER_RECEIVABLE']=='98.00' and sql(f"select sum(signed_amount)::numeric(18,2)::text from public.journal_lines where trip_id='{trip_credit['id']}' and consignment_id='{trip_credit['consignments'][0]['id']}' and account_purpose='CUSTOMER_RECEIVABLE';")=='98.00')
    excess=dispatch(draft(q='100.00',c='5.00'));p=payload('120.00',[alloc(claim(excess,'CUSTOMER_RECEIVABLE'),'100.00')]);p['credits']=[{'trip_id':excess['id'],'consignment_id':None,'amount':'20.00'}];rid=uid()
    credited=movement('CUSTOMER_RECEIPT',p,rid=rid)
    ok('AT-06 excess is explicit credit with zero debt',balances(excess)=={'CUSTOMER_RECEIVABLE':'0.00','OWNER_PAYABLE':'-95.00','BROKER_COMMISSION_PAYABLE':'-5.00','CUSTODY_RECEIVABLE':'120.00','CUSTOMER_ADVANCE_CREDIT':'-20.00'})
    ok('T08 excess receipt retry retains original',post(p,rid=rid)==(200,credited))
    custody=next(x for x in ledger(excess,at)[1]['claims'] if x['account_purpose']=='CUSTODY_RECEIVABLE' and x['remaining']=='20.00')
    rp=payload('7.50',[alloc(claim(excess,'CUSTOMER_ADVANCE_CREDIT'),'7.50',custody)],broker['id'],customer['id']);rp['office_id']=offices[1];rid=uid();returned=movement('REFUND',rp,dt,rid)
    ok('AT-06 partial refund consumes credit and funded custody',balances(excess)['CUSTOMER_ADVANCE_CREDIT']=='-12.50' and balances(excess)['CUSTODY_RECEIVABLE']=='112.50')
    ok('T08 refund identical retry one event',post(rp,dt,rid,'REFUND')==(200,returned))
    custody=next(x for x in ledger(excess,at)[1]['claims'] if x['line_id']==custody['line_id'])
    refund=payload('12.50',[alloc(claim(excess,'CUSTOMER_ADVANCE_CREDIT'),'12.50',custody)],broker['id'],customer['id'])
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:post(refund,kind='REFUND'),range(2)))
    ok('AT-06 concurrent credit consumption exactly one commit',sorted(r[0] for r in results)==[200,409])
    ok('AT-06 unused credit fully refunded once',balances(excess)['CUSTOMER_ADVANCE_CREDIT']=='0.00' and balances(excess)['CUSTODY_RECEIVABLE']=='100.00')
    transfer=dispatch(draft(q='100.00',c='5.00'));movement('CUSTOMER_RECEIPT',payload('60.00',[alloc(claim(transfer,'CUSTOMER_RECEIVABLE'),'60.00')]))
    source=claim(transfer,'CUSTODY_RECEIVABLE');p=payload('30.00',[{'source_line_id':source['line_id'],'source_version':source['version'],'amount':'30.00'}],broker['id'],owner['id']);rid=uid();tr=movement('CUSTODY_TRANSFER',p,rid=rid)
    ok('AT-18 transfer leaves all earnings and liabilities unchanged',balances(transfer)=={'CUSTOMER_RECEIVABLE':'40.00','OWNER_PAYABLE':'-95.00','BROKER_COMMISSION_PAYABLE':'-5.00','CUSTODY_RECEIVABLE':'60.00'})
    ok('AT-18 transfer retry consumes once',post(p,rid=rid,kind='CUSTODY_TRANSFER')==(200,tr))
    s=claim(transfer,'CUSTODY_RECEIVABLE',broker['id']);over=payload('30.01',[{'source_line_id':s['line_id'],'source_version':s['version'],'amount':'30.01'}],broker['id'],owner['id'])
    ok('T08 transfer prevents custody overdraft',post(over,kind='CUSTODY_TRANSFER')[1].get('message')=='INSUFFICIENT_SOURCE_OR_CLAIM')
    p=payload('20.00',[{'source_line_id':s['line_id'],'source_version':s['version'],'amount':'20.00'}],broker['id'],owner['id'])
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:post(p,kind='CUSTODY_TRANSFER'),range(2)))
    ok('T08 concurrent transfer rejects stale consumption',sorted(r[0] for r in results)==[200,409])
    owncustody=next(x for x in ledger(transfer,at)[1]['claims'] if x['account_purpose']=='CUSTODY_RECEIVABLE' and x['party_id']==owner['id'] and x['remaining']=='30.00')
    movement('OWNER_SETTLEMENT',payload(owncustody['remaining'],[alloc(claim(transfer,'OWNER_PAYABLE'),owncustody['remaining'],owncustody)],owner['id'],owner['id']))
    ok('T08 owner retention is explicit settlement after custody transfer',balances(transfer)['CUSTOMER_RECEIVABLE']=='40.00' and balances(transfer)['OWNER_PAYABLE']=='-65.00')
    owner_source=claim(transfer,'CUSTODY_RECEIVABLE',owner['id'])
    movement('COMMISSION_SETTLEMENT',payload('5.00',[alloc(claim(transfer,'BROKER_COMMISSION_PAYABLE'),'5.00',owner_source)],owner['id'],broker['id']))
    ok('T08 actual commission payment distinct from owner settlement',balances(transfer)['BROKER_COMMISSION_PAYABLE']=='0.00' and balances(transfer)['OWNER_PAYABLE']=='-65.00')
    split=dispatch(draft(q='100.00',c='0.00'))
    movement('CUSTOMER_RECEIPT',payload('30.00',[alloc(claim(split,'CUSTOMER_RECEIVABLE'),'30.00')]))
    movement('CUSTOMER_RECEIPT',payload('40.00',[alloc(claim(split,'CUSTOMER_RECEIVABLE'),'40.00')]))
    sources=[x for x in ledger(split,at)[1]['claims'] if x['account_purpose']=='CUSTODY_RECEIVABLE'];target=claim(split,'OWNER_PAYABLE')
    movement('OWNER_SETTLEMENT',payload('70.00',[alloc(target,s['remaining'],s) for s in sources],broker['id'],owner['id']))
    ok('T08 multiple sources can settle one target without repeated consumption',balances(split)['OWNER_PAYABLE']=='-30.00' and balances(split)['CUSTODY_RECEIVABLE']=='0.00')
    bulk1=dispatch(draft(q='10.00',c='0.00'));bulk2=dispatch(draft(q='20.00',c='0.00'))
    p=payload('15.00',[alloc(claim(bulk1,'OWNER_PAYABLE'),'5.00'),alloc(claim(bulk2,'OWNER_PAYABLE'),'10.00')],broker['id'],owner['id'])
    ok('T08 bulk funding mismatch denied',post(dict(p,amount='15.01'),kind='PERSONAL_FUNDING')[1].get('message')=='ALLOCATION_MISMATCH')
    movement('PERSONAL_FUNDING',p)
    ok('T08 bulk explicit allocation exactly payment total',balances(bulk1)['TRIP_FUNDING_PAYABLE']=='-5.00' and balances(bulk2)['TRIP_FUNDING_PAYABLE']=='-10.00')
    movement('CUSTOMER_RECEIPT',payload('15.00',[alloc(claim(bulk1,'CUSTOMER_RECEIVABLE'),'5.00'),alloc(claim(bulk2,'CUSTOMER_RECEIVABLE'),'10.00')]))
    bp=payload('15.00',[alloc(claim(bulk1,'OWNER_PAYABLE'),'5.00',claim(bulk1,'CUSTODY_RECEIVABLE')),alloc(claim(bulk2,'OWNER_PAYABLE'),'10.00',claim(bulk2,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id'])
    ok('T08 bulk remittance allocations must match payment total',post(dict(bp,amount='14.99'),kind='OWNER_SETTLEMENT')[1].get('message')=='ALLOCATION_MISMATCH')
    movement('OWNER_SETTLEMENT',bp)
    ok('T08 bulk remittance consumes only explicit same-trip sources',balances(bulk1)['CUSTODY_RECEIVABLE']=='0.00' and balances(bulk2)['CUSTODY_RECEIVABLE']=='0.00')
    hidden=dispatch(draft(q='10.00',c='0.00',origin=2,dest=1))
    p=payload('1.00',[alloc(claim(hidden,'OWNER_PAYABLE'),'1.00')],broker['id'],owner['id'])
    ok('T08 direct hidden claim consumption denied',post(p,kind='PERSONAL_FUNDING')[0]==403)
    c=claim(hidden,'CUSTOMER_RECEIVABLE');credit=payload('1.00',[{'trip_id':hidden['id'],'amount':'1.00'}]);ok('T08 hidden credit creation denied',post(credit,kind='ADVANCE')[0]==403)
    wrong=payload('1.00',[{'trip_id':bulk1['id'],'amount':'1.00'}],other['id'],broker['id']);ok('T08 unrelated customer cannot receive trip credit',post(wrong,kind='ADVANCE')[1].get('message')=='CUSTOMER_TRIP_REQUIRED')
    rp=payload('1.00',[alloc(claim(hidden,'CUSTOMER_RECEIVABLE'),'1.00',claim(advance,'CUSTODY_RECEIVABLE'))],broker['id'],customer['id']);ok('T08 refund cannot target receivable or unrelated source',post(rp,at,kind='REFUND')[0]==400)
    wrong_source=copy.deepcopy(refund);wrong_source['allocations'][0].update(source_line_id=claim(advance,'CUSTODY_RECEIVABLE')['line_id'],source_version=claim(advance,'CUSTODY_RECEIVABLE')['version'])
    ok('T08 refund rejects custody from another permitted trip before claim consumption',post(wrong_source,kind='REFUND')[1].get('message')=='INVALID_SOURCE')
    wrong_source=payload('1.00',[alloc(claim(split,'OWNER_PAYABLE'),'1.00',claim(advance,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id'])
    ok('T08 remittance cannot silently spend another trip custody',post(wrong_source,kind='OWNER_SETTLEMENT')[1].get('message')=='INVALID_SOURCE')
    rp=payload('1.00',[alloc(claim(split,'OWNER_PAYABLE'),'1.00')],broker['id'],owner['id'])
    for mutation in [lambda x:x.update(journal_lines=[]),lambda x:x.update(actor_id=user['id']),lambda x:x['allocations'][0].update(amount='1.001'),lambda x:x['allocations'][0].update(amount=1),lambda x:x.update(amount='0.00')]:
        bad=copy.deepcopy(rp);mutation(bad);ok('T08 forged fields and exact input violations denied',post(bad,kind='PERSONAL_FUNDING')[0]==400)
    ok('T08 expense offsets remain unavailable until T09',post(rp,kind='REIMBURSEMENT')[1].get('message')=='WORKFLOW_NOT_AVAILABLE')
    # Force a deferred transaction failure, then retry the identical request.
    rollback=draft();p=payload('1.00',[{'trip_id':rollback['id'],'amount':'1.00'}]);rid=uid();before=ledger(rollback)[1]
    sql("create function public.t08_fail_commit() returns trigger language plpgsql as $$ begin if new.kind='ADVANCE' then raise exception 'T08_COMMIT_FAILURE';end if;return null;end $$;create constraint trigger t08_commit_failure after insert on public.financial_events deferrable initially deferred for each row execute function public.t08_fail_commit();")
    try:
        fail=post(p,kind='ADVANCE',rid=rid);ok('T08 deferred commit failure returns failure',fail[0]>=400 and fail[1].get('message')=='T08_COMMIT_FAILURE')
        ok('T08 rollback leaves no event allocations audit retry or balances',ledger(rollback)[1]==before and sql(f"select (select count(*) from public.financial_events where request_id='{rid}')+(select count(*) from public.idempotency_records where request_id='{rid}');")=='0')
    finally:sql('drop trigger t08_commit_failure on public.financial_events;drop function public.t08_fail_commit();')
    movement('ADVANCE',p,rid=rid)
    ok('T08 all actual events balanced',sql(f"select count(*) from (select e.id from public.financial_events e left join public.journal_lines l on l.event_id=e.id where e.business_id='{b}' group by e.id having coalesce(sum(l.signed_amount),0)<>0)x;")=='0')
    print('T08 AT-04/06/18 and non-expense AT-05 checks PASS; diesel/reimbursement/profit checks deferred T09.',flush=True)
    import sys, subprocess
    if '--native-payments' in sys.argv:
        native=dispatch(draft());config_path=env['ROOT']/'tools/.local/t08-native-config.json'
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'payments','TEST_PASSWORD':env['real'],'TEST_TRIP_ID':native['id'],'TEST_OFFICE_ID':offices[0]}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t08-native.log').open('w',encoding='utf-8') as log:
                built=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/payments_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('T08 native Windows committed receipt retention remittance UI',built.returncode==0)
            ok('T08 native persistence independently verified',balances(native)=={'CUSTOMER_RECEIVABLE':'40000.00','OWNER_PAYABLE':'-40000.00','BROKER_COMMISSION_PAYABLE':'0.00','CUSTODY_RECEIVABLE':'0.00'})
        finally:config_path.unlink(missing_ok=True)
