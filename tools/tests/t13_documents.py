"""T13 real transactional issuance on empty-loopback managed-staff fixtures."""
import copy, hashlib, json, uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,off=env['b'],env['at'],env['office'];uid=lambda:str(uuid.uuid4())
    data=env['t11'];st=data['tokens'][1];peer=data['tokens'][2];customer,broker,owner=data['customer'],data['broker'],data['owner']
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    def master(kind,p):return success('T13 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    other=master('PARTY',{'code':'T13-OTHER','display_name':'FORBIDDEN-T13-CUSTOMER','roles':['CUSTOMER'],'contact_details':{},'archived':False})
    vehicle=master('VEHICLE',{'registration':'T13-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':None,'archived':False})
    trip=uid();review=success('T13 draft overlap review',rpc('review_trip_overlap',{'target_id':trip,'vehicle_id':vehicle['id'],'origin_office_id':off[0],'destination_office_id':off[1]},at))
    consignments=[{'id':uid(),'customer_id':p,'broker_id':broker['id'],'car_count':n,'quoted_amount':q,'quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':c,'notes':'T13 visible' if p==customer['id'] else 'FORBIDDEN-T13-NOTE','cars':[]} for p,n,q,c in [(customer['id'],1,'80000.00','4000.00'),(customer['id'],2,'20000.00','1000.00'),(other['id'],4,'50000.00','2500.00')]]
    payload={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':off[0],'destination_office_id':off[1],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic T13','reason':'Synthetic entry','stops':[],'consignments':consignments,'review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}
    t=success('T13 actual draft',rpc('save_trip',{'target_id':trip,'request_id':uid(),'expected_version':0,'payload':payload},at))
    review=success('T13 dispatch review',rpc('review_trip_overlap',{'target_id':trip,'vehicle_id':vehicle['id'],'origin_office_id':off[0],'destination_office_id':off[1],'planned_dispatch_date':'2026-01-10'},at))
    t=success('T13 actual dispatch',rpc('dispatch_trip',{'target_id':trip,'request_id':uid(),'expected_version':t['version'],'payload':{'dispatch_date':'2026-01-10','reason':'Synthetic dispatch','review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}},at))
    filters={'from':'2026-01-01','to':'2026-12-31','trip_id':trip}
    catalogue=success('T13 invoice catalogue',rpc('get_output_catalogue',{'report_kind':'CUSTOMER_INVOICE','recipient_kind':'CUSTOMER'},st))
    fields=[f['field_key'] for f in catalogue['fields']]
    command={'report_kind':'CUSTOMER_INVOICE','recipient_kind':'CUSTOMER','recipient_id':customer['id'],'filters':filters,'field_order':fields,'format_options':{'orientation':'LANDSCAPE','sheet_name':'Invoice'},'preset_id':None,'event_id':None,'supersedes_id':None,'reason':None}
    def issue(p=command,request=None,token=None):return rpc('issue_document',{'request_id':request or uid(),'expected_version':0,'payload':p},token or st)
    def get(id,token=None):return rpc('get_issued_document',{'document_id':id},token or st)
    def counts():return sql(f"select (select count(*) from public.issued_documents where business_id='{b}')||':'||(select coalesce(sum(last_number),0) from public.document_sequences where business_id='{b}')||':'||(select count(*) from private.document_requests where business_id='{b}')||':'||(select count(*) from private.document_sources where business_id='{b}')||':'||(select count(*) from public.audit_events where business_id='{b}' and record_type='DOCUMENT');")
    sql(f"update public.businesses set setup_completed=false,version=version+1 where id='{b}';")
    before=counts();missing=issue();
    if missing[0]!=400:raise AssertionError('Missing setup response: '+repr(missing))
    ok('AT26 missing company setup rejects inside issuance',counts()==before)
    version=int(sql(f"select version from public.businesses where id='{b}';"))
    success('T13 explicit company setup',rpc('save_master_record',{'kind':'COMPANY','target_id':b,'request_id':uid(),'expected_version':version,'payload':{'name':'Synthetic T13 Company','contact_details':{'phone':'FORBIDDEN-T13-CONTACT'}}},at))
    rid=uid();first=success('AT26 first actual issuance',issue(request=rid));snap=copy.deepcopy(first['snapshot']);digest=first['content_digest']
    ok('AT26 permanent server number and Pakistan issue date',first['permanent_number'].startswith('INV-') and snap['metadata']['document_number']==first['permanent_number'] and sql(f"select permanent_number='INV-'||issue_year::text||'-000001' and issue_year=extract(year from issued_at at time zone 'Asia/Karachi') from public.issued_documents where id='{first['id']}';")=='t')
    ok('AT26 canonical digest independently matches SHA256',hashlib.sha256(first['canonical_content'].encode('utf-8')).hexdigest()==digest and json.loads(first['canonical_content'])==snap)
    ok('AT26 customer-per-trip grouping excludes unrelated loads',snap['totals']['invoice_total']=='100000.00' and len(snap['rows'])==1 and snap['rows'][0]['car_count']==3 and 'FORBIDDEN-T13' not in json.dumps(snap))
    ok('AT26 selected configuration and template captured',snap['field_order']==fields and snap['format_options']['orientation']=='LANDSCAPE' and first['template_version']==first['schema_version']==1 and snap['issued'] is True)
    ok('AT26 duplicate exact request returns one document',issue(request=rid)==(200,first) and sql(f"select count(*) from private.document_requests where request_id='{rid}';")=='1')
    ok('AT26 request reuse with changed body or actor denied',issue(command|{'format_options':{'orientation':'AUTO'}},rid)[0]==409 and issue(request=rid,token=peer)[0]==409)
    with ThreadPoolExecutor(max_workers=5) as pool: concurrent=list(pool.map(lambda _:issue(),range(10)))
    ok('AT26 simultaneous different issuance commits unique numbers',all(r[0]==200 for r in concurrent) and len({r[1]['permanent_number'] for r in concurrent})==10)
    same=uid()
    with ThreadPoolExecutor(max_workers=2) as pool: duplicate=list(pool.map(lambda _:issue(request=same),range(2)))
    ok('AT26 simultaneous duplicate issuance commits once',duplicate[0]==duplicate[1] and duplicate[0][0]==200 and sql(f"select count(*) from private.document_requests where request_id='{same}';")=='1')
    # Inject failure at COMMIT, after a complete candidate response has been assembled.
    sql(f"create function public.t13_fail_commit() returns trigger language plpgsql as $$ begin if new.business_id='{b}' then raise exception 'T13_COMMIT_FAILURE';end if;return null;end $$;create constraint trigger t13_commit_failure after insert on public.issued_documents deferrable initially deferred for each row execute function public.t13_fail_commit();")
    rollback=uid();before=counts()
    try:
        failed=issue(request=rollback);ok('AT26 deferred commit failure reports failure',failed[0]>=400 and failed[1].get('message')=='T13_COMMIT_FAILURE')
        ok('AT26 rollback preserves sequence snapshots sources audit and retry records',counts()==before)
    finally:sql('drop trigger t13_commit_failure on public.issued_documents;drop function public.t13_fail_commit();')
    retried=success('AT26 exact rollback retry commits normally',issue(request=rollback))
    ok('AT26 permanent numbers and original records cannot be reused',sql(f"select count(*)=count(distinct permanent_number) from public.issued_documents where business_id='{b}';")=='t')
    for token in [st,at]:
        for table in ['issued_documents','document_sequences']:
            for method in ['GET','POST','PATCH','DELETE']:ok('AT26 direct document/sequence access denied',env['request']('/rest/v1/'+table+('?id=not.is.null' if method!='POST' else ''),{} if method in('POST','PATCH') else None,token,method=method)[0]==403)
    outside=success('T13 unrelated staff login',env['login']('outside',env['real']))['access_token']
    ok('AT26 unrelated direct issue/read/list filter denied',issue(token=outside)[0]==403 and get(first['id'],outside)[0]==403 and rpc('list_issued_documents',{'filters':{'trip_id':trip}},outside)[0]==403)
    ok('AT26 unrelated list reveals no documents',success('T13 unrelated scoped list',rpc('list_issued_documents',{},outside))['rows']==[])
    ok('AT26 anonymous issue and snapshot read denied',issue(token=env['anon'])[0] in(401,403) and get(first['id'],env['anon'])[0] in(401,403))
    for change in [{'issuer_staff_id':env['ap']['id']},{'snapshot':{'invoice_total':'0.01'}},{'permanent_number':'INV-SPOOF'},{'company_name':'Spoof'}]:ok('AT26 injected identity/number/content denied',issue(command|change)[0]==400)
    ok('AT26 forbidden field cannot enter an issued snapshot',issue(command|{'field_order':fields+['brokerage']})[0]==403)
    # Real receipt creation and its separately numbered, redacted snapshot.
    claims=success('T13 current trip financials',rpc('get_trip_financials',{'trip_id':trip},st))['claims'];claim=next(c for c in claims if c['account_purpose']=='CUSTOMER_RECEIVABLE' and c['consignment_id']==consignments[0]['id'])
    receipt=success('T13 actual customer receipt',rpc('post_financial_event',{'event_kind':'CUSTOMER_RECEIPT','request_id':uid(),'expected_version':0,'payload':{'payer_id':customer['id'],'payee_id':broker['id'],'office_id':off[0],'effective_date':'2026-03-05','amount':'10000.00','reason':'Synthetic T13 receipt','allocations':[{'target_line_id':claim['line_id'],'target_version':claim['version'],'amount':'10000.00'}]}},st))
    rc=success('T13 customer receipt catalogue',rpc('get_output_catalogue',{'report_kind':'PAYMENT_RECEIPT','recipient_kind':'CUSTOMER'},st))
    rcmd=command|{'report_kind':'PAYMENT_RECEIPT','field_order':rc['defaults'],'event_id':receipt['record_id']}
    rdoc=success('AT26 actual payment receipt issuance',issue(rcmd));ok('AT26 receipt has independent sequence and payment date',rdoc['permanent_number'].startswith('RCP-') and rdoc['snapshot']['totals']['receipt_amount']=='10000.00' and rdoc['snapshot']['rows'][0]['payment_date']=='2026-03-05')
    # Preset is presentation only; changing it cannot change a stored issued configuration.
    preset=uid();pp={'name':'Synthetic T13 invoice','shared':False,'report_kind':'CUSTOMER_INVOICE','recipient_kind':'CUSTOMER','field_order':fields,'format_options':{'orientation':'LANDSCAPE','sheet_name':'Invoice'}}
    success('T13 invoice preset create',rpc('save_output_preset',{'target_id':preset,'request_id':uid(),'expected_version':0,'payload':pp},st))
    from_preset=success('T13 issue from current preset',issue(command|{'field_order':None,'preset_id':preset}))
    required=[f['field_key'] for f in catalogue['fields'] if f['required']]
    success('AT27 change preset fields and formatting',rpc('save_output_preset',{'target_id':preset,'request_id':uid(),'expected_version':1,'payload':pp|{'field_order':required,'format_options':{'orientation':'PORTRAIT','sheet_name':'Changed'}}},st))
    version=int(sql(f"select version from public.businesses where id='{b}';"));success('AT27 company name change',rpc('save_master_record',{'kind':'COMPANY','target_id':b,'request_id':uid(),'expected_version':version,'payload':{'name':'Changed T13 Company','contact_details':{}}},at))
    p=env['profile'](st);success('AT27 issuer display-name change revokes old session',rpc('admin_manage_staff',{'target_id':p['id'],'expected_version':p['version'],'display_name':'Changed T13 Issuer','account_role':'STAFF','active':True,'office_ids':[off[0]]},at))
    st=success('T13 changed issuer fresh login',env['login']('reports1',env['real']))['access_token']
    cv=int(sql(f"select version from public.parties where id='{customer['id']}';"));success('AT27 recipient display-name change',rpc('save_master_record',{'kind':'PARTY','target_id':customer['id'],'request_id':uid(),'expected_version':cv,'payload':{'display_name':'Changed T13 Customer','roles':['CUSTOMER'],'contact_details':{},'archived':False}},at))
    review=success('T13 actual cancellation fee review',rpc('review_cancellation',{'trip_id':trip},at))
    success('AT27 source fare changes through retained cancellation adjustment',rpc('cancel_and_adjust',{'trip_id':trip,'request_id':uid(),'expected_version':t['version'],'payload':{'reason':'Synthetic agreed corrected fee','review_token':review['review_token'],'effective_date':'2026-04-01','consignments':[{'id':c['id'],'quoted_amount':'10000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'1000.00'} for c in consignments]}},at))
    old=success('AT27 reprint old snapshot',get(first['id']));old_preset=success('AT27 reprint original preset snapshot',get(from_preset['id']))
    ok('AT27 company issuer recipient fare preset changes leave old snapshot/digest unchanged',old['snapshot']==snap and old['content_digest']==digest and old_preset['snapshot']==from_preset['snapshot'])
    superseding=command|{'supersedes_id':first['id'],'reason':'Corrected source fee and display labels'}
    ok('AT26 other staff cannot supersede someone else document',issue(superseding,token=peer)[0]==403)
    replacement=success('AT26 explicit linked supersession',issue(superseding));ok('AT27 replacement captures new source and display values',replacement['snapshot']['totals']['invoice_total']=='20000.00' and replacement['snapshot']['metadata']['company_name']=='Changed T13 Company' and replacement['snapshot']['metadata']['issuer_name']=='Changed T13 Issuer' and replacement['snapshot']['metadata']['recipient_name']=='Changed T13 Customer')
    ok('AT26 supersession links and originals retained',replacement['supersedes_number']==first['permanent_number'] and get(first['id'])[1]['superseded_by_number']==replacement['permanent_number'] and get(first['id'])[1]['snapshot']==snap)
    ok('AT26 original issuance retry remains exact after later supersession',issue(request=rid)==(200,first))
    ok('AT26 original can only be superseded once',issue(superseding)[0]==409)
    # Competing supersessions of another leaf serialize, one remains rejected.
    leaf=concurrent[0][1]['id'];sup=command|{'supersedes_id':leaf,'reason':'Concurrent synthetic correction'}
    with ThreadPoolExecutor(max_workers=2) as pool:races=list(pool.map(lambda _:issue(sup),range(2)))
    ok('AT26 simultaneous supersession creates one replacement',sorted(r[0] for r in races)==[200,409])
    before=sql(f"select count(*) from public.financial_events where business_id='{b}';")
    success('T13 read issued receipt after fare change',get(rdoc['id']));ok('T13 issuance/reprint never create receipts or journals',sql(f"select count(*) from public.financial_events where business_id='{b}';")==before)
    # Keep the authorized snapshot available to the later T14 test module.
    env['t13']={'token':st,'trip':trip,'customer':customer,'vehicle':vehicle,'original':first,'replacement':replacement,'receipt':rdoc,'command':command}
    import sys
    if '--native-documents' in sys.argv:
        cfg=env['ROOT']/'tools/.local/t13-native-config.json';cfg.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'reports2','TEST_PASSWORD':env['real'],'TEST_TRIP_ID':trip,'TEST_CUSTOMER_ID':customer['id']}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t13-native.log').open('w',encoding='utf-8') as log:result=env['subprocess'].run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/documents_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(cfg)],cwd=env['ROOT']/'app',stdout=log,stderr=env['subprocess'].STDOUT)
            ok('T13 actual Windows issuance and snapshot UI',result.returncode==0)
            ok('T13 native issued document committed independently',sql(f"select count(*) from public.issued_documents where business_id='{b}' and issuer_staff_id=(select id from public.staff_profiles where business_id='{b}' and username='reports2');")=='1')
        finally:cfg.unlink(missing_ok=True)
    p=env['profile'](st);success('T13 reassign issuer to unrelated office',rpc('admin_manage_staff',{'target_id':p['id'],'expected_version':p['version'],'display_name':p['display_name'],'account_role':'STAFF','active':True,'office_ids':[off[2]]},at))
    ok('AT26 old session cannot reprint after revoked access',get(first['id'])[0]==403)
    fresh=success('T13 new session after access change',env['login']('reports1',env['real']))['access_token']
    ok('AT26 fresh session cannot reprint or retry issue to restore old office',get(first['id'],fresh)[0]==403 and issue(request=rid,token=fresh)[0]==403)
    print('T13 AT-26/27 issuance, snapshots, authorization and rollback PASS',flush=True)
