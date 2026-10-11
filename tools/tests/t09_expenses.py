"""Real T09 receipts, immutable claim kernel and transactional race checks."""
import base64, copy, json, uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,offices=env['b'],env['at'],env['office']
    uid=lambda:str(uuid.uuid4())
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    user=success('T09 managed origin staff',env['edge']({'action':'create','username':'expenses','display_name':'Synthetic finance','role':'STAFF','office_ids':[offices[0]],'password':env['password']},at))
    env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{user['id']}';"))
    temp=success('T09 temporary login',env['login']('expenses'));env['change'](temp['access_token'])
    st=success('T09 ready login',env['login']('expenses',env['real']))['access_token']
    dt=success('T09 destination login',env['login']('destination',env['real']))['access_token']
    xt=success('T09 unrelated login',env['login']('outside',env['real']))['access_token']
    def master(kind,p):return success('T09 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    parties=[master('PARTY',{'code':'T09-'+name,'display_name':'Synthetic '+name,'roles':[role],'contact_details':{},'archived':False}) for name,role in [('owner','OWNER'),('customer','CUSTOMER'),('other','CUSTOMER'),('broker','BROKER')]]
    owner,customer,other,broker=parties
    vehicle=master('VEHICLE',{'registration':'T09-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False})
    def draft(mode='DEDUCTED',q='100000.00',c='5000.00',origin=0,dest=1):
        target=uid();w=success('T09 draft review',rpc('review_trip_overlap',{'target_id':target,'vehicle_id':vehicle['id'],'origin_office_id':offices[origin],'destination_office_id':offices[dest]},at))
        p={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':offices[origin],'destination_office_id':offices[dest],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic T09','reason':'Synthetic entry','stops':[],
           'consignments':[{'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':1,'quoted_amount':q,'quote_mode':mode,'commission_method':'FIXED','commission_value':c,'notes':'','cars':[]}],
           'review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed overlap' if w['requires_confirmation'] else None}
        return success('T09 save draft',rpc('save_trip',{'target_id':target,'request_id':uid(),'expected_version':0,'payload':p},at))
    def dispatch(t):
        w=success('T09 actual dispatch review',rpc('review_trip_overlap',{'target_id':t['id'],'vehicle_id':vehicle['id'],'origin_office_id':t['origin_office_id'],'destination_office_id':t['destination_office_id'],'planned_dispatch_date':'2026-01-30'},at))
        p={'dispatch_date':'2026-01-30','reason':'Synthetic dispatch','review_token':w['review_token'],'overlap_confirmed':w['requires_confirmation'],'overlap_reason':'Synthetic reviewed dispatch' if w['requires_confirmation'] else None}
        args={'target_id':t['id'],'request_id':uid(),'expected_version':t['version'],'payload':p}
        result=success('T09 existing atomic dispatch',rpc('dispatch_trip',args,at))
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
    def movement(kind,p,token=st,rid=None):return success('T09 '+kind,post(p,token,rid,kind))
    import base64,copy,hashlib
    from decimal import Decimal
    category=master('CATEGORY',{'name':'T09 Diesel and maintenance','archived':False})
    def ea(c,amount,component='OFFSET'):return {'line_id':c['line_id'],'version':c['version'],'amount':amount,'component':component}
    def ep(t=None,funding='SELF_FUNDED_COST',payer=None,bearer=None,amount='10000.00',allocations=None,office=0):return {'vehicle_id':vehicle['id'],'trip_id':t['id'] if t else None,'office_id':offices[office],'category_id':category['id'],'effective_date':'2026-03-05','amount':amount,'payer_id':payer or owner['id'],'cost_bearer_id':bearer or owner['id'],'funding_source':funding,'reason':'Synthetic T09 expense','allocations':allocations or [],'offset_confirmed':True}
    def expense(p,token=st,rid=None):return post(p,token,rid,kind='EXPENSE')
    def costs(t=None,month=True,token=at):return rpc('get_expense_totals',{'vehicle_id':vehicle['id'],'from_date':'2026-03-01','to_date':'2026-03-31','trip_id':t['id'] if t else None},token)
    def collect(t):return movement('CUSTOMER_RECEIPT',payload('100000.00',[alloc(claim(t,'CUSTOMER_RECEIVABLE'),'100000.00')]))
    a=dispatch(draft());p=ep(a);rid=uid();e=success('AT-05 owner personally pays diesel',expense(p,rid=rid))
    ok('AT-05 personal diesel lowers profit to 85000 leaves owner due 95000',costs(a)[1]['owner_cost']=='10000.00' and Decimal('95000.00')-Decimal(costs(a)[1]['owner_cost'])==Decimal('85000.00') and balances(a)['OWNER_PAYABLE']=='-95000.00')
    ok('T09 expense retry once',expense(p,rid=rid)==(200,e) and sql(f"select count(*) from public.expenses where id='{e['record_id']}';")=='1')
    changed=copy.deepcopy(p);changed['amount']='10001.00';ok('T09 request changed denied',expense(changed,rid=rid)[0]==409)
    collect(a);movement('OWNER_SETTLEMENT',payload('95000.00',[alloc(claim(a,'OWNER_PAYABLE'),'95000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
    movement('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(claim(a,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(a,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
    ok('AT-05 owner actual cash remittance 95000',all(v=='0.00' for v in balances(a).values()))
    btrip=dispatch(draft());collect(btrip);p=ep(btrip,'PERSONAL_FUNDS',broker['id'],allocations=[ea(claim(btrip,'OWNER_PAYABLE'),'10000.00')]);rid=uid()
    be=success('AT-05 broker personally funded reviewed offset',expense(p,rid=rid))
    ok('AT-05 broker offset owner due85000 reimbursement10000 commission5000',balances(btrip)['OWNER_PAYABLE']=='-85000.00' and balances(btrip)['EXPENSE_REIMBURSEMENT_PAYABLE']=='-10000.00' and balances(btrip)['BROKER_COMMISSION_PAYABLE']=='-5000.00' and costs(btrip)[1]['vehicle_cost']=='10000.00')
    rp=payload('10000.00',[alloc(claim(btrip,'EXPENSE_REIMBURSEMENT_PAYABLE'),'10000.00',claim(btrip,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']);rr=uid()
    r=movement('REIMBURSEMENT',rp,rid=rr);ok('T09 reimbursement retry once',post(rp,rid=rr,kind='REIMBURSEMENT')==(200,r))
    ok('T09 repeated expense claim consumption denied',post(rp,kind='REIMBURSEMENT')[0]==409)
    movement('OWNER_SETTLEMENT',payload('85000.00',[alloc(claim(btrip,'OWNER_PAYABLE'),'85000.00',claim(btrip,'CUSTODY_RECEIVABLE'))],broker['id'],owner['id']))
    movement('COMMISSION_SETTLEMENT',payload('5000.00',[alloc(claim(btrip,'BROKER_COMMISSION_PAYABLE'),'5000.00',claim(btrip,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id']))
    ok('AT-05 broker cash85000 all balanceszero costonce reimbursementnotbrokerage',all(v=='0.00' for v in balances(btrip).values()) and costs(btrip)[1]['vehicle_cost']=='10000.00' and sql(f"select count(*) from public.expenses where trip_id='{btrip['id']}';")=='1')
    def profit(t):return Decimal(sql(f"select coalesce(sum(-l.signed_amount),0)::numeric(38,2)::text from public.journal_lines l join public.financial_events f on f.id=l.event_id where l.trip_id='{t['id']}' and f.kind='DISPATCH' and l.account_purpose='OWNER_PAYABLE';"))-Decimal(costs(t)[1]['owner_cost'])
    def owner_cash(t):return sql(f"select coalesce(sum(a.amount),0)::numeric(38,2)::text from public.allocations a join public.financial_events f on f.id=a.event_id where a.trip_id='{t['id']}' and f.kind='OWNER_SETTLEMENT';")
    ok('AT-05 both actual earned owner profits85000 and cash95000 versus85000',profit(a)==profit(btrip)==Decimal('85000.00') and owner_cash(a)=='95000.00' and owner_cash(btrip)=='85000.00')

    held=dispatch(draft());collect(held);p=ep(held,'HELD_TRIP_FUNDS',broker['id'],allocations=[ea(claim(held,'OWNER_PAYABLE'),'10000.00'),ea(claim(held,'CUSTODY_RECEIVABLE'),'10000.00','CASH')]);he=success('T09 held funds diesel',expense(p))
    ok('T09 held funds debitdue creditcustody no reimbursement',balances(held)['OWNER_PAYABLE']=='-85000.00' and balances(held)['CUSTODY_RECEIVABLE']=='90000.00' and 'EXPENSE_REIMBURSEMENT_PAYABLE' not in balances(held))
    ok('T09 competing stale expense held claim denied',expense(p)[0]==409)
    denied=copy.deepcopy(p);denied['offset_confirmed']=False;ok('T09 unreviewed owner offset denied',expense(denied)[0]==400)
    unrelated=dispatch(draft());bad=ep(unrelated,'PERSONAL_FUNDS',broker['id'],allocations=[ea(claim(held,'OWNER_PAYABLE'),'10000.00')]);ok('T09 cross-trip direct claim denied',expense(bad)[0]==403)
    for tok in [None,xt]:ok('T09 anonymous/outside expense denied',expense(ep(unrelated),tok)[0] in (401,403))
    dest=success('T09 destination can record trip cost',expense(ep(unrelated,office=1),dt))
    ok('T09 direct expense insert denied',env['request']('/rest/v1/expenses',{},st)[0]==403)
    ok('T09 direct confirmed edit denied',env['request']('/rest/v1/expenses?id=eq.'+e['record_id'],{'amount':'1.00'},st,method='PATCH')[0]==403)
    for value in ['1.001',-1,'-1.00','0.00','10000000000000000.00']:
        q=ep();q['amount']=value;ok('T09 strict money denied',expense(q)[0]==400)
    q=ep();q['actor_id']=uid();ok('T09 actor spoof denied',expense(q)[0]==400)
    # Maintenance is explicitly unlinked. A different bearer has cost recovery,
    # not a hidden owner entitlement deduction or a second cost at reimbursement.
    maintenance=success('AT-19 standalone personally owner maintenance',expense(ep(amount='2500.00')))
    different=success('AT-19 standalone other bearer personal advance',expense(ep(funding='PERSONAL_FUNDS',payer=broker['id'],bearer=other['id'],amount='3000.00')))
    ec=success('T09 standalone expense claims',rpc('get_expense_claims',{'expense_id':different['record_id']},st));rc=next(x for x in ec if x['account_purpose']=='PARTY_COST_RECOVERY')
    wrong=payload('3000.00',[alloc(rc,'3000.00')],other['id'],broker['id'],office=1);ok('T09 standalone recovery cannot reassign journal visibility office',post(wrong,at,kind='EXPENSE_RECOVERY')[0]==403)
    movement('EXPENSE_RECOVERY',payload('3000.00',[alloc(rc,'3000.00')],other['id'],broker['id']))
    ec=rpc('get_expense_claims',{'expense_id':different['record_id']},st)[1];re=next(x for x in ec if x['account_purpose']=='EXPENSE_REIMBURSEMENT_PAYABLE');cu=next(x for x in ec if x['account_purpose']=='CUSTODY_RECEIVABLE')
    wrong=payload('3000.00',[alloc(re,'3000.00',cu)],broker['id'],broker['id'],office=1);ok('T09 standalone reimbursement cannot move journal metadata to another office',post(wrong,at,kind='REIMBURSEMENT')[0]==403)
    movement('REIMBURSEMENT',payload('3000.00',[alloc(re,'3000.00',cu)],broker['id'],broker['id']))
    ok('T09 standalone expense journals hidden from destination-only staff',env['request']('/rest/v1/journal_lines?select=expense_id,signed_amount&expense_id=eq.'+different['record_id'],token=dt,method='GET')==(200,[]))
    ok('AT-19 standalone recovery/reimbursement leaves no claims',rpc('get_expense_claims',{'expense_id':different['record_id']},st)==(200,[]))
    ok('AT-19 expense month includes maintenance and trip costs once',costs()[1]['vehicle_cost']=='45500.00' and costs()[1]['owner_cost']=='42500.00')
    ok('AT-19 standalone does not increase lifetime trip cost',costs(a)[1]['vehicle_cost']=='10000.00')
    ok('T09 standalone hidden from other offices',rpc('get_expense_claims',{'expense_id':different['record_id']},dt)[0]==403 and rpc('get_expense_claims',{'expense_id':different['record_id']},xt)[0]==403)
    early=draft();p=ep(early,'PERSONAL_FUNDS',broker['id']);p['effective_date']='2026-01-20';ee=success('T09 draft expense personal advance',expense(p));early=dispatch(early)
    ec=rpc('get_expense_claims',{'expense_id':ee['record_id']},st)[1];cost_claim=next(x for x in ec if x['account_purpose']=='PARTY_COST_RECOVERY')
    op=payload('10000.00',[alloc(cost_claim,'10000.00',claim(early,'OWNER_PAYABLE'))],owner['id'],owner['id']);rid=uid();result=movement('EXPENSE_OFFSET',op,rid=rid)
    ok('T09 explicit later offset consumes original expense once',post(op,rid=rid,kind='EXPENSE_OFFSET')==(200,result) and post(op,kind='EXPENSE_OFFSET')[0]==409 and balances(early)['OWNER_PAYABLE']=='-85000.00' and costs(early)[1]['vehicle_cost']=='10000.00')
    excess=dispatch(draft());xe=success('T09 expense above owner entitlement',expense(ep(excess,'PERSONAL_FUNDS',broker['id'],amount='100000.00',allocations=[ea(claim(excess,'OWNER_PAYABLE'),'95000.00')])))
    ok('T09 excess cost creates recovery no overconsumed owner claim',balances(excess)['OWNER_PAYABLE']=='0.00' and balances(excess)['PARTY_COST_RECOVERY']=='5000.00' and balances(excess)['EXPENSE_REIMBURSEMENT_PAYABLE']=='-100000.00')
    month=rpc('get_expense_totals',{'vehicle_id':vehicle['id'],'from_date':'2026-01-01','to_date':'2026-01-31'},at)
    ok('AT-19 expense date basis includes January draft cost',month[1]['vehicle_cost']=='10000.00' and costs(early)[1]['date_basis']=='LIFETIME_TRIP')
    # Two independent expense commands compete for exactly one earned claim.
    race=dispatch(draft());q=ep(race,'PERSONAL_FUNDS',broker['id'],amount='95000.00',allocations=[ea(claim(race,'OWNER_PAYABLE'),'95000.00')])
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:expense(q),range(2)))
    ok('T09 concurrent expense offset exactly one winner',sorted(x[0] for x in results)==[200,409] and costs(race)[1]['vehicle_cost']=='95000.00')
    full=dispatch(draft());full_request=uid();fp=ep(full,'PERSONAL_FUNDS',broker['id'],amount='95000.00',allocations=[ea(claim(full,'OWNER_PAYABLE'),'95000.00')]);fr=success('T09 full offset initial posting',expense(fp,rid=full_request))
    ok('T09 full consumed owner offset identical retry returns committed result',expense(fp,rid=full_request)==(200,fr))
    collect(early);ec=rpc('get_expense_claims',{'expense_id':ee['record_id']},st)[1];rep=next(x for x in ec if x['account_purpose']=='EXPENSE_REIMBURSEMENT_PAYABLE');rp=payload('10000.00',[alloc(rep,'10000.00',claim(early,'CUSTODY_RECEIVABLE'))],broker['id'],broker['id'])
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:post(rp,kind='REIMBURSEMENT'),range(2)))
    ok('T09 competing reimbursements consume original expense once',sorted(x[0] for x in results)==[200,409] and costs(early)[1]['vehicle_cost']=='10000.00')
    retry=ep();rr=uid()
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:expense(retry,rid=rr),range(2)))
    ok('T09 concurrent duplicate UUID one expense',results[0]==results[1] and results[0][0]==200)
    # Evidence posts independently, with actual byte signatures, size and RLS.
    raw=b'\x89PNG\r\n\x1a\nsynthetic-T09-evidence'; arid=uid();attachment={'expense_id':be['record_id'],'request_id':arid,'expected_version':1,'mime_type':'image/png','base64':base64.b64encode(raw).decode()}
    def upload(a,token=st):return env['request']('/functions/v1/expense-receipts',a,token)
    for token in [None,xt]:ok('AT-20 unauthenticated/outside upload denied',upload(attachment,token)[0]>=400)
    for mime,data in [('image/png',b'not-a-png'),('text/plain',raw),('application/pdf',raw),('image/png',b'\x89PNG\r\n\x1a\n'+b'x'*5242880)]:
        q=dict(attachment,mime_type=mime,base64=base64.b64encode(data).decode());ok('AT-20 unsupported mismatched oversized receipt rejected',upload(q)[0]>=400)
    # Force a genuine Storage failure, not merely an invalid client input.
    failpath=b+'/'+be['record_id']+'/'+arid
    sql(f"create function public.t09_storage_failure() returns trigger language plpgsql as $$ begin if new.name='{failpath}' then raise exception 'SYNTHETIC_STORAGE_FAILURE';end if;return new;end $$;create trigger t09_storage_failure before insert on storage.objects for each row execute function public.t09_storage_failure();")
    try:
        failed=upload(attachment);ok('AT-20 actual storage failure separate from posted expense',failed[0]==503 and failed[1]['financial_status']=='UNCHANGED' and costs(btrip)[1]['vehicle_cost']=='10000.00' and sql(f"select count(*) from public.expense_evidence where expense_id='{be['record_id']}';")=='0')
    finally:sql('drop trigger t09_storage_failure on storage.objects;drop function public.t09_storage_failure();')
    attached=success('AT-20 real private receipt attached',upload(attachment));path=attached['object_path']
    ok('AT-20 attachment retry same object reference',upload(attachment)==(200,attached) and sql(f"select count(*) from public.expense_evidence where expense_id='{be['record_id']}';")=='1')
    for token,allowed in [(st,True),(dt,True),(xt,False),(None,False)]:ok('AT-20 live authenticated private download', (env['request']('/storage/v1/object/authenticated/receipts/'+path,token=token,method='GET')[0]==200)==allowed)
    ok('AT-20 receipt bytes hash verified',sql(f"select sha256 from public.receipt_files where id='{attached['receipt_id']}';")==hashlib.sha256(raw).hexdigest())
    ok('AT-20 signed URL forbidden',env['request']('/storage/v1/object/sign/receipts/'+path,{'expiresIn':3600},st)[0]>=400)
    q=dict(attachment,request_id=uid());failed=upload(q);ok('AT-20 second attachment conflict financial result unchanged',failed[0]==409 and failed[1]['financial_status']=='UNCHANGED' and costs(btrip)[1]['vehicle_cost']=='10000.00')
    orphanpath=b+'/'+be['record_id']+'/'+q['request_id']
    sql(f"update storage.objects set created_at=now()-interval '25 hours' where bucket_id='receipts' and name in('{path}','{orphanpath}');")
    ok('AT-20 staff cannot clean abandoned evidence',env['request']('/functions/v1/expense-receipts',{'action':'cleanup'},st)[0]==403)
    clean=success('AT-20 administrator cleans only abandoned uploads',env['request']('/functions/v1/expense-receipts',{'action':'cleanup'},at));ok('AT-20 referenced receipt retained orphan removed',clean['removed_abandoned']==1 and env['request']('/storage/v1/object/authenticated/receipts/'+path,token=st,method='GET')[0]==200 and sql(f"select count(*) from storage.objects where bucket_id='receipts' and name='{orphanpath}';")=='0')
    ok('AT-20 cleaned abandoned retry cannot attach',upload(q)[0]>=400 and costs(btrip)[1]['vehicle_cost']=='10000.00')
    ca=dict(attachment,expense_id=maintenance['record_id'],request_id=uid())
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:upload(ca),range(2)))
    ok('AT-20 concurrent duplicate attachment one object reference',results[0]==results[1] and results[0][0]==200 and sql(f"select count(*) from public.expense_evidence where expense_id='{maintenance['record_id']}';")=='1')
    standalone_path=results[0][1]['object_path']
    ok('AT-20 standalone receipt not visible to destination-only staff',env['request']('/storage/v1/object/authenticated/receipts/'+standalone_path,token=dt,method='GET')[0]!=200)
    ra=dict(attachment,expense_id=dest['record_id'])
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:upload(dict(ra,request_id=uid())),range(2)))
    ok('AT-20 competing attachment requests keep exactly one link',sorted(x[0] for x in results)==[200,409] and sql(f"select count(*) from public.expense_evidence where expense_id='{dest['record_id']}';")=='1')
    ok('T09 attachment trusted finalize unavailable to ordinary clients',rpc('attach_expense_receipt',{'actor_claims':{},'expense_id':be['record_id'],'request_id':uid(),'expected_version':1,'mime_type':'image/png','byte_size':1,'sha256':'0'*64},st)[0]==403)
    # Deferred commit exception must roll back expense, journals, allocations,
    # audit and request cache; the same UUID is safe after remediation.
    target=dispatch(draft());q=ep(target,'PERSONAL_FUNDS',broker['id'],allocations=[ea(claim(target,'OWNER_PAYABLE'),'10000.00')]);rid=uid()
    sql("create function public.t09_fail_commit() returns trigger language plpgsql as $$ begin if new.kind='EXPENSE' then raise exception 'SYNTHETIC_COMMIT_FAILURE';end if;return new;end $$;create constraint trigger t09_fail_commit after insert on public.financial_events deferrable initially deferred for each row execute function public.t09_fail_commit();")
    try:
        r=expense(q,rid=rid);ok('T09 deferred commit rollback no successful response',r[0]>=400 and costs(target)[1]['vehicle_cost']=='0.00' and sql(f"select count(*) from public.idempotency_records where request_id='{rid}';")=='0' and balances(target)['OWNER_PAYABLE']=='-95000.00')
    finally:sql('drop trigger t09_fail_commit on public.financial_events;drop function public.t09_fail_commit();')
    success('T09 original UUID retry after rollback',expense(q,rid=rid))
    ok('T09 all postings balanced',sql(f"select count(*) from(select event_id from public.journal_lines where business_id='{b}' group by event_id having sum(signed_amount)<>0) q;")=='0')
    import sys,subprocess
    if '--native-expenses' in sys.argv:
        config_path=env['ROOT']/'tools/.local/t09-native-config.json'
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'expenses','TEST_PASSWORD':env['real'],'TEST_OFFICE_ID':offices[0]}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t09-native-expenses.log').open('w',encoding='utf-8') as log:
                built=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/expenses_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('T09 real Windows expense and private receipt UI',built.returncode==0)
            ok('T09 native expense independently persisted once',sql(f"select count(*) from public.expenses x join public.expense_evidence e on e.expense_id=x.id where x.business_id='{b}' and x.notes='Synthetic native T09 expense' and x.amount=1234.56 and x.trip_id is null and x.funding_source='SELF_FUNDED_COST';")=='1')
        finally:config_path.unlink(missing_ok=True)
        st=success('T09 fresh session after native global logout',env['login']('expenses',env['real']))['access_token']
    old_totals=costs()[1];newowner=master('PARTY',{'code':'T09-replacement-owner','display_name':'Synthetic replacement owner','roles':['OWNER'],'contact_details':{},'archived':False})
    success('T09 master vehicle owner changed',rpc('save_master_record',{'kind':'VEHICLE','target_id':vehicle['id'],'request_id':uid(),'expected_version':vehicle['version'],'payload':{'registration':'T09-SYNTHETIC','current_owner_id':newowner['id'],'default_driver_id':None,'archived':False}},at))
    ok('AT-19 historical expense owner classification preserved',costs()[1]==old_totals and costs(a)[1]['owner_cost']=='10000.00')
    current=env['profile'](st);change={'target_id':current['id'],'expected_version':current['version'],'display_name':current['display_name'],'account_role':'STAFF','active':True,'office_ids':[]}
    success('T09 remove expense staff office',rpc('admin_manage_staff',change,at))
    ok('AT-20 old JWT receipt denied after assignment removal',env['request']('/storage/v1/object/authenticated/receipts/'+path,token=st,method='GET')[0]!=200)
    ok('T09 old idempotent expense result denied after revocation',expense(p,st,rid)[0]==403)
    ok('T09 scoped receipt metadata absent after revocation',env['request']('/rest/v1/receipt_files?select=object_path',token=st,method='GET')==(200,[]))
    ok('T09 expense records stay immutable after receipt/reimbursement',sql(f"select version from public.expenses where id='{be['record_id']}';")=='1')
