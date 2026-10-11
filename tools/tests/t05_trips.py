"""T05 real HTTP/RLS acceptance, synthetic loopback fixtures only via t03_api.py."""
import copy, json, uuid, sys, subprocess
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc, request, sql, ok = [env[k] for k in ('rpc','request','sql','ok')]
    b, at, office = [env[k] for k in ('b','at','office')]
    uid = lambda: str(uuid.uuid4())
    def success(name, result):
        if result[0] != 200: raise AssertionError(f'{name}: {result}')
        ok(name, True)
        return result[1]
    tokens = {}
    for name in ['entry','colleague']:
        result=success('T05 create synthetic '+name,env['edge']({'action':'create','username':name,'display_name':'Test '+name,'role':'STAFF','office_ids':[office[0]],'password':env['password']},at))
        env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{result['id']}';"))
        first=success('T05 temporary sign in',env['login'](name))
        env['change'](first['access_token'])
        tokens[name]=success('T05 ready sign in',env['login'](name,env['real']))['access_token']
    for name in ['destination','outside']:
        tokens[name]=success('T05 scope sign in '+name,env['login'](name,env['real']))['access_token']
    st,dt,xt=tokens['entry'],tokens['destination'],tokens['outside']
    def master(kind,payload):
        return success('T05 master fixture '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':payload},at))
    parties=[]
    for name,roles in [('owner',['OWNER','DRIVER']),('customer1',['CUSTOMER']),('customer2',['CUSTOMER']),('broker',['BROKER']),('newowner',['OWNER'])]:
        parties.append(master('PARTY',{'code':'T05-'+name,'display_name':'Synthetic '+name,'roles':roles,'contact_details':{},'archived':False}))
    owner,c1,c2,broker,newowner=parties
    vehicle=master('VEHICLE',{'registration':'T05-SYNTHETIC','current_owner_id':owner['id'],'default_driver_id':owner['id'],'archived':False})
    route=master('ROUTE',{'code':'T05-R','origin_label':'Synthetic pickup','destination_label':'Synthetic drop','suggested_fare':'1234.56','archived':False})
    otheroffice=master('OFFICE',{'code':'T05-O','name':'Restricted synthetic office','archived':False})
    financial=sql(f"select count(*) from public.financial_events where business_id='{b}';")
    def body(empty=False, reverse=False):
        stops=[{'id':uid(),'kind':kind,'address':'Synthetic stop '+str(i)} for i,kind in enumerate(['PICKUP','PICKUP','DROP','DROP'])]
        cs=[]
        for i,customer in enumerate([c1,c2]):
            cs.append({'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':3 if i==0 else 2,
                'quoted_amount':'100000.00' if i==0 else '1234.56','quote_mode':'DEDUCTED' if i==0 else 'ADDED',
                'commission_method':'PERCENTAGE' if i==0 else 'FIXED','commission_value':'5.00' if i==0 else '10.01',
                'pickup_stop_id':stops[i]['id'],'drop_stop_id':stops[i+2]['id'],'notes':'Synthetic only',
                'cars':[{'id':uid(),'identifier':'SYNTHETIC-'+str(n),'pickup_stop_id':None,'drop_stop_id':None} for n in range(2)] if i==0 else []})
        return {'vehicle_id':vehicle['id'],'driver_id':owner['id'],'origin_office_id':office[1] if reverse else office[0],
            'destination_office_id':office[0] if reverse else office[1],'route_id':route['id'],'planned_dispatch_date':'2026-10-11',
            'load_kind':'EMPTY' if empty else 'LOADED','return_of_trip_id':None,'notes':'Isolated T05 draft','reason':'Synthetic correction',
            'stops':[] if empty else stops,'consignments':[] if empty else cs}
    def save(payload,target=None,version=0,token=st,rid=None):
        return rpc('save_trip',{'target_id':target or uid(),'request_id':rid or uid(),'expected_version':version,'payload':payload},token)
    def detail(target,token=st): return rpc('get_trip_detail',{'trip_id':target},token)
    payload=body(); target=uid(); rid=uid()
    draft=success('AT-08 draft multi-customer create',save(payload,target,rid=rid))
    ok('T05 only draft lifecycle, potential values, server owner',draft['state']=='DRAFT' and draft['dispatch_date'] is None and draft['arrival_date'] is None and draft['owner_id']==owner['id'])
    ok('AT-08 draft exact combined totals',draft['totals']=={'car_count':5,'customer_charge':'101244.57','commission':'5010.01','owner_entitlement':'96234.56'})
    cons={c['customer_id']:c for c in draft['consignments']}
    ok('AT-08 separate customers retain independent fares/counts',cons[c1['id']]['owner_entitlement']=='95000.00' and cons[c2['id']]['customer_charge']=='1244.57' and cons[c2['id']]['car_count']==2)
    ok('T05 optional identifiers do not replace car count',len(cons[c1['id']]['cars'])==2 and len(cons[c2['id']]['cars'])==0)
    ok('T05 identifier stops inherit consignment pickup/drop',all(a['pickup_stop_id']==payload['stops'][0]['id'] and a['drop_stop_id']==payload['stops'][2]['id'] for a in cons[c1['id']]['cars']))
    ok('T05 create retry returns identical response',save(payload,target,rid=rid)==(200,draft))
    ok('T05 request ID mismatch denied',save(dict(payload,notes='Different'),target,rid=rid)[0]==409)
    ok('T05 one create audit with trusted actor',sql(f"select count(*) from public.audit_events where record_id='{target}' and action='CREATE_DRAFT' and actor_id=(select id from public.staff_profiles where username='entry' and business_id='{b}');")=='1')
    for token in [st,dt,at]: ok('T05 origin/destination/admin detail readable',detail(target,token)[0]==200)
    ok('T05 destination detail not editable',detail(target,dt)[1]['can_edit'] is False)
    ok('T05 unrelated detail denied',detail(target,xt)[0]==403)
    for term in ['T05-SYNTHETIC','Synthetic customer1',draft['trip_number']]:
        for token,visible in [(st,True),(dt,True),(xt,False)]:
            page=success('T05 office scoped search',rpc('list_trips',{'search_text':term},token))
            ok('T05 search cannot expand office scope',any(r['id']==target for r in page['rows'])==visible)
    ok('T05 unauthorized office filter denied',rpc('list_trips',{'office_id':office[2]},st)[0]==403)
    ok('T05 date/state/vehicle filters',len(rpc('list_trips',{'vehicle_id':vehicle['id'],'trip_state':'DRAFT','date_from':'2026-10-11','date_to':'2026-10-11'},st)[1]['rows'])==1)
    ok('T05 date outside range filters draft',rpc('list_trips',{'date_from':'2026-10-12'},st)[1]['rows']==[])
    ok('T05 invalid date/range/query rejected',all(rpc('list_trips',p,st)[0]==400 for p in [{'date_from':'2026-02-30'},{'date_from':'2026-10-12','date_to':'2026-10-11'},{'page_offset':-1},{'search_text':None},{'trip_state':'UNKNOWN'}]))
    for table,child in [('trips',target),('consignments',cons[c1['id']]['id']),('stops',payload['stops'][0]['id']),('consignment_cars',cons[c1['id']]['cars'][0]['id'])]:
        ok('T05 direct '+table+' RLS hides outside row',request('/rest/v1/'+table+'?select=id&id=eq.'+child,token=xt,method='GET')==(200,[]))
        for token in [st,dt,at,None]:
            for method in ['POST','PATCH','DELETE']:
                denial=request('/rest/v1/'+table+('?id=eq.'+child if method!='POST' else ''),({'notes':'Bypass'} if table in ('trips','consignments') else {'address':'Bypass'} if table=='stops' else {'identifier':'Bypass'}) if method=='PATCH' else {} if method=='POST' else None,token,method=method)
                ok('T05 direct '+table+' '+method+' denied',denial[0] in (401,403) and denial[1].get('code')=='42501')
    for token in [dt,xt,tokens['colleague'],None]: ok('T05 only assigned creator/admin edits',save(payload,target,1,token)[0] in (401,403))
    spoof=dict(payload,origin_office_id=office[1],destination_office_id=office[0])
    ok('T05 spoofing new origin cannot bypass existing origin',save(spoof,target,1,dt)[0]==403)
    attack=copy.deepcopy(payload)
    for c in attack['consignments']: c.update(commission='0.00',customer_charge='0.01',owner_entitlement='999999.99')
    canonical=success('T05 manipulated derived prices reconciled',save(attack,target,1))
    ok('T05 manipulated client cannot override server totals',canonical['totals']==draft['totals'])
    ok('T05 stale expected version denied',save(payload,target,1)[0]==409)
    invalid=[]
    def invalid_case(name, mutate):
        p=body();mutate(p);invalid.append((name,p))
    invalid_case('JSON numeric fare',lambda p:p['consignments'][0].update(quoted_amount=123.45))
    invalid_case('extra decimal fare',lambda p:p['consignments'][0].update(quoted_amount='1.001'))
    invalid_case('negative fare',lambda p:p['consignments'][0].update(quoted_amount='-1.00'))
    invalid_case('percentage over 100',lambda p:p['consignments'][0].update(commission_value='100.01'))
    invalid_case('deduction greater than fare',lambda p:p['consignments'][0].update(commission_method='FIXED',commission_value='100000.01'))
    invalid_case('broker missing for commission',lambda p:p['consignments'][0].update(broker_id=None))
    invalid_case('zero count',lambda p:p['consignments'][0].update(car_count=0))
    invalid_case('more identifiers than count',lambda p:p['consignments'][0].update(car_count=1))
    invalid_case('duplicate identifiers',lambda p:p['consignments'][0]['cars'][1].update(identifier='SYNTHETIC-0'))
    invalid_case('foreign stop',lambda p:p['consignments'][0].update(pickup_stop_id=payload['stops'][0]['id']))
    invalid_case('drop before pickup',lambda p:p.update(stops=list(reversed(p['stops']))))
    invalid_case('wrong stop kind',lambda p:p['consignments'][0].update(pickup_stop_id=p['stops'][2]['id']))
    invalid_case('wrong customer role',lambda p:p['consignments'][0].update(customer_id=owner['id']))
    invalid_case('duplicate child ID',lambda p:p['stops'][1].update(id=p['stops'][0]['id']))
    invalid_case('reuse child from other draft',lambda p:p['consignments'][0].update(id=payload['consignments'][0]['id']))
    invalid_case('empty cannot carry consignments',lambda p:p.update(load_kind='EMPTY'))
    invalid_case('loaded requires consignments',lambda p:p.update(consignments=[]))
    for field,value in [('state','DISPATCHED'),('dispatch_date','2026-10-11'),('owner_id',newowner['id']),('business_id',uid()),('created_by',env['admin'])]:
        invalid_case('injected '+field,lambda p,f=field,v=value:p.update({f:v}))
    before=sql(f"select jsonb_build_array((select count(*) from public.trips where business_id='{b}'),(select count(*) from public.stops where business_id='{b}'),(select count(*) from public.audit_events where business_id='{b}'),(select last_number from private.trip_sequences where business_id='{b}')); ")
    for name,p in invalid: ok('T05 '+name+' rejected',save(p)[0]>=400)
    ok('T05 failed aggregate writes roll back completely',before==sql(f"select jsonb_build_array((select count(*) from public.trips where business_id='{b}'),(select count(*) from public.stops where business_id='{b}'),(select count(*) from public.audit_events where business_id='{b}'),(select last_number from private.trip_sequences where business_id='{b}'));"))
    ok('T05 missing edit reason rejected',save(dict(payload,reason=''),target,2)[0]==400)
    ok('T05 null expected version rejected',save(payload,target,None)[0]==400)
    with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(lambda _:save(payload,target,2),range(2)))
    ok('T05 competing edits exactly one succeeds',sorted(r[0] for r in results)==[200,409])
    canonical=next(r[1] for r in results if r[0]==200)
    success('T05 update current owner',rpc('save_master_record',{'kind':'VEHICLE','target_id':vehicle['id'],'request_id':uid(),'expected_version':vehicle['version'],'payload':{'current_owner_id':newowner['id']}},at))
    success('T05 update route fare',rpc('save_master_record',{'kind':'ROUTE','target_id':route['id'],'request_id':uid(),'expected_version':route['version'],'payload':{'suggested_fare':'9876.54'}},at))
    canonical=success('T05 saved draft edit preserves history',save(payload,target,canonical['version']))
    ok('T05 existing owner/route/agreed fares remain recorded',canonical['owner_id']==owner['id'] and canonical['route_snapshot']['suggested_fare']=='1234.56' and canonical['totals']==draft['totals'])
    newdraft=success('T05 new draft snapshots current owner',save(body(empty=True)))
    ok('T05 new draft uses new owner/route',newdraft['owner_id']==newowner['id'] and newdraft['route_snapshot']['suggested_fare']=='9876.54' and newdraft['totals']['customer_charge']=='0.00')
    for empty in [True,False]:
        p=body(empty=empty,reverse=True);p['return_of_trip_id']=target
        returned=success('AT-09 linked '+('empty' if empty else 'loaded')+' return',save(p,token=dt))
        ok('AT-09 return links original, reverses offices',returned['return_of_trip_id']==target and returned['origin_office_id']==office[1] and returned['destination_office_id']==office[0])
    ok('AT-09 original detail shows both returns',len(detail(target)[1]['linked_returns'])==2)
    returnid=detail(target)[1]['linked_returns'][0]['id']
    ok('AT-09 return cycle rejected',save(dict(payload,return_of_trip_id=returnid),target,canonical['version'])[0]==400)
    canonical=success('T05 administrator edits another creator draft',save(payload,target,canonical['version'],at))
    p=body(empty=True);p['return_of_trip_id']=target
    ok('AT-09 invalid return direction rejected',save(p)[0]==400)
    p=body(empty=True);selfid=uid();p['return_of_trip_id']=selfid
    ok('AT-09 self return rejected',save(p,selfid)[0]==400)
    ok('AT-09 linked parent offices cannot be changed',save(dict(payload,destination_office_id=office[2]),target,canonical['version'])[0]==400)
    p=body(); editable=success('T05 aggregate edit fixture',save(p))
    p['stops']=[p['stops'][1],p['stops'][0],p['stops'][3],p['stops'][2]]
    editable=success('T05 reorder stops atomically',save(p,editable['id'],editable['version']))
    ok('T05 reorder keeps links and consecutive positions',[s['id'] for s in editable['stops']]==[s['id'] for s in p['stops']] and [s['position'] for s in editable['stops']]==[1,2,3,4])
    p['consignments']=p['consignments'][:1];p['consignments'][0]['cars']=[]
    p['stops']=[s for s in p['stops'] if s['id'] in [p['consignments'][0]['pickup_stop_id'],p['consignments'][0]['drop_stop_id']]]
    editable=success('T05 remove draft children atomically',save(p,editable['id'],editable['version']))
    ok('T05 removed consignment, cars and unused stops absent',len(editable['consignments'])==1 and editable['consignments'][0]['cars']==[] and len(editable['stops'])==2 and editable['totals']['car_count']==3)
    p.update(load_kind='EMPTY',consignments=[],stops=[])
    editable=success('T05 convert unposted draft to empty',save(p,editable['id'],editable['version']))
    ok('T05 empty edit clears quote aggregate and children',editable['totals']=={'car_count':0,'customer_charge':'0.00','commission':'0.00','owner_entitlement':'0.00'} and editable['stops']==[] and editable['consignments']==[])
    archived=success('T05 archive customer fixture',rpc('save_master_record',{'kind':'PARTY','target_id':c1['id'],'request_id':uid(),'expected_version':c1['version'],'payload':{'archived':True,'roles':c1['roles']}},at))
    ok('T05 new draft cannot choose archived customer',save(body())[0]==400)
    canonical=success('T05 existing draft retains archived customer',save(payload,target,canonical['version']))
    ok('T05 archived historical agreement preserved',canonical['totals']==draft['totals'])
    success('T05 restore synthetic customer',rpc('save_master_record',{'kind':'PARTY','target_id':c1['id'],'request_id':uid(),'expected_version':archived['version'],'payload':{'archived':False,'roles':c1['roles']}},at))
    # Read pagination fixtures are trusted SQL, not production/import data.
    for i in range(51):
        sql(f"insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,owner_id,owner_snapshot,load_kind) values('{uid()}','{b}','T05-PAGE-{i}','{vehicle['id']}','{office[0]}','{office[1]}','{owner['id']}','{{\"display_name\":\"Synthetic owner\"}}','EMPTY');")
    first=rpc('list_trips',{'search_text':'T05-PAGE'},st)[1]['rows'];second=rpc('list_trips',{'search_text':'T05-PAGE','page_offset':50},st)[1]['rows']
    ok('T05 bounded pagination without repeats',len(first)==50 and len(second)==1 and not ({r['id'] for r in first}&{r['id'] for r in second}))
    # Lifecycle fixture is inserted by postgres, never by a client/T05 command.
    visible,hidden=uid(),uid()
    fixture_snapshot=json.dumps({'display_name':'Synthetic newowner'})
    for tid,orig,dest,number in [(visible,office[0],office[1],'T05-VISIBLE'),(hidden,office[2],otheroffice['id'],'T05-HIDDEN')]:
        sql(f"insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,owner_id,owner_snapshot,load_kind,state,dispatch_date) values('{tid}','{b}','{number}','{vehicle['id']}','{orig}','{dest}','{newowner['id']}','{fixture_snapshot}','EMPTY','DISPATCHED','2026-10-10');")
    overlapid=uid();p=body(empty=True)
    def review(tid=overlapid, token=st): return rpc('review_trip_overlap',{'target_id':tid,'vehicle_id':vehicle['id'],'origin_office_id':office[0],'destination_office_id':office[1],'planned_dispatch_date':'2026-10-11'},token)
    warning=success('T05 overlap review',review())
    ok('T05 overlap includes visible trip plus generic restricted warning',warning['requires_confirmation'] is True and warning['restricted_conflict'] is True and [t['id'] for t in warning['visible_trips']]==[visible])
    ok('T05 overlap response discloses no hidden ID/name/count',hidden not in json.dumps(warning) and 'T05-HIDDEN' not in json.dumps(warning) and set(warning)=={'review_token','requires_confirmation','visible_trips','restricted_conflict'})
    ok('T05 overlapping draft cannot save without review',save(p,overlapid)[0]==400)
    confirmed=dict(p,overlap_confirmed=True,overlap_reason='Confirmed synthetic warning',review_token=warning['review_token'])
    ok('T05 explicit checkbox alone cannot bypass ticket',save(dict(confirmed,review_token=None),overlapid)[0]==400)
    ok('T05 review belongs to actor',save(confirmed,overlapid,token=tokens['colleague'])[0]==400)
    ok('T05 overlap confirmation requires reason',save(dict(confirmed,overlap_reason=''),overlapid)[0]==400)
    sql(f"update public.trips set notes='Fixture changed',version=version+1 where id='{hidden}';")
    ok('T05 changed overlap context must be reviewed again',save(confirmed,overlapid)[0]==409)
    warning=success('T05 renewed overlap review',review());confirmed['review_token']=warning['review_token']
    overlapdraft=success('T05 confirmed overlap draft save',save(confirmed,overlapid))
    ok('T05 confirmed warning and reason recorded',overlapdraft['overlap_confirmed'] is True and overlapdraft['overlap_reason']==confirmed['overlap_reason'])
    expiredid=uid();warning=success('T05 expiring review fixture',review(expiredid))
    sql(f"update private.trip_reviews set expires_at=now()-interval '1 second' where token='{warning['review_token']}';")
    ok('T05 expired review denied',save(dict(confirmed,review_token=warning['review_token']),expiredid)[0]==400)
    ok('T05 dispatched record cannot be edited by draft command',save(p,visible,1,at)[0]==400)
    ok('T05 drafts post no financial events',sql(f"select count(*) from public.financial_events where business_id='{b}';")==financial)
    if '--trips-native' in sys.argv:
        cfg=env['ROOT']/'tools/.local/t05-native-config.json'
        cfg.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'entry','TEST_PASSWORD':env['real'],'TEST_TRIP_ID':target}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t05-native.log').open('w',encoding='utf-8') as log:
                native=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/trip_draft_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(cfg)],cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('T05 native Windows draft list/detail/editor/save workflow',native.returncode==0)
            ok('T05 native correction persisted canonically',detail(target,at)[1]['notes']=='Native draft correction')
        finally: cfg.unlink(missing_ok=True)
    print('T05 draft acceptance PASS; AT-08 arrival/delivery propagation deferred to T06.',flush=True)
