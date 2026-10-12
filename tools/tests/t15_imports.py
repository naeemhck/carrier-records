"""AT-30 real JWT reviewed imports; empty loopback harness only."""
import copy,uuid,json
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];at,b,office=env['at'],env['b'],env['office']
    uid=lambda:str(uuid.uuid4())
    def good(name,r):
        if r[0]!=200:raise AssertionError(name+': '+str(r))
        ok(name,True);return r[1]
    u=good('T15 managed importer',env['edge']({'action':'create','username':'importer','display_name':'Synthetic importer','role':'STAFF','office_ids':[office[0]],'password':env['password']},at))
    env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{u['id']}';"))
    tmp=good('T15 temporary login',env['login']('importer'));env['change'](tmp['access_token']);st=good('T15 importer login',env['login']('importer',env['real']))['access_token']
    cat=good('T15 category',rpc('save_master_record',{'kind':'CATEGORY','target_id':uid(),'request_id':uid(),'expected_version':0,'payload':{'name':'T15 synthetic category','archived':False}},at))
    catalogue=good('T15 versioned server catalogue',rpc('get_import_templates',{},st));cc=next(x['code'] for x in catalogue['category_codes'] if x['name']=='T15 synthetic category')
    def row(kind,key,**data):return {'kind':kind,'row_key':key,'data':data}
    def command(rows):return {'batch_id':uid(),'template_version':1,'office_code':'O0','rows':rows}
    rows=[row('PARTY','owner',code='T15-OWNER',display_name='Synthetic import owner',roles='OWNER,DRIVER'),row('PARTY','customer',code='T15-CUSTOMER',display_name='Synthetic import customer',roles='CUSTOMER'),row('PARTY','broker',code='T15-BROKER',display_name='Synthetic import broker',roles='BROKER'),row('VEHICLE','vehicle',registration='T15-VEHICLE',owner_code='T15-OWNER',driver_code='T15-OWNER'),row('ROUTE','route',code='T15-ROUTE',origin_label='Synthetic pickup',destination_label='Synthetic drop',suggested_fare='1234.56'),row('TRIP_DRAFT','trip',vehicle_code='T15-VEHICLE',driver_code='T15-OWNER',origin_code='O0',destination_code='O1',route_code='T15-ROUTE',load_kind='LOADED',planned_dispatch_date='2026-10-13',notes='Synthetic new operation'),row('STOP','pickup',trip_key='trip',position='1',stop_kind='PICKUP',address='Synthetic pickup'),row('STOP','drop',trip_key='trip',position='2',stop_kind='DROP',address='Synthetic drop'),row('CONSIGNMENT_DRAFT','load',trip_key='trip',customer_code='T15-CUSTOMER',broker_code='T15-BROKER',car_count='2',quoted_amount='100000.00',quote_mode='DEDUCTED',commission_method='FIXED',commission_value='5000.00',pickup_stop_key='pickup',drop_stop_key='drop'),row('CAR','car',consignment_key='load',identifier='Synthetic optional car',pickup_stop_key='pickup',drop_stop_key='drop'),row('EXPENSE_DRAFT','cost',vehicle_code='T15-VEHICLE',trip_key='trip',office_code='O0',category_code=cc,expense_date='2026-10-13',amount='10000.00',payer_code='T15-OWNER',cost_bearer_code='T15-OWNER',funding_source='SELF_FUNDED_COST',notes='Synthetic imported diesel')]
    c=command(rows);before=sql(f"select count(*) from public.financial_events where business_id='{b}';")
    p=good('AT30 complete linked dry-run preview',rpc('validate_import',{'command':c},at));ok('AT30 no preview row errors',p['errors']==[])
    ok('AT30 preview never writes masters or drafts',sql("select count(*) from public.parties where code='T15-OWNER';")=='0')
    args={'command':c,'review_token':p['review_token'],'confirm_overlap':False}
    r=good('AT30 atomic reviewed batch commit',rpc('commit_import',args,at))
    ok('AT30 exactly one identical batch retry',rpc('commit_import',args,at)==(200,r) and sql(f"select count(*) from public.import_rows where batch_id='{c['batch_id']}';")==str(len(rows)))
    ok('AT30 imported drafts do not post financial events',before==sql(f"select count(*) from public.financial_events where business_id='{b}';"))
    t=next(x['values'] for x in r['rows'] if x['kind']=='TRIP_DRAFT');ok('AT30 server computes exact fares',t['state']=='DRAFT' and t['consignments'][0]['customer_charge']=='100000.00' and t['consignments'][0]['owner_entitlement']=='95000.00' and len(t['consignments'][0]['cars'])==1)
    altered=copy.deepcopy(args);altered['command']['rows'][0]['data']['display_name']='Changed';ok('AT30 modified committed request denied',rpc('commit_import',altered,at)[0]==409)
    ok('AT30 different actor retry denied',rpc('commit_import',args,st)[0]==409)
    for kind in ['PARTY','VEHICLE','ROUTE']:
        p=good('AT30 staff master preview '+kind,rpc('validate_import',{'command':command([next(x for x in rows if x['kind']==kind)])},st));ok('AT30 staff master rows forbidden '+kind,p['errors'][0]['code']=='FORBIDDEN')
    trip=row('TRIP_DRAFT','newtrip',vehicle_code='T15-VEHICLE',origin_code='O0',destination_code='O1',load_kind='EMPTY',planned_dispatch_date='2026-10-14')
    c2=command([trip]);p2=good('AT30 staff origin preview',rpc('validate_import',{'command':c2},st));ok('AT30 staff origin valid',not p2['errors'])
    args2={'command':c2,'review_token':p2['review_token']}
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:rpc('commit_import',args2,st),range(2)))
    ok('AT30 concurrent duplicate one batch',results[0]==results[1] and results[0][0]==200 and sql(f"select count(*) from public.import_batches where client_batch_id='{c2['batch_id']}';")=='1')
    # Invalid second row must leave even the first valid row uncommitted.
    for field,value,code in [('planned_dispatch_date','03/04/2026','date'),('load_kind','BOOKED','kind'),('notes','=1+1','formula')]:
        bad=copy.deepcopy(trip);bad['data'][field]=value;c3=command([bad]);p3=good('AT30 invalid '+code+' preview',rpc('validate_import',{'command':c3},st));ok('AT30 row error '+code,bool(p3['errors']));ok('AT30 invalid commit rejected',rpc('commit_import',{'command':c3,'review_token':p3['review_token']},st)[0]==409)
    for value in ['1.001','-1.00','1e3','',100]:
        exp=copy.deepcopy(rows[-1]);exp['data'].pop('trip_key');exp['data']['amount']=value;c3=command([trip,exp]);p3=good('AT30 invalid money preview',rpc('validate_import',{'command':c3},st));ok('AT30 exact money rejected with row error',bool(p3['errors']));ok('AT30 no partial two-row commit',rpc('commit_import',{'command':c3,'review_token':p3['review_token']},st)[0]==409 and sql(f"select count(*) from public.import_batches where client_batch_id='{c3['batch_id']}';")=='0')
    c3=command([dict(trip,data=dict(trip['data'],origin_code='O2'))]);p3=good('AT30 wrong origin validation',rpc('validate_import',{'command':c3},st));ok('AT30 origin control server denial',p3['errors'][0]['code']=='FORBIDDEN')
    unknown=copy.deepcopy(trip);unknown['data']['vehicle_code']='Unknown';p3=good('AT30 unknown reference',rpc('validate_import',{'command':command([unknown])},st));ok('AT30 unknown reference no coercion',p3['errors'][0]['code']=='REFERENCE_NOT_FOUND_OR_AMBIGUOUS')
    amb=good('T15 case ambiguity fixture',rpc('save_master_record',{'kind':'PARTY','target_id':uid(),'request_id':uid(),'expected_version':0,'payload':{'code':'t15-owner','display_name':'Synthetic ambiguous party','roles':['OWNER'],'contact_details':{},'archived':False}},at))
    p3=good('AT30 ambiguous reference preview',rpc('validate_import',{'command':command([row('VEHICLE','amb',registration='T15-AMB',owner_code='T15-OWNER')])},at));ok('AT30 ambiguity not first-match',p3['errors'][0]['code']=='REFERENCE_NOT_FOUND_OR_AMBIGUOUS')
    good('T15 remove ambiguity through archive',rpc('save_master_record',{'kind':'PARTY','target_id':amb['id'],'request_id':uid(),'expected_version':amb['version'],'payload':{'roles':['OWNER'],'archived':True}},at))
    c4=command([trip]);p4=good('AT30 pre-change review',rpc('validate_import',{'command':c4},st));v=next(x['values'] for x in r['rows'] if x['kind']=='VEHICLE')
    good('T15 change referenced master',rpc('save_master_record',{'kind':'VEHICLE','target_id':v['id'],'request_id':uid(),'expected_version':v['version'],'payload':{'registration':'T15-VEHICLE','default_driver_id':None}},at))
    ok('AT30 stale reference fingerprint rejected',rpc('commit_import',{'command':c4,'review_token':p4['review_token']},st)[0]==409)
    drafts=good('AT30 expense drafts list',rpc('list_import_expense_drafts',{},at));d=next(x for x in drafts if x['payload']['reason']=='Synthetic imported diesel');ep=dict(d['payload'],allocations=[],offset_confirmed=False)
    edargs={'target_id':d['id'],'expected_version':d['version'],'request_id':uid(),'payload':ep};posted=good('AT30 normal expense financial confirmation',rpc('confirm_import_expense',edargs,at))
    ok('AT30 expense confirmation retry no duplication',rpc('confirm_import_expense',edargs,at)==(200,posted) and sql(f"select count(*) from public.expenses where id='{posted['record_id']}';")=='1')
    for name,body in [('forged-money',dict(trip,data=dict(trip['data'],journal_lines='[]'))),('bad-kind',row('JOURNAL','x',amount='1.00'))]:
        pv=good('AT30 '+name,rpc('validate_import',{'command':command([body])},st));ok('AT30 modified API fields denied',bool(pv['errors']))
    ok('AT30 no public direct import inserts',env['request']('/rest/v1/import_batches',{},st)[0]==403)
    ok('AT30 private apply unavailable',rpc('import_apply',{'command':c,'allow_overlap':True},at)[0]>=400)

    # A deferred failure after source creation must roll the whole transaction back.
    failbatch=command([dict(trip,data=dict(trip['data'],notes='Synthetic rollback import'))]);fv=good('AT30 deferred-failure review',rpc('validate_import',{'command':failbatch},st))
    sql("create function public.t15_test_rollback() returns trigger language plpgsql as $$begin raise exception 'SYNTHETIC_IMPORT_COMMIT_FAILURE';end$$;create constraint trigger t15_test_rollback after insert on public.import_batches deferrable initially deferred for each row execute function public.t15_test_rollback();")
    try:
        ok('AT30 late commit failure returned',rpc('commit_import',{'command':failbatch,'review_token':fv['review_token']},st)[0]>=400)
        ok('AT30 late failure no partial sources batch rows or cache',sql("select count(*) from public.trips where notes='Synthetic rollback import';")=='0' and sql(f"select count(*) from public.import_batches where client_batch_id='{failbatch['batch_id']}';")=='0' and sql(f"select result is null from private.import_reviews where batch_id='{failbatch['batch_id']}';")=='t')
    finally:sql('drop trigger t15_test_rollback on public.import_batches;drop function public.t15_test_rollback();')
    for child in [row('STOP','orphan',trip_key='',position='1',stop_kind='PICKUP',address='Synthetic'),row('CAR','orphan',consignment_key='',identifier='Synthetic')]:
        pv=good('AT30 orphan child preview',rpc('validate_import',{'command':command([child])},st));ok('AT30 orphan does not appear as created child',bool(pv['errors']))
    import sys,subprocess
    if '--native-imports' in sys.argv:
        folder=env['ROOT']/'tools/.local/t15-native-files';folder.mkdir(exist_ok=True)
        cfg=env['ROOT']/'tools/.local/t15-native-config.json';cfg.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'importer','TEST_PASSWORD':env['real'],'TEST_IMPORT_DIR':str(folder)}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t15-native.log').open('w',encoding='utf-8') as log:native=subprocess.run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/imports_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(cfg)],cwd=env['ROOT']/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('AT30 real Windows template parse preview cancellation and explicit commit',native.returncode==0)
        finally:cfg.unlink(missing_ok=True)
        st=good('T15 native logout fresh login',env['login']('importer',env['real']))['access_token']
        ok('AT30 independent native persisted draft',sql("select count(*) from public.trips where notes='Synthetic native XLSX import' and state='DRAFT';")=='1')
        runtime=Path('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
        check=subprocess.run([str(runtime),str(env['ROOT']/'tools/tests/t15_file_inspection.py'),str(folder)],capture_output=True,text=True)
        ok('AT30 actual eight-sheet template/input inspection',check.returncode==0)
    # Office revoked after review must fail even on previously committed retries.
    prof=env['profile'](st);good('T15 revoke origin',rpc('admin_manage_staff',{'target_id':prof['id'],'expected_version':prof['version'],'display_name':prof['display_name'],'account_role':'STAFF','active':True,'office_ids':[office[2]]},at))
    ok('AT30 old JWT import retry denied',rpc('commit_import',args2,st)[0]==403)
    fresh=good('T15 reassigned login',env['login']('importer',env['real']))['access_token'];ok('AT30 fresh JWT revoked import retry denied',rpc('commit_import',args2,fresh)[0]==403)
    print('T15 AT30 import checks PASS',flush=True)
