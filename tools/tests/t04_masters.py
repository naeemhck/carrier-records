"""T04 extension to the empty-local-database T03 API harness (--masters).
No identities or secrets are persisted. Trip/quote/document SQL fixtures are
explicitly test-only: T05 entry and T13 issuance are later tasks.
"""
import json
import uuid
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc, request, sql, ok = [env[k] for k in ('rpc','request','sql','ok')]
    b, at, office = [env[k] for k in ('b','at','office')]
    financial_count=sql(f"select count(*) from public.financial_events where business_id='{b}';")
    code, login = env['login']('destination', env['real'])
    ok('T04 staff login',code==200)
    st = login['access_token']
    uid = lambda: str(uuid.uuid4())
    def save(kind,payload,record=None,rid=None,version=None,token=at):
        return rpc('save_master_record',{'kind':kind,'target_id':record['id'] if record else uid(),
            'request_id':rid or uid(),'expected_version':version if version is not None else record['version'] if record else 0,'payload':payload},token)
    def create(kind,payload):
        code,result=save(kind,payload)
        if code!=200: raise AssertionError(f'T04 {kind} create failed: {code} {result}')
        ok('T04 '+kind+' create',code==200)
        return result
    def listing(kind,token=at,archived=False,**extra):
        return rpc('list_master_records',dict(kind=kind,include_archived=archived,**extra),token)
    ok('T04 document setup initially blocked',rpc('require_document_setup',token=at)[0]==400)
    code,companies=listing('COMPANY'); company=companies[0]
    company=save('COMPANY',{'name':'ISOLATED T04 COMPANY','contact_details':{'address':'Test address'}},company)[1]
    ok('T04 company identity enables setup gate',rpc('require_document_setup',token=at)[1]['company']['name']=='ISOLATED T04 COMPANY')
    parties=[]
    for n,roles in [(1,['OWNER','DRIVER']), (2,['OWNER','CUSTOMER','BROKER']), (3,['CUSTOMER'])]:
        parties.append(create('PARTY',{'code':'T04-P'+str(n),'display_name':'Test party '+str(n),'roles':roles,'contact_details':{'phone':'synthetic-only'},'archived':False}))
    owner,second,customer=parties
    vehicle=create('VEHICLE',{'registration':'T04-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':owner['id'],'archived':False})
    route=create('ROUTE',{'code':'T04-R','origin_label':'Test origin','destination_label':'Test destination','suggested_fare':'1234.56','archived':False})
    category=create('CATEGORY',{'name':'Synthetic diesel','archived':False})
    expense=uid()
    sql(f"insert into public.expenses(id,business_id,vehicle_id,office_id,category_id,expense_date,amount,payer_id,cost_bearer_id,funding_source) values('{expense}','{b}','{vehicle['id']}','{office[0]}','{category['id']}','2026-10-11',10.01,'{owner['id']}','{owner['id']}','SELF_FUNDED_COST');")
    expense_before=sql(f"select to_jsonb(e) from public.expenses e where id='{expense}';")
    extra_office=create('OFFICE',{'code':'T04-O','name':'Synthetic office','archived':False})
    ok('T04 one contact has multiple roles',set(second['roles'])=={'OWNER','CUSTOMER','BROKER'})
    defaults_body={'vehicle_id':vehicle['id'],'route_id':route['id'],'origin_office_id':office[0],'destination_office_id':office[1]}
    code,defaults=rpc('get_trip_defaults',defaults_body,at)
    ok('T04 server snapshot captures current owner and exact fare',code==200 and defaults['owner_id']==owner['id'] and defaults['suggested_fare']=='1234.56')
    trip,consignment,document=uid(),uid(),uid()
    sql(f"""begin;
      insert into public.trips(id,business_id,trip_number,vehicle_id,driver_id,origin_office_id,destination_office_id,route_id,owner_id,owner_snapshot,route_snapshot,load_kind)
      values('{trip}','{b}','T04-HISTORY','{vehicle['id']}','{owner['id']}','{office[0]}','{office[1]}','{route['id']}','{defaults['owner_id']}',
        '{json.dumps(defaults['owner_snapshot'])}'::jsonb,'{json.dumps(defaults['route_snapshot'])}'::jsonb,'LOADED');
      insert into public.consignments(id,business_id,trip_id,customer_id,car_count,quoted_amount,quote_mode,commission_method,commission_value,commission,customer_charge,owner_entitlement)
      values('{consignment}','{b}','{trip}','{customer['id']}',1,1234.56,'DEDUCTED','FIXED',0,0,1234.56,1234.56);
      insert into public.issued_documents(id,business_id,document_type,permanent_number,issue_year,issuer_staff_id,office_id,trip_id,recipient_kind,recipient_id,snapshot,field_order,format_options,schema_version,template_version,content_digest)
      values('{document}','{b}','INVOICE','T04-TEST',2026,'{env['ap']['id']}','{office[0]}','{trip}','OWNER','{owner['id']}',
        '{json.dumps({'owner':defaults['owner_snapshot'],'route':defaults['route_snapshot'],'fare':'1234.56'})}'::jsonb,array['owner'],'{{}}'::jsonb,1,1,repeat('a',64));
      commit;""")
    history=sql(f"select jsonb_build_object('trip',to_jsonb(t),'quote',to_jsonb(c),'document',to_jsonb(d)) from public.trips t join public.consignments c on c.trip_id=t.id join public.issued_documents d on d.trip_id=t.id where t.id='{trip}';")
    code,vehicle=save('VEHICLE',{'registration':'T04-SYNTHETIC','current_owner_id':second['id'],'default_driver_id':None,'archived':False},vehicle)
    ok('AT-10 current owner changed',code==200)
    code,route=save('ROUTE',{'suggested_fare':'9876.54','origin_label':'Changed origin'},route)
    ok('AT-11 route default changed exactly',code==200 and route['suggested_fare']=='9876.54')
    code,new_defaults=rpc('get_trip_defaults',defaults_body,at)
    ok('AT-10 new trip defaults use new owner',code==200 and new_defaults['owner_id']==second['id'])
    ok('AT-11 new draft suggestion changed',new_defaults['suggested_fare']=='9876.54' and new_defaults['route_snapshot']['origin_label']=='Changed origin')
    code,owner=save('PARTY',{'display_name':'Renamed historical owner','roles':owner['roles'],'contact_details':{'phone':'changed-test-contact'}},owner)
    ok('AT-10 owner contact/name edit accepted without rewriting snapshots',code==200)
    new_trip=uid()
    sql(f"insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,route_id,owner_id,owner_snapshot,route_snapshot,load_kind) values('{new_trip}','{b}','T04-NEW','{vehicle['id']}','{office[0]}','{office[1]}','{route['id']}','{new_defaults['owner_id']}','{json.dumps(new_defaults['owner_snapshot'])}','{json.dumps(new_defaults['route_snapshot'])}','EMPTY');")
    ok('AT-10 actual new fixture trip records new owner',sql(f"select owner_id from public.trips where id='{new_trip}';")==second['id'])
    ok('AT-10/11 prior trip, agreed quote and issued snapshot byte-equivalent',history==sql(f"select jsonb_build_object('trip',to_jsonb(t),'quote',to_jsonb(c),'document',to_jsonb(d)) from public.trips t join public.consignments c on c.trip_id=t.id join public.issued_documents d on d.trip_id=t.id where t.id='{trip}';"))
    rid=uid(); body={'name':'Synthetic renamed diesel'}
    first=save('CATEGORY',body,category,rid)
    ok('T04 identical retry returns one result',first==save('CATEGORY',body,category,rid) and first[0]==200)
    ok('T04 conflicting retry rejected',save('CATEGORY',{'name':'Changed retry'},category,rid)[0]==409)
    ok('T04 stale version rejected',save('CATEGORY',body,category)[0]==409)
    new_id,new_request=uid(),uid()
    create_args={'kind':'CATEGORY','target_id':new_id,'request_id':new_request,'expected_version':0,'payload':{'name':'Retry-created category'}}
    created=rpc('save_master_record',create_args,at)
    ok('T04 creation retry preserves one record and response',created[0]==200 and created==rpc('save_master_record',create_args,at))
    ok('T04 creation retry produces one audit entry',sql(f"select count(*) from public.audit_events where record_id='{new_id}';")=='1')
    null_args=dict(create_args,request_id=uid(),expected_version=None)
    ok('T04 null version rejected',rpc('save_master_record',null_args,at)[0]==400)
    category=first[1]
    with ThreadPoolExecutor(max_workers=2) as pool:
        results=list(pool.map(lambda _:save('CATEGORY',{'name':'Concurrent edit'},category),range(2)))
    ok('T04 competing edits exactly one accepted',sorted(r[0] for r in results)==[200,409])
    category=next(r[1] for r in results if r[0]==200)
    ok('T04 negative expected version denied',save('CATEGORY',body,category,version=-1)[0]==400)
    ok('T04 client business/actor injection rejected',save('CATEGORY',dict(name='Bypass',business_id=uid()),category)[0]==400)
    ok('T04 JSON numeric fare rejected',save('ROUTE',{'suggested_fare':123.45},route)[0]==400)
    ok('T04 extra decimals rejected',save('ROUTE',{'suggested_fare':'1.001'},route)[0]==400)
    ok('T04 negative fare rejected',save('ROUTE',{'suggested_fare':'-1.00'},route)[0]>=400)
    ok('T04 wrong owner role rejected',save('VEHICLE',{'current_owner_id':customer['id']},vehicle)[0]==400)
    ok('T04 wrong driver role rejected',save('VEHICLE',{'default_driver_id':customer['id']},vehicle)[0]==400)
    ok('T04 unrelated origin snapshot request denied',rpc('get_trip_defaults',defaults_body,st)[0]==403)
    ok('T04 assigned origin snapshot request succeeds',rpc('get_trip_defaults',dict(defaults_body,origin_office_id=office[1],destination_office_id=office[0]),st)[0]==200)
    for token in [st,None]:
        for kind in ['COMPANY','OFFICE','PARTY','VEHICLE','ROUTE','CATEGORY']:
            ok('T04 non-admin '+kind+' command denied',save(kind,{},token=token)[0] in (401,403))
    for token in [st,at,None]:
        for table in ['businesses','offices','parties','party_roles','vehicles','routes','expense_categories']:
            for method in ['POST','PATCH','DELETE']:
                code,error=request('/rest/v1/'+table+('?id=not.is.null' if method!='POST' else ''),{'version':999} if method=='PATCH' else {} if method=='POST' else None,token,method=method)
                ok('T04 direct '+table+' '+method+' denied',code in (401,403) and error.get('code')=='42501')
    code,choices=listing('PARTY',st)
    ok('T04 staff choices exclude contacts/Auth IDs/version metadata',code==200 and choices and all(not(set(r)&{'contact_details','created_by','version','business_id'}) for r in choices))
    ok('T04 staff cannot retrieve archived choices',listing('PARTY',st,True)[0]==403)
    ok('T04 staff cannot retrieve admin company record',listing('COMPANY',st)[0]==403)
    ok('T04 anonymous cannot read choices',listing('PARTY',None)[0] in (401,403))
    ok('T04 raw master read unavailable to staff',request('/rest/v1/parties?select=*',token=st,method='GET')[0]==403)
    for kind,record in [('PARTY',owner),('VEHICLE',vehicle),('ROUTE',route),('CATEGORY',category),('OFFICE',extra_office)]:
        payload={'archived':True}
        if kind=='PARTY':payload['roles']=record['roles']
        code,updated=save(kind,payload,record)
        ok('T04 used '+kind+' archives without deleting',code==200 and updated['archived_at'] is not None)
        ok('T04 archived '+kind+' excluded from choices',all(r['id']!=record['id'] for r in listing(kind,st)[1]))
        ok('T04 admin can inspect archived '+kind,any(r['id']==record['id'] for r in listing(kind,at,True)[1]))
    ok('T04 archived vehicle cannot seed draft',rpc('get_trip_defaults',defaults_body,at)[0]==400)
    ok('T04 used category and party archive preserve saved expense',expense_before==sql(f"select to_jsonb(e) from public.expenses e where id='{expense}';"))
    ok('T04 archived owner/route retains history',history==sql(f"select jsonb_build_object('trip',to_jsonb(t),'quote',to_jsonb(c),'document',to_jsonb(d)) from public.trips t join public.consignments c on c.trip_id=t.id join public.issued_documents d on d.trip_id=t.id where t.id='{trip}';"))
    code,second=save('PARTY',{'roles':['CUSTOMER','BROKER']},second)
    ok('T04 role removal archives referenced OWNER link',code==200 and sql(f"select archived_at is not null from public.party_roles where party_id='{second['id']}' and role='OWNER';")=='t')
    ok('T04 historical new owner role link retained',sql(f"select owner_id from public.trips where id='{new_trip}';")==second['id'])
    ok('T04 audit captures previous role list',sql(f"select before_data->'roles' ? 'OWNER' from public.audit_events where record_id='{second['id']}' and action='UPDATE' order by recorded_at desc limit 1;")=='t')
    # Scope tests with a second synthetic business, without a second authenticated admin.
    foreign_b,foreign_p=uid(),uid()
    sql(f"insert into public.businesses(id,name) values('{foreign_b}','SECOND SYNTHETIC BUSINESS');insert into public.parties(id,business_id,code,display_name) values('{foreign_p}','{foreign_b}','FOREIGN','FOREIGN TEST');insert into public.party_roles(business_id,party_id,role) values('{foreign_b}','{foreign_p}','OWNER');")
    try:
        ok('T04 foreign business excluded from admin search',not any(r['id']==foreign_p for r in listing('PARTY',at,True)[1]))
        ok('T04 foreign owner assignment rejected',save('VEHICLE',{'current_owner_id':foreign_p,'archived':False},vehicle)[0]>=400)
        ok('T04 foreign record update rejected',save('PARTY',{'roles':['OWNER']},{'id':foreign_p,'version':1})[0]==409)
    finally:
        sql(f"delete from public.party_roles where business_id='{foreign_b}';delete from public.parties where business_id='{foreign_b}';delete from public.businesses where id='{foreign_b}';")
    # Server pagination, including code search independent of display name.
    sql('insert into public.expense_categories(business_id,name) values '+','.join(f"('{b}','Pagination {i:03}')" for i in range(55))+';')
    page1=listing('CATEGORY',search_text='Pagination')[1];page2=listing('CATEGORY',search_text='Pagination',page_offset=50)[1]
    ok('T04 server pages capped at 50 without overlap',len(page1)==50 and len(page2)==5 and not(set(r['id'] for r in page1)&set(r['id'] for r in page2)))
    ok('T04 master writes never create financial events',sql(f"select count(*) from public.financial_events where business_id='{b}';")==financial_count)
    ok('T04 stable code search matches a different display name',any(r['id']==second['id'] for r in listing('PARTY',search_text='T04-P2')[1]))
    ok('T04 revoked/unassigned staff cannot read choices',listing('PARTY',env['ot'])[0]==403)
    ok('T04 revoked/unassigned staff cannot save',save('CATEGORY',{'name':'Revoked bypass'},token=env['ot'])[0]==403)
    assigned_office=next(r for r in listing('OFFICE')[1] if r['id']==office[1])
    ok('T04 used assigned office archives',save('OFFICE',{'archived':True},assigned_office)[0]==200)
    ok('T04 office archive invalidates staff choices immediately',listing('PARTY',st)[0]==403)
    import sys, subprocess
    if '--masters-native' in sys.argv:
        config_path=env['ROOT']/'tools/.local/t04-native-config.json'
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],
            'APP_BUSINESS_ID':b,'TEST_USERNAME':'admin','TEST_PASSWORD':env['real']}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t04-native.log').open('w',encoding='utf-8') as log:
                result=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test',
                    'integration_test/master_records_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],
                    cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('T04 native Windows admin create/edit/archive UI',result.returncode==0)
        finally:config_path.unlink(missing_ok=True)
        code,data=env['login']('admin',env['real'])
        ok('T04 harness admin sign-in after native logout',code==200)
        env['at']=data['access_token']
    print('T04 API acceptance checks PASS',flush=True)
