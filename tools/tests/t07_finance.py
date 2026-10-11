"""Real T07 receipts, immutable claim kernel and transactional race checks."""
import base64, copy, json, uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,offices=env['b'],env['at'],env['office']
    uid=lambda:str(uuid.uuid4())
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    user=success('T07 managed origin staff',env['edge']({'action':'create','username':'finance','display_name':'Synthetic finance','role':'STAFF','office_ids':[offices[0]],'password':env['password']},at))
    env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{user['id']}';"))
    temp=success('T07 temporary login',env['login']('finance'));env['change'](temp['access_token'])
    st=success('T07 ready login',env['login']('finance',env['real']))['access_token']
    dt=success('T07 destination login',env['login']('destination',env['real']))['access_token']
    xt=success('T07 unrelated login',env['login']('outside',env['real']))['access_token']
    def master(kind,p):return success('T07 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    parties=[master('PARTY',{'code':'T07-'+name,'display_name':'Synthetic '+name,'roles':[role],'contact_details':{},'archived':False}) for name,role in [('owner','OWNER'),('customer','CUSTOMER'),('other','CUSTOMER'),('broker','BROKER')]]
    owner,customer,other,broker=parties
    vehicle=master('VEHICLE',{'registration':'T07-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False})
    def draft(mode='DEDUCTED',q='100000.00',c='5000.00',origin=0,dest=1):
        target=uid();w=success('T07 draft review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':offices[origin],'destination_office_id':offices[dest]},at))
        p={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':offices[origin],'destination_office_id':offices[dest],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic T07','reason':'Synthetic entry','stops':[],
           'consignments':[{'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':1,'quoted_amount':q,'quote_mode':mode,'commission_method':'FIXED','commission_value':c,'notes':'','cars':[]}],
           'review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed overlap' if w['requires_confirmation'] else None}
        return success('T07 save draft',rpc('save_trip',{'target_id':target,'request_id':uid(),'expected_version':0,'payload':p},at))
    def dispatch(t):
        w=success('T07 actual dispatch review',rpc('review_trip_overlap',{'target_id':t['id'],'vehicle_id':vehicle['id'],'origin_office_id':t['origin_office_id'],'destination_office_id':t['destination_office_id'],'planned_dispatch_date':'2026-01-30'},at))
        p={'dispatch_date':'2026-01-30','reason':'Synthetic dispatch','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed dispatch' if w['requires_confirmation'] else None}
        args={'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p}
        result=success('T07 existing atomic dispatch',rpc('dispatch_trip',args,at))
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
    # Private kernel calls use a verified real session and temporary local test
    # membership. This is NOT a client API or completed T08 workflow.
    claims=json.loads(base64.urlsafe_b64decode(at.split('.')[1]+'==='))
    def core(kind,p,rid=None):
        query="begin;grant carrier_security to postgres;set local role carrier_security;do $claims$ begin perform set_config('request.jwt.claims',"+"'"+json.dumps(claims).replace("'","''")+"',true);end $claims$;"
        query+=f"select private.post_claim_event('{kind}','{rid or uid()}',0,'{json.dumps(p)}');reset role;revoke carrier_security from postgres;commit;"
        raw=sql(query);return json.loads(next(x for x in raw.splitlines() if x.startswith('{')))
    def balances(t):return {x['account_purpose']:x['balance'] for x in ledger(t,at)[1]['balances']}
    a=dispatch(draft());ca=claim(a,'CUSTOMER_RECEIVABLE')
    ok('AT-01 recognized exact deducted split',balances(a)=={'CUSTOMER_RECEIVABLE':'100000.00','OWNER_PAYABLE':'-95000.00','BROKER_COMMISSION_PAYABLE':'-5000.00'})
    ok('T07 scoped claim read omits raw event/actor/business metadata',set(ledger(a)[1])=={'scope','complete','label','balances','claims'} and all(set(x)=={'line_id','party_id','account_purpose','consignment_id','expense_id','effective_date','remaining','version'} for x in ledger(a)[1]['claims']))
    ok('T07 unrelated/anonymous ledger reads denied',ledger(a,xt)[0]==403 and ledger(a,None)[0] in (401,403))
    p=payload('60000.00',[alloc(ca,'60000.00')]);rid=uid()
    for token in [xt,None]:ok('T07 unauthorized receipt denied',post(p,token,rid)[0] in (401,403))
    for value in ['1.001',1.00,'-1.00','0.00','10000000000000000.00']:
        bad=copy.deepcopy(p);bad['amount']=value;r=post(bad);ok('AT-17 invalid precision/type/range/sign rejected',r[0]==400)
    for mutation in [lambda x:x.update(actor_id=user['id']),lambda x:x.update(journal_lines=[]),lambda x:x.update(payer_id=other['id']),lambda x:x.update(amount='59999.99'),lambda x:x['allocations'][0].update(amount=60000),lambda x:x['allocations'].append(x['allocations'][0].copy())]:
        bad=copy.deepcopy(p);mutation(bad);ok('T07 spoofing/wrong-party/duplicate/mismatch denied',post(bad)[0]==400)
    ok('T07 nonzero create version denied',post(p,version=1)[0]==400)
    ok('T07 later client settlement/expense workflows blocked',all(post(p,kind=k)[1].get('message')=='WORKFLOW_NOT_AVAILABLE' for k in ['DISPATCH','OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','EXPENSE','ADVANCE','REVERSAL']))
    p['office_id']=offices[1]
    receipt=success('AT-04 customer receipt by destination staff',post(p,dt,rid))
    ok('AT-04 customer debt, held money and owner debt separate',balances(a)=={'CUSTOMER_RECEIVABLE':'40000.00','CUSTODY_RECEIVABLE':'60000.00','OWNER_PAYABLE':'-95000.00','BROKER_COMMISSION_PAYABLE':'-5000.00'})
    ok('AT-16 identical receipt retry returns exact result',post(p,dt,rid)==(200,receipt))
    ok('AT-16 changed request or different actor rejected',post(dict(p,reason='Changed'),dt,rid)[0]==409 and post(p,at,rid)[0]==409)
    ok('AT-16 one event/audit/idempotency result on retries',sql(f"select (select count(*) from public.financial_events where request_id='{rid}')::text||','||(select count(*) from public.idempotency_records where request_id='{rid}')::text||','||(select count(*) from public.audit_events where record_id='{receipt['record_id']}')::text;")=='1,1,1')
    def archive_broker(archived,version):
        return success('T07 archive/restore recipient',rpc('save_master_record',{'kind':'PARTY','target_id':broker['id'],'request_id':uid(),'expected_version':version,'payload':{'code':'T07-broker','display_name':'Synthetic broker','roles':['BROKER'],'contact_details':{},'archived':archived}},at))
    archived=archive_broker(True,broker['version'])
    ok('AT-16 archived recipient retains committed retry result',post(p,dt,rid)==(200,receipt))
    new=payload('1.00',[alloc(claim(a,'CUSTOMER_RECEIVABLE'),'1.00')])
    ok('T07 archived recipient cannot receive new posting',post(new)[1].get('message')=='ACTIVE_RECIPIENT_OR_OFFICE_REQUIRED')
    broker.update(archive_broker(False,archived['version']))
    source=claim(a,'CUSTODY_RECEIVABLE');commission=claim(a,'BROKER_COMMISSION_PAYABLE')
    core('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(commission,'5000.00',source)],broker['id'],broker['id']))
    source=claim(a,'CUSTODY_RECEIVABLE');own=claim(a,'OWNER_PAYABLE')
    settle_p=payload('55000.00',[alloc(own,'55000.00',source)],broker['id'],owner['id']);settle_id=uid()
    settled=core('OWNER_SETTLEMENT',settle_p,settle_id)
    ok('AT-04 private retention/remittance kernel yields 40000 debt and zero custody',balances(a)=={'CUSTOMER_RECEIVABLE':'40000.00','CUSTODY_RECEIVABLE':'0.00','OWNER_PAYABLE':'-40000.00','BROKER_COMMISSION_PAYABLE':'0.00'})
    ok('AT-16 private kernel settlement retry consumes once',core('OWNER_SETTLEMENT',settle_p,settle_id)==settled)
    # Full A/B examples use the same real dispatch + receipt paths and private
    # settlement kernel. No trusted arbitrary journals fabricate their balances.
    for mode,charge,owner_due in [('DEDUCTED','100000.00','95000.00'),('ADDED','105000.00','100000.00')]:
        t=dispatch(draft(mode));c=claim(t,'CUSTOMER_RECEIVABLE')
        success('AT-01/02 full customer receipt',post(payload(charge,[alloc(c,charge)])))
        ok('AT-01/02 receipt is not owner settlement',balances(t)['OWNER_PAYABLE']=='-'+owner_due and balances(t)['CUSTODY_RECEIVABLE']==charge)
        core('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(claim(t,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(t,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
        core('OWNER_SETTLEMENT',payload(owner_due,[alloc(claim(t,'OWNER_PAYABLE'),owner_due,claim(t,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
        ok('AT-01/02 full canonical private settlement balances zero',all(v=='0.00' for v in balances(t).values()))
    race=dispatch(draft(q='0.03',c='0.00'));c=claim(race,'CUSTOMER_RECEIVABLE');p=payload('0.02',[alloc(c,'0.02')])
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:post(p),range(2)))
    ok('AT-16 competing customer claim one commit one conflict',sorted(r[0] for r in results)==[200,409])
    ok('AT-17 exact paisa remaining derived from journal',balances(race)['CUSTOMER_RECEIVABLE']=='0.01' and claim(race,'CUSTOMER_RECEIVABLE')['remaining']=='0.01')
    c=claim(race,'CUSTOMER_RECEIVABLE');same=payload('0.01',[alloc(c,'0.01')]);same_id=uid()
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:post(same,rid=same_id),range(2)))
    ok('AT-16 concurrent identical retries return one event',results[0]==results[1] and results[0][0]==200 and sql(f"select count(*) from public.financial_events where request_id='{same_id}';")=='1')
    ok('T07 consumed claims excluded from open choices',not any(x['account_purpose']=='CUSTOMER_RECEIVABLE' for x in ledger(race)[1]['claims']))
    custody_race=dispatch(draft(q='100.00',c='0.00'))
    success('T07 seed real custody for race',post(payload('60.00',[alloc(claim(custody_race,'CUSTOMER_RECEIVABLE'),'60.00')])))
    race_p=payload('40.00',[alloc(claim(custody_race,'OWNER_PAYABLE'),'40.00',claim(custody_race,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id'])
    def spend(_):
        try:return 'COMMITTED',core('OWNER_SETTLEMENT',race_p)
        except RuntimeError as e:
            if 'CLAIM_VERSION_CONFLICT' in str(e):return 'CONFLICT',None
            raise
    with ThreadPoolExecutor(max_workers=2) as pool:spent=list(pool.map(spend,range(2)))
    ok('AT-16 competing custody spend one commit one conflict',sorted(r[0] for r in spent)==['COMMITTED','CONFLICT'])
    ok('T07 custody cannot go negative',balances(custody_race)['CUSTODY_RECEIVABLE']=='20.00' and balances(custody_race)['OWNER_PAYABLE']=='-60.00')
    bad=payload('30.00',[alloc(claim(custody_race,'OWNER_PAYABLE'),'30.00',claim(custody_race,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id'])
    try:core('OWNER_SETTLEMENT',bad);raise AssertionError('Custody overdraft accepted')
    except RuntimeError as e:ok('T07 overdraft rejected at current source revision','INSUFFICIENT_SOURCE' in str(e))
    early=payload('0.01',[alloc(claim(custody_race,'CUSTOMER_RECEIVABLE'),'0.01')]);early['effective_date']='2026-01-29'
    ok('T07 pre-earning receipt requires later advance workflow',post(early)[1].get('message')=='PAYMENT_PRECEDES_CLAIM')
    bulk=dispatch(draft(q='10.00',c='0.00'));bulk2=dispatch(draft(q='20.00',c='0.00'))
    pbulk=payload('15.00',[alloc(claim(bulk,'CUSTOMER_RECEIVABLE'),'5.00'),alloc(claim(bulk2,'CUSTOMER_RECEIVABLE'),'10.00')])
    br=success('T07 multi-trip explicit receipt',post(pbulk))
    ok('T07 bulk event metadata stays private; trip totals are contextual',balances(bulk)['CUSTODY_RECEIVABLE']=='5.00' and balances(bulk2)['CUSTODY_RECEIVABLE']=='10.00')
    hidden=dispatch(draft(q='10.00',c='0.00',origin=2,dest=1))
    mixed=payload('1.00',[alloc(claim(hidden,'CUSTOMER_RECEIVABLE'),'1.00')])
    ok('T07 any inaccessible bulk target denied',post(mixed)[0]==403)
    # Future workflow claims are trusted balanced metadata fixtures only; T07
    # tests their shared consumption kernel, not expense/advance entry screens.
    foundation=dispatch(draft(q='100.00',c='0.00'))
    success('T07 real receipt supplies claim-kernel fixture custody',post(payload('30.00',[alloc(claim(foundation,'CUSTOMER_RECEIVABLE'),'30.00')])))
    def seed(kind,amount,debit_party,debit_purpose,credit_party,credit_purpose,expense=None):
        event=uid();consignment=foundation['consignments'][0]['id'];expense_sql="'"+expense+"'" if expense else 'null'
        sql(f"begin;insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id,expense_id) values('{event}','{b}','{kind}','2026-02-02','{env['ap']['id']}','{offices[0]}','{vehicle['id']}','{foundation['id']}','{consignment}',{amount},'{uid()}',{expense_sql});insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,expense_id) values('{b}','{event}','{debit_party}','{offices[0]}','{vehicle['id']}','{foundation['id']}','{consignment}','{debit_purpose}',{amount},{expense_sql}),('{b}','{event}','{credit_party}','{offices[0]}','{vehicle['id']}','{foundation['id']}','{consignment}','{credit_purpose}',-{amount},{expense_sql});commit;")
    seed('PERSONAL_FUNDING','20.00',owner['id'],'OWNER_PAYABLE',broker['id'],'TRIP_FUNDING_PAYABLE')
    category=master('CATEGORY',{'name':'T07 synthetic cost','archived':False})
    def expense_fixture(amount,bearer):
        eid=uid();sql(f"insert into public.expenses(id,business_id,vehicle_id,trip_id,office_id,category_id,expense_date,amount,payer_id,cost_bearer_id,funding_source,state) values('{eid}','{b}','{vehicle['id']}','{foundation['id']}','{offices[0]}','{category['id']}','2026-02-02',{amount},'{broker['id']}','{bearer}','PERSONAL_FUNDS','CONFIRMED');");return eid
    seed('EXPENSE','10.00',owner['id'],'OWNER_PAYABLE',broker['id'],'EXPENSE_REIMBURSEMENT_PAYABLE',expense_fixture('10.00',owner['id']))
    seed('ADVANCE','5.00',broker['id'],'CUSTODY_RECEIVABLE',customer['id'],'CUSTOMER_ADVANCE_CREDIT')
    funding=claim(foundation,'TRIP_FUNDING_PAYABLE');reimb=claim(foundation,'EXPENSE_REIMBURSEMENT_PAYABLE')
    actual_source=next(x for x in ledger(foundation,at)[1]['claims'] if x['account_purpose']=='CUSTODY_RECEIVABLE' and x['remaining']=='30.00')
    core('FUNDING_RECOVERY',payload('20.00',[alloc(funding,'20.00',actual_source)],broker['id'],broker['id']))
    actual_source=next(x for x in ledger(foundation,at)[1]['claims'] if x['line_id']==actual_source['line_id'])
    core('REIMBURSEMENT',payload('10.00',[alloc(reimb,'10.00',actual_source)],broker['id'],broker['id']))
    core('ADVANCE_APPLICATION',payload('5.00',[alloc(claim(foundation,'CUSTOMER_RECEIVABLE'),'5.00',claim(foundation,'CUSTOMER_ADVANCE_CREDIT'))],customer['id'],customer['id']))
    ok('T07 private funding/reimbursement/credit claims consume exactly once',balances(foundation)['TRIP_FUNDING_PAYABLE']=='0.00' and balances(foundation)['EXPENSE_REIMBURSEMENT_PAYABLE']=='0.00' and balances(foundation)['CUSTOMER_ADVANCE_CREDIT']=='0.00' and balances(foundation)['CUSTOMER_RECEIVABLE']=='65.00' and balances(foundation)['CUSTODY_RECEIVABLE']=='5.00')
    seed('EXPENSE','1.00',other['id'],'PARTY_COST_RECOVERY',broker['id'],'EXPENSE_REIMBURSEMENT_PAYABLE',expense_fixture('1.00',other['id']))
    ok('T07 eight distinct account purposes query from effective journal',sql(f"select count(distinct account_purpose) from public.journal_lines where business_id='{b}';")=='8' and claim(foundation,'PARTY_COST_RECOVERY')['remaining']=='1.00')
    owner_receipt=dispatch(draft())
    success('T07 owner receives customer funds in custody',post(payload('100000.00',[alloc(claim(owner_receipt,'CUSTOMER_RECEIVABLE'),'100000.00')],payee=owner['id'])))
    ok('T07 owner custody receipt still does not settle owner entitlement',balances(owner_receipt)['CUSTOMER_RECEIVABLE']=='0.00' and balances(owner_receipt)['CUSTODY_RECEIVABLE']=='100000.00' and balances(owner_receipt)['OWNER_PAYABLE']=='-95000.00')
    maximum=dispatch(draft(q='9999999999999999.99',c='0.00'));maximum2=dispatch(draft(q='9999999999999999.99',c='0.00'))
    from decimal import Decimal
    summary=success('T07 exact wide aggregate summary',rpc('get_balance_summary',{'scope':'ALL'},at))
    ok('AT-17 aggregate balances exceed single posting bound without overflow',Decimal(summary['totals']['CUSTOMER_RECEIVABLE'])>Decimal('19999999999999999.98') and balances(maximum)['CUSTOMER_RECEIVABLE']=='9999999999999999.99')
    # Preserve T06 commit-failure guarantees for receipt posting as well.
    rollback=dispatch(draft(q='1.00',c='0.00'));p=payload('1.00',[alloc(claim(rollback,'CUSTOMER_RECEIVABLE'),'1.00')]);rollback_id=uid()
    sql("create function public.t07_fail_commit() returns trigger language plpgsql as $$ begin if new.kind='CUSTOMER_RECEIPT' then raise exception 'T07_COMMIT_FAILURE';end if;return null;end $$;create constraint trigger t07_commit_failure after insert on public.financial_events deferrable initially deferred for each row execute function public.t07_fail_commit();")
    before=ledger(rollback)[1]
    try:
        failed=post(p,rid=rollback_id);ok('T07 deferred commit failure returns failure',failed[0]>=400 and failed[1].get('message')=='T07_COMMIT_FAILURE')
        ok('T07 no partial event/allocations/audit/retry/claim changes',ledger(rollback)[1]==before and sql(f"select (select count(*) from public.financial_events where request_id='{rollback_id}')+(select count(*) from public.idempotency_records where request_id='{rollback_id}');")=='0')
    finally:sql('drop trigger t07_commit_failure on public.financial_events;drop function public.t07_fail_commit();')
    success('T07 same receipt request succeeds after rollback',post(p,rid=rollback_id))
    ok('T07 every created event balanced',sql(f"select count(*) from (select e.id from public.financial_events e left join public.journal_lines l on l.event_id=e.id where e.business_id='{b}' group by e.id having coalesce(sum(l.signed_amount),0)<>0)x;")=='0')
    ok('T07 original recognition once, no second earnings from receipt',sql(f"select count(*) from public.financial_events where trip_id='{a['id']}' and kind='DISPATCH';")=='1')
    print('T07 financial kernel acceptance PASS; T08/T09 payment and expense entry workflows remain deferred.',flush=True)
