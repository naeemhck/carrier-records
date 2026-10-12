"""T12 real HTTP recipient redaction, preset isolation and presentation invariance."""
import copy,json,uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,off=env['b'],env['at'],env['office'];uid=lambda:str(uuid.uuid4());data=env['t11'];st=data['token'];peer=data['tokens'][1];owner,customer,broker=data['owner'],data['customer'],data['broker']
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    def master(kind,p):return success('T12 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    other=master('PARTY',{'code':'T12-OTHER','display_name':'FORBIDDEN-CUSTOMER-T12','roles':['CUSTOMER'],'contact_details':{},'archived':False});otherbroker=master('PARTY',{'code':'T12-OTHERBROKER','display_name':'FORBIDDEN-BROKER-T12','roles':['BROKER'],'contact_details':{},'archived':False})
    vehicle=master('VEHICLE',{'registration':'T12-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False});trip,c1,c2,e1,e2,s1,s2= [uid() for _ in range(7)]
    sql(f"""begin;
    insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,owner_id,owner_snapshot,load_kind,state,dispatch_date,created_by) values('{trip}','{b}','T12-SYNTHETIC','{vehicle['id']}','{off[0]}','{off[1]}','{owner['id']}',jsonb_build_object('display_name','Synthetic T11 OWNER'),'LOADED','DISPATCHED','2026-01-20','{env['admin']}');
    insert into public.stops(id,business_id,trip_id,position,kind,address) values('{s1}','{b}','{trip}',1,'PICKUP','VISIBLE-T12-STOP'),('{s2}','{b}','{trip}',2,'DROP','FORBIDDEN-T12-STOP');
    insert into public.consignments(id,business_id,trip_id,customer_id,broker_id,car_count,quoted_amount,quote_mode,commission_method,commission_value,commission,customer_charge,owner_entitlement,notes) values('{c1}','{b}','{trip}','{customer['id']}','{broker['id']}',1,80000,'DEDUCTED','FIXED',4000,4000,80000,76000,'VISIBLE-T12-NOTES'),('{c2}','{b}','{trip}','{other['id']}','{otherbroker['id']}',2,20000,'DEDUCTED','FIXED',1000,1000,20000,19000,'FORBIDDEN-T12-NOTES');
    insert into public.consignment_cars(business_id,trip_id,consignment_id,identifier,pickup_stop_id,drop_stop_id) values('{b}','{trip}','{c1}','VISIBLE-T12-CAR','{s1}',null),('{b}','{trip}','{c2}','FORBIDDEN-T12-CAR',null,'{s2}');
    insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id) values('{e1}','{b}','DISPATCH','2026-01-20','{env['ap']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}',80000,'{uid()}'),('{e2}','{b}','DISPATCH','2026-01-20','{env['ap']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}',20000,'{uid()}');
    insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount) values
    ('{b}','{e1}','{customer['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}','CUSTOMER_RECEIVABLE',80000),('{b}','{e1}','{owner['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}','OWNER_PAYABLE',-76000),('{b}','{e1}','{broker['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}','BROKER_COMMISSION_PAYABLE',-4000),
    ('{b}','{e2}','{other['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}','CUSTOMER_RECEIVABLE',20000),('{b}','{e2}','{owner['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}','OWNER_PAYABLE',-19000),('{b}','{e2}','{otherbroker['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}','BROKER_COMMISSION_PAYABLE',-1000);commit;""")
    def post(kind,p):return success('T12 actual '+kind,rpc('post_financial_event',{'event_kind':kind,'request_id':uid(),'expected_version':0,'payload':p},st))
    def claim(purpose,party=None,consignment=None):return next(c for c in success('T12 current claim',rpc('get_trip_financials',{'trip_id':trip},st))['claims'] if c['account_purpose']==purpose and (party is None or c['party_id']==party) and (consignment is None or c['consignment_id']==consignment))
    def a(c,amount,source=None):
        result={'target_line_id':c['line_id'],'target_version':c['version'],'amount':amount}
        if source:result.update(source_line_id=source['line_id'],source_version=source['version'])
        return result
    receipt=post('CUSTOMER_RECEIPT',{'payer_id':customer['id'],'payee_id':broker['id'],'office_id':off[0],'effective_date':'2026-02-15','amount':'60000.00','reason':'Synthetic T12 cash','allocations':[a(claim('CUSTOMER_RECEIVABLE',customer['id'],c1),'60000.00')]})
    held=post('CUSTOMER_RECEIPT',{'payer_id':customer['id'],'payee_id':owner['id'],'office_id':off[0],'effective_date':'2026-02-16','amount':'20000.00','reason':'Synthetic owner custody, not settlement','allocations':[a(claim('CUSTOMER_RECEIVABLE',customer['id'],c1),'20000.00')]})
    settled=post('OWNER_SETTLEMENT',{'payer_id':broker['id'],'payee_id':owner['id'],'office_id':off[0],'effective_date':'2026-02-20','amount':'55000.00','reason':'Synthetic owner settlement','allocations':[a(claim('OWNER_PAYABLE',owner['id'],c1),'55000.00',claim('CUSTODY_RECEIVABLE',broker['id'],c1))]})
    post('EXPENSE',{'vehicle_id':vehicle['id'],'trip_id':trip,'office_id':off[0],'category_id':data['category']['id'],'effective_date':'2026-02-10','amount':'10000.00','payer_id':owner['id'],'cost_bearer_id':owner['id'],'funding_source':'SELF_FUNDED_COST','reason':'Synthetic T12 cost','allocations':[],'offset_confirmed':False})
    company=success('T12 current company',rpc('list_master_records',{'kind':'COMPANY'},at))[0]
    success('T12 explicit synthetic company setup',rpc('save_master_record',{'kind':'COMPANY','target_id':b,'request_id':uid(),'expected_version':company['version'],'payload':{'name':'Synthetic T12 Company','contact_details':{}}},at))
    def cat(report,recipient,token=st):return success('AT23 eligible '+report+'/'+recipient,rpc('get_output_catalogue',{'report_kind':report,'recipient_kind':recipient},token))
    base={'from':'2026-01-01','to':'2026-04-30','vehicle_id':vehicle['id']}
    def prepare(report,recipient,party=None,fields=None,filters=None,preset=None,event=None,token=st,options=None,offset=0):
        return rpc('prepare_output',{'report_kind':report,'recipient_kind':recipient,'recipient_id':party,'filters':filters or base,'field_order':fields,'format_options':options or {'orientation':'AUTO','sheet_name':'Records'},'preset_id':preset,'event_id':event,'page_offset':offset},token)
    oc=cat('OWNER_STATEMENT','OWNER');cc=cat('CUSTOMER_STATEMENT','CUSTOMER');bc=cat('BROKER_MONTHLY','BROKER');ic=cat('MONTHLY_VEHICLE','INTERNAL')
    keys=lambda c:[f['field_key'] for f in c['fields']]
    required=lambda c:[f['field_key'] for f in c['fields'] if f['required']]
    ok('AT23 owner catalogue excludes gross and brokerage',not({'customer_fare','brokerage','receipts','custody','operating_profit'}&set(keys(oc))))
    ok('AT23 customer catalogue excludes owner/internal cost and commission',not({'owner_earnings','owner_profit','owner_cost','vehicle_cost','brokerage','owner_due'}&set(keys(cc))))
    ok('AT23 broker excludes owner profitability',not({'owner_profit','operating_profit','owner_cost','vehicle_cost'}&set(keys(bc))))
    ok('AT23 stable groups/types/defaults/required',all(f['value_type'] in ['TEXT','MONEY','DATE','INTEGER','BOOLEAN'] and f['field_group'] in ['Identity','Journey','Cars','Charges','Expenses','Payments','Balances','Notes'] for c in [oc,cc,bc,ic] for f in c['fields']) and all(set(required(c))<=set(c['defaults']) for c in [oc,cc,bc,ic]))
    forbidden={'OWNER':{'customer_fare','brokerage','receipts','vehicle_cost','operating_profit'},'CUSTOMER':{'owner_earnings','owner_profit','owner_cost','vehicle_cost','brokerage','owner_due','commission_settled'},'BROKER':{'owner_profit','owner_cost','vehicle_cost','operating_profit'}}
    def allkeys(value):
        if isinstance(value,dict):return set(value)|set().union(*(allkeys(v) for v in value.values()))
        if isinstance(value,list):return set().union(*(allkeys(v) for v in value)) if value else set()
        return set()
    snapshots={}
    for report,recipient,party,catalogue in [('OWNER_STATEMENT','OWNER',owner['id'],oc),('CUSTOMER_STATEMENT','CUSTOMER',customer['id'],cc),('BROKER_MONTHLY','BROKER',broker['id'],bc)]:
        full=success('AT23 all-permitted '+recipient,prepare(report,recipient,party,keys(catalogue)));small=success('AT24 minimum '+recipient,prepare(report,recipient,party,required(catalogue)))
        ok('AT24 hidden columns retain canonical accounting '+recipient,full['totals']==small['totals'] and full['metadata']['period']==small['metadata']['period'] and full['metadata']['scope']==small['metadata']['scope'])
        ok('AT23 forbidden data absent recursively '+recipient,not(forbidden[recipient]&allkeys(full)))
        ok('AT24 selected fields and order only '+recipient,[f['field_key'] for f in full['fields']]==keys(catalogue) and all(set(row)=={f['field_key'] for f in catalogue['fields'] if not f['header']} for row in full['rows']))
        snapshots[recipient]=full
    ok('AT24 owner profit distinct from remaining settlement',snapshots['OWNER']['totals']['owner_profit']=='85000.00' and snapshots['OWNER']['totals']['owner_due']=='40000.00' and snapshots['OWNER']['totals']['owner_settled']=='55000.00')
    ok('AT23 own customer only including cars/stops/notes',snapshots['CUSTOMER']['totals']['customer_fare']=='80000.00' and snapshots['CUSTOMER']['totals']['receipts']=='80000.00' and snapshots['CUSTOMER']['rows'][0]['car_count']==1 and all(x not in json.dumps(snapshots['CUSTOMER']) for x in ['FORBIDDEN-CUSTOMER-T12','FORBIDDEN-BROKER-T12','FORBIDDEN-T12-CAR','FORBIDDEN-T12-STOP','FORBIDDEN-T12-NOTES']))
    ok('AT23 broker own commission only',snapshots['BROKER']['totals']['brokerage']=='4000.00' and 'FORBIDDEN-T12-CAR' not in json.dumps(snapshots['BROKER']))
    for report,recipient,party,c in [('OWNER_STATEMENT','OWNER',owner['id'],oc),('CUSTOMER_STATEMENT','CUSTOMER',customer['id'],cc),('BROKER_MONTHLY','BROKER',broker['id'],bc)]:
        for key in forbidden[recipient]:ok('AT25 direct forbidden field '+recipient+'/'+key,prepare(report,recipient,party,c['defaults']+[key])[0]==403)
    ok('AT23 required scope cannot be removed',prepare('OWNER_STATEMENT','OWNER',owner['id'],[k for k in oc['defaults'] if k!='scope'])[0]==400)
    ok('AT23 duplicate and unknown field reject',prepare('OWNER_STATEMENT','OWNER',owner['id'],oc['defaults']+['scope'])[0]==400 and prepare('OWNER_STATEMENT','OWNER',owner['id'],oc['defaults']+['actor_id'])[0]==403)
    ok('AT25 format/embedded payload injection reject',prepare('OWNER_STATEMENT','OWNER',owner['id'],oc['defaults'],options={'orientation':'AUTO','cached_data':{'brokerage':'999999'}})[0]==400)
    invoicecat=cat('CUSTOMER_INVOICE','CUSTOMER');invoice=success('AT23 customer-per-trip invoice preview',prepare('CUSTOMER_INVOICE','CUSTOMER',customer['id'],keys(invoicecat),filters=base|{'trip_id':trip}));ok('AT23 required invoice identity/total server-owned',invoice['metadata']['invoice_total']=='80000.00' and invoice['metadata']['company_name']=='Synthetic T12 Company' and invoice['metadata']['issuer_name']==env['profile'](st)['display_name'] and invoice['metadata']['document_number']=='Not issued — preview' and invoice['issued'] is False)
    ok('AT23 invoice required total cannot hide',prepare('CUSTOMER_INVOICE','CUSTOMER',customer['id'],[k for k in invoicecat['defaults'] if k!='invoice_total'],filters=base|{'trip_id':trip})[0]==400)
    rc=cat('PAYMENT_RECEIPT','OWNER');ownerreceipt=success('AT23 own settlement receipt preview',prepare('PAYMENT_RECEIPT','OWNER',owner['id'],rc['defaults'],event=settled['record_id']));ok('AT23 owner receipt excludes customer custody amount',ownerreceipt['totals']=={'receipt_amount':'55000.00'} and prepare('PAYMENT_RECEIPT','OWNER',owner['id'],rc['defaults'],event=held['record_id'])[0]==403)
    choices=success('T12 eligible owner receipt choices',rpc('list_output_receipts',{'recipient_kind':'OWNER','recipient_id':owner['id'],'filters':base,'page_offset':0},st));ok('AT23 picker excludes gross customer receipts',settled['record_id'] in {x['id'] for x in choices} and held['record_id'] not in {x['id'] for x in choices})
    pc={'name':'Synthetic personal T12','shared':False,'report_kind':'OWNER_STATEMENT','recipient_kind':'OWNER','field_order':oc['defaults'],'format_options':{'orientation':'LANDSCAPE','sheet_name':'Owner statement'}}
    pid=uid();rid=uid()
    def save(payload=pc,id=pid,request=None,version=0,token=st):return rpc('save_output_preset',{'target_id':id,'request_id':request or uid(),'expected_version':version,'payload':payload},token)
    first=success('AT25 personal preset save',save(request=rid));ok('T12 same preset UUID retry once',save(request=rid)==(200,first) and sql(f"select count(*) from public.output_presets where id='{pid}';")=='1')
    ok('T12 request UUID body mismatch',save(pc|{'name':'changed'},request=rid)[0]==409)
    ok('AT25 another staff personal preset denied',prepare('OWNER_STATEMENT','OWNER',owner['id'],preset=pid,token=peer)[0]==403)
    shared=pc|{'name':'Synthetic company T12','shared':True};sid=uid();success('AT25 admin shared preset',save(shared,sid,token=at))
    ok('AT25 staff shared save/rename/delete denied',save(shared,uid())[0]==403 and save(shared|{'name':'hacked'},sid,version=1)[0]==403 and rpc('delete_output_preset',{'target_id':sid,'request_id':uid(),'expected_version':1},st)[0]==403)
    listed=success('T12 own and shared presets listed',rpc('list_output_presets',{'report_kind':'OWNER_STATEMENT','recipient_kind':'OWNER'},st));otherlist=success('T12 peer only shared preset',rpc('list_output_presets',{'report_kind':'OWNER_STATEMENT','recipient_kind':'OWNER'},peer));ok('AT25 no ownership/Auth metadata or other personal presets',pid in {p['id'] for p in listed} and pid not in {p['id'] for p in otherlist} and sid in {p['id'] for p in otherlist} and not({'business_id','owner_staff_id','created_by','request_id'}&allkeys(listed)))
    used=success('AT24 shared preset revalidated preview',prepare('OWNER_STATEMENT','OWNER',owner['id'],preset=sid));ok('AT24 preset formatting never changes money',used['totals']==snapshots['OWNER']['totals'] and used['format_options']['orientation']=='LANDSCAPE')
    # Corrupt an old template only via trusted fixture SQL; ordinary writes remain denied.
    sql(f"update public.output_presets set version=version+1,field_order=array_append(field_order,'brokerage'),format_options=format_options||'{{\"cached_payload\":{{\"brokerage\":\"999999.00\"}}}}'::jsonb where id='{sid}';")
    stale=success('AT25 invalid preset list is sanitized',rpc('list_output_presets',{'report_kind':'OWNER_STATEMENT','recipient_kind':'OWNER'},st));bad=next(p for p in stale if p['id']==sid);ok('AT25 stale forbidden fields and cached data absent',bad['valid'] is False and 'field_order' not in bad and 'format_options' not in bad and '999999' not in json.dumps(stale))
    ok('AT25 malicious stale shared preset rejects on use',prepare('OWNER_STATEMENT','OWNER',owner['id'],preset=sid)[0]==403)
    success('T12 admin repair shared preset',save(shared,sid,version=2,token=at))
    renamed=success('T12 personal rename versioned',save(pc|{'name':'Renamed T12'},version=1));ok('T12 stale rename conflict',save(pc,version=1)[0]==409)
    results=list(ThreadPoolExecutor(max_workers=2).map(lambda n:save(pc|{'name':'Concurrent '+str(n)},version=renamed['version']),range(2)));ok('T12 concurrent preset update detects stale version',sorted(r[0] for r in results)==[200,409])
    current=next(p for p in success('T12 reload personal version',rpc('list_output_presets',{'report_kind':'OWNER_STATEMENT','recipient_kind':'OWNER'},st)) if p['id']==pid);dr=uid();delete={'target_id':pid,'request_id':dr,'expected_version':current['version']};deleted=success('T12 personal delete',rpc('delete_output_preset',delete,st));ok('T12 deletion retry is exact',rpc('delete_output_preset',delete,st)==(200,deleted))
    outside=success('T12 outside login',env['login']('outside',env['real']))['access_token'];ok('AT25 shared preset does not grant hidden trip',prepare('OWNER_STATEMENT','OWNER',owner['id'],filters=base|{'trip_id':trip},preset=sid,token=outside)[0]==403)
    for token in [st,at]:
        for table in ['output_presets','output_fields']:
            for method in ['POST','PATCH','DELETE']:ok('T12 direct catalogue/preset write denied',env['request']('/rest/v1/'+table+('?id=not.is.null' if method!='POST' else ''),{} if method!='DELETE' else None,token,method=method)[0]==403)
    before=sql(f"select (select count(*) from public.financial_events where business_id='{b}')||':'||(select count(*) from public.journal_lines where business_id='{b}')||':'||(select count(*) from public.allocations where business_id='{b}');")
    for c in [oc,cc,bc]:success('AT24 repeat redacted preview without posting',prepare(c['report_kind'],c['recipient_kind'],{'OWNER':owner['id'],'CUSTOMER':customer['id'],'BROKER':broker['id']}[c['recipient_kind']],required(c)))
    after=sql(f"select (select count(*) from public.financial_events where business_id='{b}')||':'||(select count(*) from public.journal_lines where business_id='{b}')||':'||(select count(*) from public.allocations where business_id='{b}');");ok('AT24 field visibility never changes accounting or issues documents',before==after and sql(f"select count(*) from public.issued_documents where business_id='{b}';")=='0')
    # A whole-trip advance has no consignment ID: it still belongs only to its actual customer.
    post('ADVANCE',{'payer_id':customer['id'],'payee_id':broker['id'],'office_id':off[0],'effective_date':'2026-03-01','amount':'123.45','reason':'Synthetic whole-trip advance','allocations':[{'trip_id':trip,'amount':'123.45'}]})
    advanced=success('T12 actual customer whole-trip advance preview',prepare('CUSTOMER_STATEMENT','CUSTOMER',customer['id'],cc['defaults']))
    stranger=success('T12 other customer excludes whole-trip advance',prepare('CUSTOMER_STATEMENT','CUSTOMER',other['id'],cc['defaults']))
    ok('AT25 whole-trip credits retain actual customer identity',advanced['totals']['customer_credit']=='123.45' and advanced['totals']['receipts']=='80123.45' and stranger['totals']['customer_credit']=='0.00' and stranger['totals']['receipts']=='0.00')
    ok('AT25 wrong recipient role denied',prepare('CUSTOMER_STATEMENT','CUSTOMER',owner['id'],cc['defaults'])[0]==403)
    # Isolated standalone costs provide more than one preview page, without altering the trip fixture.
    sql(f"""insert into public.vehicles(id,business_id,registration,current_owner_id) select md5('{b}-t12page-'||g)::uuid,'{b}','T12-PAGE-'||g,'{owner['id']}' from generate_series(1,61)g;
    insert into public.expenses(id,business_id,vehicle_id,office_id,category_id,owner_id,amount,payer_id,cost_bearer_id,funding_source,state,expense_date,created_by) select md5('{b}-t12expense-'||g)::uuid,'{b}',md5('{b}-t12page-'||g)::uuid,'{off[0]}','{data['category']['id']}','{owner['id']}',1,'{owner['id']}','{owner['id']}','SELF_FUNDED_COST','CONFIRMED','2025-06-10','{env['admin']}' from generate_series(1,61)g;""")
    pages={'from':'2025-06-01','to':'2025-06-30'}
    one=success('T12 preview page one',prepare('OWNER_STATEMENT','OWNER',owner['id'],oc['defaults'],filters=pages))
    two=success('T12 preview page two',prepare('OWNER_STATEMENT','OWNER',owner['id'],oc['defaults'],filters=pages,offset=50))
    ok('AT23 preview 50-row pages preserve totals and order',len(one['rows'])==50 and len(two['rows'])==11 and one['has_more'] and not two['has_more'] and one['totals']==two['totals'] and one['totals']['owner_cost']=='61.00' and not({r['record_name'] for r in one['rows']}&{r['record_name'] for r in two['rows']}))
    import sys
    if '--native-outputs' in sys.argv:
        config_path=env['ROOT']/'tools/.local/t12-native-config.json'
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'reports0','TEST_PASSWORD':env['real']}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t12-native.log').open('w',encoding='utf-8') as log:
                native=env['subprocess'].run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/outputs_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],cwd=env['ROOT']/'app',stdout=log,stderr=env['subprocess'].STDOUT)
            ok('T12 real Windows output preview and preset UI',native.returncode==0)
            ok('T12 native preset committed exactly once with hidden cost',sql(f"select count(*) from public.output_presets where business_id='{b}' and name='Synthetic native T12' and not shared and not('vehicle_cost'=any(field_order));")=='1')
        finally:config_path.unlink(missing_ok=True)
        st=success('T12 login after native logout',env['login']('reports0',env['real']))['access_token']
    p=env['profile'](st)
    success('T12 move staff away from historical trip office',rpc('admin_manage_staff',{'target_id':p['id'],'expected_version':p['version'],'display_name':p['display_name'],'account_role':'STAFF','active':True,'office_ids':[off[2]]},at))
    ok('AT25 old JWT and shared preset cannot restore revoked access',prepare('OWNER_STATEMENT','OWNER',owner['id'],filters=base|{'trip_id':trip},preset=sid,token=st)[0]==403)
    fresh=success('T12 fresh login after office reassignment',env['login']('reports0',env['real']))['access_token']
    ok('AT25 fresh session cannot restore old trip from shared preset',prepare('OWNER_STATEMENT','OWNER',owner['id'],filters=base|{'trip_id':trip},preset=sid,token=fresh)[0]==403)
    now=success('T12 current-scope shared preset excludes revoked records',prepare('OWNER_STATEMENT','OWNER',owner['id'],preset=sid,token=fresh))
    ok('AT25 reusable layout grants no historical-office access',now['rows']==[] and all(v=='0.00' for v in now['totals'].values()) and 'Assigned-office' in now['metadata']['scope'])
    env['t12']={'token':fresh,'shared_id':sid,'owner':owner,'vehicle':vehicle,'trip':trip}
