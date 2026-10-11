"""Destructive synthetic fixtures only on an EMPTY, loopback local Supabase.
Secrets are obtained in memory from CLI status; output contains case names only.
"""
import json, subprocess, urllib.request, urllib.error, uuid, secrets, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sql(query):
    r=subprocess.run(['docker','exec','-i','supabase_db_transport_project','psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=query,text=True,encoding='utf-8',capture_output=True)
    if r.returncode: raise RuntimeError('SQL fixture failed: '+r.stderr)
    return r.stdout.strip()
status=subprocess.run(['powershell','-NoProfile','-File',str(ROOT/'tools/supabase.ps1'),'status','-o','json'],capture_output=True,text=True,check=True)
cfg=json.loads(status.stdout); base=cfg['API_URL']; anon=cfg['ANON_KEY']; secret=cfg['SERVICE_ROLE_KEY']
assert base=='http://127.0.0.1:54321'
assert sql('select count(*) from public.businesses;')=='0', 'Use a separate empty local test database.'
assert sql('select count(*) from auth.users;')=='0', 'Test requires no existing accounts.'
def request(path,body=None,token=None,method='POST',priv=False,raw=None):
    key=secret if priv else anon
    data=raw if raw is not None else None if body is None else json.dumps(body).encode()
    headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'image/png' if raw else 'application/json'}
    req=urllib.request.Request(base+path,data=data,headers=headers,method=method)
    try:
        with urllib.request.urlopen(req,timeout=30) as r: code=r.status; content=r.read()
    except urllib.error.HTTPError as e: code=e.code;content=e.read()
    try: value=json.loads(content)
    except Exception: value=content
    return code,value
def ok(name,condition):
    if not condition: raise AssertionError(name)
    print('PASS '+name,flush=True)
def rpc(name,body=None,token=None,priv=False):return request('/rest/v1/rpc/'+name,body or {},token,priv=priv)
def edge(body,token):return request('/functions/v1/staff-accounts',body,token)
b=str(uuid.uuid4()); users=[]; password='Tmp!'+secrets.token_urlsafe(20); real='New!'+secrets.token_urlsafe(20)
def create_auth(username,pw=password):
    code,data=request('/auth/v1/admin/users',{'email':f'{username}.{b}@staff.invalid','password':pw,'email_confirm':True},priv=True)
    ok('trusted Auth identity creation',code==200);users.append(data['id']);return data['id']
def login(username,pw=password):return request('/auth/v1/token?grant_type=password',{'email':f'{username}.{b}@staff.invalid','password':pw})
def profile(token):
    code,p=rpc('get_session_profile',token=token);ok('live session profile',code==200);return p
def change(token,pw=password,new=real):
    p=profile(token);code,data=edge({'action':'change','current_password':pw,'password':new,'expected_version':p['version']},token)
    ok('verified password change through Edge',code==200);return data
try:
    admin=create_auth('admin')
    code,result=rpc('bootstrap_staff_admin',{'business_id':b,'company_name':'ISOLATED T03 TEST','auth_user_id':admin,'username':'admin','display_name':'Test Admin'},priv=True)
    ok('service-only first administrator bootstrap',code in (200,204))
    code,data=login('admin');ok('temporary administrator sign-in',code==200);at=data['access_token'];ar=data['refresh_token']
    ok('temporary password cannot list accounts',rpc('list_staff_accounts',token=at)[0]==403)
    ok('temporary password cannot read offices',request('/rest/v1/offices?select=*',token=at,method='GET')[1]==[])
    change(at)
    ok('old access token revoked after password change',rpc('get_session_profile',token=at)[0]==403)
    ok('old refresh token revoked after password change',request('/auth/v1/token?grant_type=refresh_token',{'refresh_token':ar})[0]>=400)
    code,data=login('admin',real);ok('changed administrator password login',code==200);at=data['access_token'];ap=profile(at)
    office=[str(uuid.uuid4()) for _ in range(3)]
    sql('insert into public.offices(id,business_id,code,name) values '+','.join(f"('{o}','{b}','O{i}','Test Office {i}')" for i,o in enumerate(office))+';')
    staff={}
    for name,assigned in [('origin',[office[0]]),('destination',[office[1]]),('outside',[office[2]]),('unassigned',[])]:
        code,result=edge({'action':'create','username':name,'display_name':'Test '+name,'role':'STAFF','office_ids':assigned,'password':password},at)
        ok('administrator creates '+name,code==200)
        authid=sql(f"select auth_user_id from public.staff_profiles where id='{result['id']}';");users.append(authid)
        staff[name]={'id':result['id'],'auth':authid}
        code,data=login(name)
        if not assigned:ok('unassigned account cannot sign in',code==403);continue
        ok('assigned active staff sign-in '+name,code==200);old=data['access_token']
        change(old)
        code,data=login(name,real);ok('staff changed-password login '+name,code==200)
        staff[name].update(token=data['access_token'],refresh=data['refresh_token'])
    ot=staff['origin']['token'];dt=staff['destination']['token'];xt=staff['outside']['token']
    owner=str(uuid.uuid4());customer=str(uuid.uuid4());vehicle=str(uuid.uuid4());trips=[str(uuid.uuid4()) for _ in range(2)]
    sql(f"""begin;
    insert into public.parties(id,business_id,code,display_name) values('{owner}','{b}','OWNER','Test Owner'),('{customer}','{b}','CUSTOMER','Test Customer');
    insert into public.party_roles(business_id,party_id,role) values('{b}','{owner}','OWNER'),('{b}','{customer}','CUSTOMER');
    insert into public.vehicles(id,business_id,registration,current_owner_id) values('{vehicle}','{b}','TEST-ONLY','{owner}');
    insert into public.trips(id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,owner_id,owner_snapshot,load_kind) values
    ('{trips[0]}','{b}','T03-A','{vehicle}','{office[0]}','{office[1]}','{owner}','{{"display_name":"Test Owner"}}','EMPTY'),
    ('{trips[1]}','{b}','T03-B','{vehicle}','{office[1]}','{office[2]}','{owner}','{{"display_name":"Test Owner"}}','EMPTY');
    commit;""")
    for token,n in [(ot,1),(dt,2),(xt,1)]:
        code,rows=request('/rest/v1/trips?select=id',token=token,method='GET');ok('AT-12 RLS filters assigned trips',code==200 and len(rows)==n)
    for operation in ['EDIT_FARE','DISPATCH','POST_MONEY','EXPENSE']:
        ok('AT-12 origin '+operation,rpc('authorize_trip_operation',{'trip_id':trips[0],'operation':operation},ot)==(200,True))
    ok('AT-12 origin cannot arrive',rpc('authorize_trip_operation',{'trip_id':trips[0],'operation':'ARRIVAL'},ot)[0]==403)
    ok('AT-12 destination can arrive',rpc('authorize_trip_operation',{'trip_id':trips[0],'operation':'ARRIVAL'},dt)==(200,True))
    for operation in ['EDIT_FARE','DISPATCH']:
        ok('AT-12 destination cannot '+operation,rpc('authorize_trip_operation',{'trip_id':trips[0],'operation':operation},dt)[0]==403)
    ok('AT-12 unrelated office denied',rpc('authorize_trip_operation',{'trip_id':trips[0],'operation':'POST_MONEY'},xt)[0]==403)
    ok('AT-12 unknown operation denied',rpc('authorize_trip_operation',{'trip_id':trips[0],'operation':'BYPASS'},ot)[0]==403)
    for token in [ot,dt,at,None]:
        ok('AT-12 direct trip mutation denied',request('/rest/v1/trips?id=eq.'+trips[0],{'notes':'bypass'},token,method='PATCH')[0]>=400)
        for table in ['financial_events','journal_lines','allocations','idempotency_records']:
            for method in ['POST','PATCH','DELETE']:
                code,denial=request('/rest/v1/'+table+('?id=not.is.null' if method in ('PATCH','DELETE') else ''),({'signed_amount':'1.00'} if table=='journal_lines' else {'result':{}} if table=='idempotency_records' else {'amount':'1.00'}) if method=='PATCH' else {} if method=='POST' else None,token,method=method)
                ok('AT-13 direct '+table+' '+method+' denied',code in (401,403) and denial.get('code')=='42501')
    ok('AT-13 staff cannot create administrator',edge({'action':'create','username':'hacker','display_name':'Hacker','role':'ADMIN','office_ids':[],'password':password},ot)[0]==403)
    ok('AT-13 privileged service RPC denied',rpc('register_staff',{'actor_claims':{},'auth_user_id':admin,'username':'hacker','display_name':'Hacker','account_role':'ADMIN','office_ids':[]},ot)[0]==403)
    ok('AT-13 public signup disabled',request('/auth/v1/signup',{'email':f'public.{b}@staff.invalid','password':password})[0]>=400)
    ok('AT-13 direct role/status/password-flag update denied',request('/rest/v1/staff_profiles?id=eq.'+staff['origin']['id'],{'role':'ADMIN','active':True,'must_change_password':False,'version':99},ot,method='PATCH')[0]==403)
    ok('AT-13 direct office assignment denied',request('/rest/v1/staff_offices',{'business_id':b,'staff_id':staff['origin']['id'],'office_id':office[2]},ot)[0]==403)
    ok('AT-13 staff cannot invoke administrator account update',rpc('admin_manage_staff',{'target_id':ap['id'],'expected_version':ap['version'],'display_name':'Attack','account_role':'STAFF','active':False,'office_ids':[]},ot)[0]==403)
    import base64
    parts=ot.split('.')
    forged=json.loads(base64.urlsafe_b64decode(parts[1]+'='*(-len(parts[1])%4)));forged['sub']=admin
    parts[1]=base64.urlsafe_b64encode(json.dumps(forged).encode()).decode().rstrip('=')
    ok('AT-13 forged JWT fails direct backend verification',rpc('get_session_profile',token='.'.join(parts))[0]==401)
    own={'target_id':ap['id'],'expected_version':ap['version'],'display_name':ap['display_name'],'account_role':'ADMIN','active':False,'office_ids':[]}
    ok('administrator self-disable denied',rpc('admin_manage_staff',own,at)[0]==400)
    own.update(active=True,account_role='STAFF')
    ok('administrator self-demotion denied',rpc('admin_manage_staff',own,at)[0]==400)
    ok('AT-13 metadata cannot grant admin',request('/auth/v1/user',{'data':{'role':'ADMIN','office_ids':office}},ot,method='PUT')[0]==200 and rpc('list_staff_accounts',token=ot)[0]==403)
    # Balanced synthetic journals are fixture setup, not a financial posting command.
    for i,trip in enumerate(trips):
        event=str(uuid.uuid4());amount=['100.00','700.00'][i]
        sql(f"""begin;insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,trip_id,amount,request_id) values('{event}','{b}','DISPATCH','2026-10-11','{ap['id']}','{office[i]}','{trip}',{amount},'{uuid.uuid4()}');
        insert into public.journal_lines(business_id,event_id,party_id,office_id,trip_id,account_purpose,signed_amount) values('{b}','{event}','{customer}','{office[i]}','{trip}','CUSTOMER_RECEIVABLE',{amount}),('{b}','{event}','{owner}','{office[i]}','{trip}','OWNER_PAYABLE',-{amount});commit;""")
    ok('AT-14 null report scope denied',rpc('get_balance_summary',{'scope':None},ot)[0]==403)
    ok('AT-14 staff complete global balance denied',rpc('get_balance_summary',{'scope':'ALL'},ot)[0]==403)
    code,summary=rpc('get_balance_summary',{'scope':'ASSIGNED'},ot)
    ok('AT-14 staff exact scoped totals and explicit label',code==200 and summary['complete'] is False and 'not a complete' in summary['label'] and summary['totals']=={'CUSTOMER_RECEIVABLE':'100.00','OWNER_PAYABLE':'-100.00'})
    code,summary=rpc('get_balance_summary',{'scope':'ALL'},at)
    ok('AT-14 administrator complete exact totals',code==200 and summary['complete'] is True and summary['totals']=={'CUSTOMER_RECEIVABLE':'800.00','OWNER_PAYABLE':'-800.00'})
    ok('AT-14 direct event metadata closed',request('/rest/v1/financial_events?select=*',token=ot,method='GET')[0]==403)
    raw=b'\x89PNG\r\n\x1a\nsynthetic-t03-receipt';path=b+'/synthetic.png'
    ok('trusted synthetic receipt upload',request('/storage/v1/object/receipts/'+path,priv=True,raw=raw)[0]==200)
    sql(f"insert into public.receipt_files(business_id,office_id,trip_id,object_path,mime_type,byte_size,sha256) values('{b}','{office[0]}','{trips[0]}','{path}','image/png',{len(raw)},'{hashlib.sha256(raw).hexdigest()}');")
    for token,allowed in [(ot,True),(dt,True),(xt,False),(None,False)]:
        code,_=request('/storage/v1/object/authenticated/receipts/'+path,token=token,method='GET')
        ok('AT-13 private receipt scope', (code==200)==allowed)
    ok('AT-13 persistent signed-URL bypass blocked',request('/storage/v1/object/sign/receipts/'+path,{'expiresIn':3600},ot)[0]>=400)
    p=profile(ot)
    update={'target_id':p['id'],'expected_version':p['version'],'display_name':p['display_name'],'account_role':'STAFF','active':False,'office_ids':[office[0]]}
    missing=dict(update);missing['expected_version']=None
    ok('null account version rejected',rpc('admin_manage_staff',missing,at)[0]==409)
    ok('administrator disables account',rpc('admin_manage_staff',update,at)[0]==200)
    ok('AT-13 disabled old JWT denied',rpc('get_session_profile',token=ot)[0]==403)
    ok('AT-13 disabled receipt denied',request('/storage/v1/object/authenticated/receipts/'+path,token=ot,method='GET')[0]!=200)
    ok('disabled password sign-in denied',login('origin',real)[0]==403)
    ok('disabled refresh denied',request('/auth/v1/token?grant_type=refresh_token',{'refresh_token':staff['origin']['refresh']})[0]>=400)
    ok('stale account version rejected',rpc('admin_manage_staff',update,at)[0]==409)
    update['expected_version']+=1;update['active']=True
    ok('administrator enables account',rpc('admin_manage_staff',update,at)[0]==200)
    code,data=login('origin',real);ok('enabled account fresh sign-in',code==200);ot=data['access_token'];p=profile(ot)
    reset='Reset!'+secrets.token_urlsafe(20)
    ok('administrator resets password',edge({'action':'reset','target_id':p['id'],'expected_version':p['version'],'password':reset},at)[0]==200)
    ok('reset invalidates old access JWT',rpc('get_session_profile',token=ot)[0]==403)
    ok('old password fails after reset',login('origin',real)[0]>=400)
    code,data=login('origin',reset);ok('reset temporary password sign-in',code==200);ot=data['access_token']
    ok('reset forces password change',profile(ot)['must_change_password'] is True)
    ok('temporary reset token business data denied',request('/rest/v1/trips?select=*',token=ot,method='GET')[1]==[])
    ok('wrong current password denied',edge({'action':'change','current_password':password,'password':real,'expected_version':profile(ot)['version']},ot)[0]==403)
    change(ot,reset,real)
    code,data=login('origin',real);ot=data['access_token'];p=profile(ot)
    update.update(expected_version=p['version'],office_ids=[])
    ok('administrator removes assignments',rpc('admin_manage_staff',update,at)[0]==200)
    ok('lost assignment old JWT denied',rpc('get_session_profile',token=ot)[0]==403)
    ok('lost assignment new login denied',login('origin',real)[0]==403)
    code,accounts=rpc('list_staff_accounts',token=at)
    ok('administrator account list excludes Auth identities and credentials',code==200 and all('auth_user_id' not in x and 'password' not in x for x in accounts))
    audit=sql(f"select coalesce(jsonb_agg(after_data)::text,'[]') from public.audit_events where business_id='{b}';")
    ok('audit contains no passwords or tokens',all(x not in audit for x in [password,real,reset,at]))
    ok('unknown/forged actor fields rejected',edge({'action':'create','username':'hacker','display_name':'Hacker','role':'ADMIN','office_ids':[],'password':password,'actor_id':admin},at)[0]==400)
    # Simulate the SQL/Auth boundary failing after the database lock commits.
    import base64
    claims=json.loads(base64.urlsafe_b64decode(at.split('.')[1]+'='*(-len(at.split('.')[1])%4)))
    xp=profile(xt)
    code,operation=rpc('begin_staff_password',{'actor_claims':claims,'target_id':xp['id'],'expected_version':xp['version'],'is_reset':True},priv=True)
    ok('password preparation locks target before external update',code==200 and rpc('get_session_profile',token=xt)[0]==403)
    ok('pending password account cannot sign in',login('outside',real)[0]==403)
    recovery={'target_id':xp['id'],'expected_version':xp['version']+1,'actor_id':ap['id']}
    ok('ordinary administrator cannot call trusted password recovery',rpc('recover_staff_password',recovery,at)[0]==403)
    recovered='Recovered!'+secrets.token_urlsafe(20)
    ok('trusted recovery resets Auth password',request('/auth/v1/admin/users/'+staff['outside']['auth'],{'password':recovered},priv=True,method='PUT')[0]==200)
    code,result=rpc('recover_staff_password',recovery,priv=True)
    ok('trusted recovery unlocks with forced password change',code==204)
    code,data=login('outside',recovered)
    ok('recovered account still requires change',code==200 and profile(data['access_token'])['must_change_password'] is True)
    change(data['access_token'],recovered,real)
    import sys
    if '--native' in sys.argv:
        config_path=ROOT/'tools/.local/t03-native-config.json'
        config_path.write_text(json.dumps({'APP_ENV':'test','SUPABASE_URL':base,'SUPABASE_PUBLISHABLE_KEY':anon,'APP_BUSINESS_ID':b,'TEST_USERNAME':'outside','TEST_PASSWORD':real}),encoding='utf-8')
        try:
            with (ROOT/'tools/.local/t03-native-auth.log').open('w',encoding='utf-8') as log:
                built=subprocess.run(['powershell','-NoProfile','-File',str(ROOT/'tools/flutter.ps1'),'test','integration_test/staff_sign_in_test.dart','-d','windows','--no-pub','--dart-define-from-file='+str(config_path)],cwd=ROOT/'app',stdout=log,stderr=subprocess.STDOUT)
            ok('native Windows username sign-in and secure logout UI',built.returncode==0)
        finally:config_path.unlink(missing_ok=True)
    if '--trips' in sys.argv:
        from t05_trips import verify
        verify(globals())
    if '--masters' in sys.argv:
        from t04_masters import verify
        verify(globals())
    ok('global logout succeeds',request('/auth/v1/logout?scope=global',token=at)[0]==204)
    ok('logged-out JWT fails live authorization',rpc('get_session_profile',token=at)[0]==403)
    print('T03 API acceptance checks PASS',flush=True)
finally:
    # Local test fixtures only; preserve production immutability by never using this against hosted data.
    request('/storage/v1/object/receipts',{'prefixes':[b+'/synthetic.png']},priv=True,method='DELETE')
    sql(f"""begin;delete from private.trip_reviews where business_id='{b}';delete from private.trip_requests where business_id='{b}';delete from private.trip_sequences where business_id='{b}';delete from private.master_requests where business_id='{b}';delete from private.password_operations where target_id in(select id from public.staff_profiles where business_id='{b}');
    alter table public.audit_events disable trigger user;alter table public.journal_lines disable trigger user;alter table public.financial_events disable trigger user;
    delete from public.audit_events where business_id='{b}';delete from public.journal_lines where business_id='{b}';delete from public.financial_events where business_id='{b}';
    delete from public.expenses where business_id='{b}';delete from public.receipt_files where business_id='{b}';alter table public.issued_documents disable trigger user;delete from public.issued_documents where business_id='{b}';alter table public.issued_documents enable trigger user;delete from public.consignment_cars where business_id='{b}';delete from public.consignments where business_id='{b}';delete from public.stops where business_id='{b}';delete from public.trips where business_id='{b}';delete from public.vehicles where business_id='{b}';delete from public.party_roles where business_id='{b}';delete from public.parties where business_id='{b}';
    delete from public.routes where business_id='{b}';delete from public.expense_categories where business_id='{b}';delete from public.staff_offices where business_id='{b}';delete from public.staff_profiles where business_id='{b}';delete from public.offices where business_id='{b}';delete from public.businesses where id='{b}';
    alter table public.audit_events enable trigger user;alter table public.journal_lines enable trigger user;alter table public.financial_events enable trigger user;commit;""")
    for user in users:request('/auth/v1/admin/users/'+user,priv=True,method='DELETE')
    ok('synthetic identities and business fixtures removed',sql('select (select count(*) from auth.users)+(select count(*) from public.businesses);')=='0')
