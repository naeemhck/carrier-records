"""T14 complete/redacted export HTTP payloads and real Windows file generation."""
import copy,json,uuid
from pathlib import Path

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at,off=env['b'],env['at'],env['office'];uid=lambda:str(uuid.uuid4());data=env['t11'];st=data['tokens'][3]
    def success(name,r):
        if r[0]!=200:raise AssertionError(f'{name}: {r}')
        ok(name,True);return r[1]
    def master(kind,p):return success('T14 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    vehicle=master('VEHICLE',{'registration':'T14-WIDE','current_owner_id':data['owner']['id'],'default_driver_id':None,'archived':False})
    other=master('PARTY',{'code':'T14-OTHER','display_name':'FORBIDDEN-T14-CUSTOMER','roles':['CUSTOMER'],'contact_details':{},'archived':False})
    rows=[]
    for n in range(8):
        trip,c1,c2,e1,e2,expense,s1,s2,s3=[uid() for _ in range(9)]
        rows.append((trip,c1,c2))
        statements=[f"insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,owner_id,owner_snapshot,load_kind,state,dispatch_date,notes) values('{trip}','{b}','T14-WIDE-{n+1}','{vehicle['id']}','{off[0]}','{off[1]}','{data['owner']['id']}',jsonb_build_object('display_name','Synthetic historical owner'),'LOADED','DISPATCHED','2026-01-30','Synthetic long trip note with wrapping and optional car identifiers repeated for clear transport records.');",
          f"insert into public.stops(id,business_id,trip_id,position,kind,address) values('{s1}','{b}','{trip}',1,'PICKUP','Long visible synthetic pickup address and loading location for customer car delivery with detailed directions'),('{s2}','{b}','{trip}',2,'DROP','Long visible synthetic destination address and unloading location with transport contact directions'),('{s3}','{b}','{trip}',3,'DROP','FORBIDDEN-T14-STOP');",
          f"insert into public.consignments(id,business_id,trip_id,customer_id,broker_id,car_count,quoted_amount,quote_mode,commission_method,commission_value,commission,customer_charge,owner_entitlement,notes) values('{c1}','{b}','{trip}','{data['customer']['id']}','{data['broker']['id']}',2,60000,'DEDUCTED','FIXED',3000,3000,60000,57000,'=HYPERLINK(\"https://example.invalid\",\"Synthetic note is literal text\")'),('{c2}','{b}','{trip}','{other['id']}','{data['broker']['id']}',3,40000,'DEDUCTED','FIXED',2000,2000,40000,38000,'FORBIDDEN-T14-NOTE');",
          f"insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id) values('{e1}','{b}','DISPATCH','2026-01-30','{env['ap']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}',60000,'{uid()}'),('{e2}','{b}','DISPATCH','2026-01-30','{env['ap']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}',40000,'{uid()}');",
          f"insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount) values('{b}','{e1}','{data['customer']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}','CUSTOMER_RECEIVABLE',60000),('{b}','{e1}','{data['owner']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}','OWNER_PAYABLE',-57000),('{b}','{e1}','{data['broker']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c1}','BROKER_COMMISSION_PAYABLE',-3000),('{b}','{e2}','{other['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}','CUSTOMER_RECEIVABLE',40000),('{b}','{e2}','{data['owner']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}','OWNER_PAYABLE',-38000),('{b}','{e2}','{data['broker']['id']}','{off[0]}','{vehicle['id']}','{trip}','{c2}','BROKER_COMMISSION_PAYABLE',-2000);",
          f"insert into public.expenses(id,business_id,vehicle_id,trip_id,office_id,category_id,expense_date,amount,payer_id,cost_bearer_id,funding_source,state,owner_id) values('{expense}','{b}','{vehicle['id']}','{trip}','{off[0]}','{data['category']['id']}','2026-02-10',1000,'{data['owner']['id']}','{data['owner']['id']}','SELF_FUNDED_COST','CONFIRMED','{data['owner']['id']}');"]
        for idx,cons in enumerate([c1,c1,c2]):
            identifier=(('VISIBLE-T14-CAR-'+str(n)+'-'+str(idx)+'-') if cons==c1 else 'FORBIDDEN-T14-CAR-')+'LONG-SYNTHETIC-TRANSPORT-IDENTIFIER-'*2
            statements.append(f"insert into public.consignment_cars(business_id,trip_id,consignment_id,identifier,pickup_stop_id,drop_stop_id) values('{b}','{trip}','{cons}','{identifier}','{s1 if cons==c1 else s3}','{s2 if cons==c1 else s3}');")
        sql('begin;'+''.join(statements)+'commit;')
    for role in ['owner','customer','broker']:
        party=data[role];version=int(sql(f"select version from public.parties where id='{party['id']}';"))
        long_name=('Synthetic '+role+' recipient with a long transport operations description for loading, unloading and reconciliation')[:119]
        success('T14 long synthetic recipient name',rpc('save_master_record',{'kind':'PARTY','target_id':party['id'],'request_id':uid(),'expected_version':version,'payload':{'display_name':long_name,'roles':[role.upper()],'contact_details':{},'archived':False}},at))
    filters={'from':'2026-01-01','to':'2026-12-31','vehicle_id':vehicle['id']}
    def catalogue(report,recipient):return success('T14 current export catalogue',rpc('get_output_catalogue',{'report_kind':report,'recipient_kind':recipient},st))
    def command(report,recipient,party=None,hidden=None):
        c=catalogue(report,recipient);fields=[f['field_key'] for f in c['fields'] if f['field_key']!=hidden]
        return {'report_kind':report,'recipient_kind':recipient,'recipient_id':party,'filters':filters,'field_order':fields,'format_options':{'orientation':'AUTO','sheet_name':'Records'},'preset_id':None,'event_id':None}
    cmds={
        'owner_full':command('OWNER_STATEMENT','OWNER',data['owner']['id']),
        'owner_hidden':command('OWNER_STATEMENT','OWNER',data['owner']['id'],'owner_cost'),
        'customer':command('CUSTOMER_STATEMENT','CUSTOMER',data['customer']['id']),
        'broker':command('BROKER_MONTHLY','BROKER',data['broker']['id']),
        'wide_internal':command('OWNER_STATEMENT','INTERNAL'),
    }
    def export(cmd,token=st):return rpc('prepare_output_export',{'command':cmd},token)
    cases={name:success('AT24 authorized complete '+name,export(cmd)) for name,cmd in cmds.items()}
    ok('AT24 hidden cost never changes authoritative profit or balances',cases['owner_full']['totals']==cases['owner_hidden']['totals'] and cases['owner_full']['totals']['owner_profit']=='752000.00' and all('owner_cost' not in r for r in cases['owner_hidden']['rows']))
    ok('AT29 customer payload has only own charges cars stops and notes',cases['customer']['totals']['customer_fare']=='480000.00' and all('FORBIDDEN-T14' not in json.dumps(r) for r in cases['customer']['rows']))
    ok('AT28 wide selected payload includes optional long identifiers',len(cases['wide_internal']['fields'])>25 and len(cases['wide_internal']['rows'])==8 and any(len(r.get('car_identifiers',''))>200 for r in cases['wide_internal']['rows']))
    # The T12 fixture has 61 standalone groups; a full export must include both pages.
    if 't12' in env:
        pages=copy.deepcopy(cmds['owner_full']);pages['filters']={'from':'2025-06-01','to':'2025-06-30'}
        complete=success('T14 all export pages fetched server-side',export(pages));ok('AT24 full export includes 61 rows and exact whole-filter totals',len(complete['rows'])==61 and complete['totals']['owner_cost']=='61.00' and not complete['has_more'])
    for role,key in [('OWNER','brokerage'),('CUSTOMER','owner_profit'),('BROKER','owner_profit')]:
        target=copy.deepcopy(cmds[{'OWNER':'owner_full','CUSTOMER':'customer','BROKER':'broker'}[role]]);target['field_order'].append(key);ok('AT29 modified export request cannot restore forbidden '+role,export(target)[0]==403)
    ok('AT29 arbitrary embedded source/payload injection denied',export(cmds['owner_full']|{'raw_source':{'brokerage':'999999.00'}})[0]==400)
    ok('AT29 unauthorized direct full export denied',export(cmds['owner_full'],env['t11']['tokens'][4])[0]==403)
    before=sql(f"select (select count(*) from public.financial_events where business_id='{b}')||':'||(select count(*) from public.journal_lines where business_id='{b}')||':'||(select count(*) from public.issued_documents where business_id='{b}');")
    for _ in range(2):success('T14 repeat read-only export',export(cmds['owner_hidden']))
    ok('AT24 exports never post or issue documents',before==sql(f"select (select count(*) from public.financial_events where business_id='{b}')||':'||(select count(*) from public.journal_lines where business_id='{b}')||':'||(select count(*) from public.issued_documents where business_id='{b}');"))
    # Native generation calls the production export service, digest verification and libraries.
    import sys
    if '--native-exports' in sys.argv:
        output_dir=env['ROOT']/'tools/.local/t14-native-files';output_dir.mkdir(exist_ok=True)
        cfg=env['ROOT']/'tools/.local/t14-native-config.json'
        cfg.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':env['base'],'SUPABASE_PUBLISHABLE_KEY':env['anon'],'APP_BUSINESS_ID':b,'TEST_USERNAME':'reports3','TEST_PASSWORD':env['real'],'TEST_VEHICLE_ID':vehicle['id'],'TEST_OWNER_ID':data['owner']['id'],'TEST_CUSTOMER_ID':data['customer']['id'],'TEST_BROKER_ID':data['broker']['id'],'TEST_ORIGINAL_ID':env['t13']['original']['id'],'TEST_REPLACEMENT_ID':env['t13']['replacement']['id'],'TEST_RECEIPT_ID':env['t13']['receipt']['id'],'TEST_EXPORT_DIR':str(output_dir)}),encoding='utf-8')
        try:
            with (env['ROOT']/'tools/.local/t14-native.log').open('w',encoding='utf-8') as log:result=env['subprocess'].run(['powershell','-NoProfile','-File',str(env['ROOT']/'tools/flutter.ps1'),'test','integration_test/exports_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(cfg)],cwd=env['ROOT']/'app',stdout=log,stderr=env['subprocess'].STDOUT)
            ok('T14 actual Windows PDF XLSX generation and printing capability',result.returncode==0)
        finally:cfg.unlink(missing_ok=True)
        st=success('T14 fresh login after native global logout',env['login']('reports3',env['real']))['access_token']
        runtime=Path('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe')
        with (env['ROOT']/'tools/.local/t14-file-inspection.log').open('w',encoding='utf-8') as log:r=env['subprocess'].run([str(runtime),str(env['ROOT']/'tools/tests/t14_file_inspection.py'),str(output_dir)],stdout=log,stderr=env['subprocess'].STDOUT)
        ok('AT24/28/29 independent actual PDF XLSX contents metadata hidden-data inspection',r.returncode==0)
    p=env['profile'](st);success('T14 revoke exporter old office',rpc('admin_manage_staff',{'target_id':p['id'],'expected_version':p['version'],'display_name':p['display_name'],'account_role':'STAFF','active':True,'office_ids':[off[2]]},at))
    ok('AT29 old JWT cannot export after access change',export(cmds['owner_full'],st)[0]==403)
    fresh=success('T14 fresh login after export scope change',env['login']('reports3',env['real']))['access_token']
    now=success('T14 current full export excludes revoked office',export(cmds['owner_full'],fresh));ok('AT29 fresh export does not restore previous totals',now['rows']==[] and now['totals']['owner_profit']=='0.00')
    ok('AT29 current snapshot export read denied after office change',rpc('get_issued_document',{'document_id':env['t13']['original']['id']},fresh)[0]==403)
    print('T14 backend export selection accounting scope and payload attacks PASS',flush=True)
