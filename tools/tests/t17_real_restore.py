"""AT-32 actual full-stack restore; all inputs are synthetic and local."""
import base64,hashlib,json,os,re,subprocess,sys,time,urllib.request,urllib.error,uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backup'))
from backup import protect,validate_config
from core import BackupError,atomic_json,digest,export_recovery,run_backup
from restore import ArchiveInspector,isolated_port_block,query,recover_archive,restore_database,restore_receipts,target_guard
from transport import Transport
from vault import WindowsVault

ROOT=Path(__file__).resolve().parents[2]
def source_query(sql):
    r=subprocess.run(['docker','exec','-i','-e','PGOPTIONS=-csearch_path=','supabase_db_transport_project','psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=sql.encode(),capture_output=True,check=True)
    return r.stdout.decode().strip()
def ok(name,condition):
    if not condition:raise AssertionError(name)
    print('PASS '+name,flush=True)

def fingerprint(sql):
    tables=sql("select schemaname||'.'||tablename from pg_tables where schemaname in('public','private') and tablename not in('backup_status','backup_runs') order by 1").splitlines()
    values={}
    for table in tables+['auth.users','auth.identities']:
        # Exact JSON strings retain numeric precision; no money enters a float.
        values[table]=sql('select md5(coalesce(string_agg(row_to_json(t)::text,chr(10) order by row_to_json(t)::text),\'\')) from '+table+' t')
    return values

SCHEMA="""select md5(coalesce(string_agg(x,chr(10) order by x),'')) from (
select 'column:'||n.nspname||'.'||c.relname||'.'||a.attname||':'||format_type(a.atttypid,a.atttypmod)||':'||coalesce(pg_get_expr(d.adbin,d.adrelid),'')||':'||a.attnotnull::text x from pg_attribute a join pg_class c on c.oid=a.attrelid join pg_namespace n on n.oid=c.relnamespace left join pg_attrdef d on d.adrelid=c.oid and d.adnum=a.attnum where n.nspname in('public','private','auth','storage') and a.attnum>0 and not a.attisdropped and c.relkind in('r','p','v','m')
union all select 'function:'||n.nspname||'.'||p.proname||':'||pg_get_functiondef(p.oid)||':'||p.proowner::regrole::text||':'||coalesce((select string_agg(v::text,',' order by v::text) from unnest(p.proacl)v),'')||':'||p.prosecdef::text||':'||coalesce(p.proconfig::text,'') from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('public','private') and p.prokind='f'
union all select 'policy:'||schemaname||'.'||tablename||'.'||policyname||':'||roles::text||':'||coalesce(qual,'')||':'||coalesce(with_check,'') from pg_policies where schemaname in('public','private','storage')
union all select 'grant:'||n.nspname||'.'||c.relname||':'||c.relowner::regrole::text||':'||coalesce((select string_agg(v::text,',' order by v::text) from unnest(c.relacl)v),'')||':'||c.relrowsecurity::text||':'||c.relforcerowsecurity::text from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in('public','private')
)s"""

def main():
    e=json.loads(sys.stdin.read());root=Path(e['root']).resolve();project='carrier_restore_'+uuid.uuid4().hex[:12];container='supabase_db_'+project;target_guard(container)
    work=root/'target';(work/'supabase').mkdir(parents=True);config_text=(ROOT/'supabase/config.toml').read_text(encoding='utf-8').replace('project_id = "transport_project"','project_id = "'+project+'"')
    port_base=isolated_port_block()
    for port in range(54320,54330):config_text=config_text.replace(str(port),str(port_base+port-54320))
    config_text=config_text.replace('inspector_port = 8083','inspector_port = 8183')
    (work/'supabase/config.toml').write_text(config_text,encoding='utf-8')
    cli=ROOT/'tools/.local/supabase/supabase.exe'
    prefix='CarrierRecordsBackup/test/'+uuid.uuid4().hex;v=WindowsVault();key=os.urandom(32);targets=[];started=False
    config={'format_version':1,'business_id':e['business_id'],'supabase_url':e['url'],'credential_prefix':prefix,'backup_root':str(root/'encrypted'),'status_path':str(root/'local-status.json'),'daily_time':'18:00','time_zone':'Pacific Standard Time','task_name':'CarrierRecordsBackup-'+str(uuid.uuid4()),'config_path':str(root/'config.json'),'docker_container':e['source_container'],'retention_days':30,'isolated_test':True}
    validate_config(config);protect(root);protect(root/'encrypted');protect(root/'recovery');atomic_json(root/'config.json',config)
    try:
        for name,value in {'service':e['service'],'publishable':e['publishable'],'auth':{'username':'admin','password':e['password']},'database':{'database':'postgres'}}.items():
            target=prefix+'/'+name;v.write(target,json.dumps(value).encode());targets.append(target)
        v.write(prefix+'/key',key);targets.append(prefix+'/key')
        passphrase=base64.b64encode(os.urandom(24)).decode();recovery=root/'recovery/recovery.json';export_recovery(key,recovery,passphrase)
        result=run_backup(config,key,Transport(config,v));ok('AT32 representative T16 encrypted backup created',result['outcome']=='SUCCESS')
        expected=fingerprint(source_query);schema=source_query(SCHEMA)
        counts=json.loads(source_query("select json_build_object('trips',(select count(*) from public.trips),'events',(select count(*) from public.financial_events),'reversals',(select count(*) from public.financial_events where reversal_of_id is not null),'documents',(select count(*) from public.issued_documents),'receipts',(select count(*) from public.receipt_files),'users',(select count(*) from auth.users),'assignments',(select count(*) from public.staff_offices))"))
        ok('AT32 fixture includes real reversals issued documents receipts and assignments',all(counts[k]>0 for k in counts))
        expected_balances=source_query("select coalesce(jsonb_agg(x order by account_purpose),'[]') from (select account_purpose,sum(signed_amount)::text balance from public.journal_lines group by account_purpose)x")
        # PC loss is simulated: remove vault key and original in-memory key before recovery.
        v.delete(prefix+'/key');key=None
        for target in targets:v.delete(target)
        try:v.read(prefix+'/key');ok('AT32 original Windows vault key unavailable',False)
        except RuntimeError:ok('AT32 original Windows vault key unavailable',True)
        archive=next((root/'encrypted/archives').glob('*.crb'));timer=time.perf_counter()
        # Validate wrong recovery material before touching the target.
        try:recover_archive(archive,root/'encrypted',recovery,'incorrect recovery passphrase',ArchiveInspector());ok('AT32 wrong recovery passphrase denied',False)
        except BackupError:ok('AT32 wrong recovery passphrase denied',True)
        key,manifest,database,metadata=recover_archive(archive,root/'encrypted',recovery,passphrase,ArchiveInspector())
        ok('AT32 separate recovery key verifies encrypted archive and all objects',manifest['business_id']==e['business_id'] and len(manifest['receipts'])>0)
        probe=subprocess.run(['docker','exec','-i',e['source_container'],'pg_restore','--file=/dev/null'],input=database,capture_output=True)
        probe_text=probe.stderr.decode(errors='replace').lower();probe_reason='NON_SEEKABLE_INPUT' if 'non-seekable' in probe_text else 'UNEXPECTED_EOF' if 'end of file' in probe_text else 'OTHER_FAILURE' if probe.returncode else 'VALID_STREAM'
        print('AT32 read-only stdin archive probe '+json.dumps({'exit_code':probe.returncode,'reason':probe_reason}),flush=True)
        runtime_images=metadata['local_runtime_images']
        hints={'database':'postgres-version','auth':'gotrue-version','rest':'rest-version','storage':'storage-version'}
        (work/'supabase/.temp').mkdir(exist_ok=True)
        for service,name in hints.items():
            image=runtime_images[service];tag=image.rsplit(':',1)[1]
            if not re.fullmatch(r'[0-9A-Za-z_.-]+',tag):raise AssertionError('Invalid runtime image tag')
            (work/'supabase/.temp'/name).write_text(tag,encoding='utf-8')
            # Reuse installed compatible images under the CLI registry alias.
            alias='public.ecr.aws/supabase/'+image.rsplit('/',1)[-1]
            subprocess.run(['docker','tag',image,alias],capture_output=True,check=True)
        r=subprocess.run([str(cli),'start','--workdir',str(work),'--exclude','studio,postgres-meta,realtime,edge-runtime,mailpit,logflare,vector,supavisor,imgproxy'],capture_output=True)
        started=True
        if r.returncode:
            for line in r.stderr.decode(errors='replace').splitlines():
                if any(word in line.lower() for word in ['failed','unhealthy','error']):
                    line=re.sub(r'\"[^\"]*\"|\x27[^\x27]*\x27','<quoted>',line)
                    line=re.sub(r'https?://\S+|[A-Za-z0-9_+/=$.-]{24,}','<value>',line)
                    print('RESTORE_START_DIAGNOSTIC '+line[:240],flush=True)
            raise AssertionError('AT32 isolated stack startup failed')
        cfg=json.loads(subprocess.run([str(cli),'status','--workdir',str(work),'-o','json'],capture_output=True,text=True,check=True).stdout)
        base=cfg['API_URL'];ok('AT32 target uses independent loopback port',base=='http://127.0.0.1:'+str(port_base+1))
        for service,prefix_name in [('database','db'),('auth','auth'),('rest','rest'),('storage','storage')]:
            original=subprocess.run(['docker','image','inspect','--format','{{.Id}}',runtime_images[service]],capture_output=True,text=True,check=True).stdout.strip()
            actual=subprocess.run(['docker','inspect','--format','{{.Image}}','supabase_'+prefix_name+'_'+project],capture_output=True,text=True,check=True).stdout.strip()
            ok('AT32 target runtime image matches recorded '+service,original==actual)
        services=['supabase_auth_'+project,'supabase_rest_'+project,'supabase_storage_'+project]
        subprocess.run(['docker','stop',*services],capture_output=True,check=True)
        restore_database(container,database,metadata)
        restored_schema=query(container,SCHEMA)
        if restored_schema!=schema:
            detail=SCHEMA[SCHEMA.index('from (')+6:SCHEMA.rindex(')s')]
            source_rows=set(json.loads(source_query('select jsonb_agg(x order by x) from ('+detail+')s')))
            target_rows=set(json.loads(query(container,'select jsonb_agg(x order by x) from ('+detail+')s')))
            print('SCHEMA_DIFFERENCE '+json.dumps({'source_only':[':'.join(x.split(':')[:2]) for x in sorted(source_rows-target_rows)],'target_only':[':'.join(x.split(':')[:2]) for x in sorted(target_rows-source_rows)]}),flush=True)
        ok('AT32 restored schema functions policies grants match source',restored_schema==schema)
        ok('AT32 exact source history staff mappings offices identities restored',fingerprint(lambda q:query(container,q))==expected)
        ok('AT32 exact balances preserved',query(container,"select coalesce(jsonb_agg(x order by account_purpose),'[]') from (select account_purpose,sum(signed_amount)::text balance from public.journal_lines group by account_purpose)x")==expected_balances)
        ok('AT32 obsolete sessions and refresh tokens absent',query(container,'select (not exists(select 1 from auth.sessions) and not exists(select 1 from auth.refresh_tokens))::text')=='true')
        ok('AT32 command owners remain NOLOGIN NOBYPASSRLS',query(container,"select bool_and(not rolcanlogin and not rolbypassrls)::text from pg_roles where rolname like 'carrier_%'")=='true')
        # Storage metadata cannot manufacture file contents. Remove only restored
        # provider object rows, then recreate files through the new private API.
        subprocess.run(['docker','start',*services],capture_output=True,check=True)
        def request(path,body=None,token=None,priv=False,raw=None,method='POST',mime='image/png',upsert=False):
            secret=cfg['SERVICE_ROLE_KEY'] if priv else cfg['ANON_KEY'];headers={'apikey':secret,'Authorization':'Bearer '+(token or secret),'Content-Type':mime if raw is not None else 'application/json'}
            if upsert:headers['x-upsert']='true'
            req=urllib.request.Request(base+path,data=raw if raw is not None else json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
            try:
                with urllib.request.urlopen(req,timeout=30) as response:code=response.status;data=response.read()
            except urllib.error.HTTPError as error:code=error.code;data=error.read()
            if code>=400 and priv and path.startswith('/storage/'):
                try:failure=json.loads(data);label=str(failure.get('code',failure.get('error','UNKNOWN')))
                except Exception:label='UNKNOWN'
                print('RESTORE_STORAGE_FAILURE '+json.dumps({'status':code,'code':label if re.fullmatch(r'[A-Za-z0-9_.-]{1,80}',label) else 'UNKNOWN'}),flush=True)
            try:return code,json.loads(data)
            except Exception:return code,data
        ready=False
        for _ in range(60):
            try:
                if all(request(path,method='GET')[0]==200 for path in ['/auth/v1/health','/rest/v1/','/storage/v1/status']):ready=True;break
            except Exception:pass
            time.sleep(1)
        ok('AT32 restored Auth REST and Storage ready before recovery requests',ready)
        def upload(item,data):
            mime=query(container,"select mime_type from public.receipt_files where object_path='"+item['object_path'].replace("'","''")+"'")
            ok('AT32 decrypted receipt uploaded into target private bucket',request('/storage/v1/object/receipts/'+item['object_path'],priv=True,raw=data,mime=mime,upsert=True)[0]==200)
        copied=restore_receipts(root/'encrypted',key,manifest,upload)
        def login(name):return request('/auth/v1/token?grant_type=password',{'email':name+'.'+e['business_id']+'@staff.invalid','password':e['password']})
        ok('AT32 obsolete access token denied',request('/rest/v1/rpc/get_session_profile',{},e['old_access'])[0]>=400)
        ok('AT32 obsolete refresh token denied',request('/auth/v1/token?grant_type=refresh_token',{'refresh_token':e['old_refresh']})[0]>=400)
        a=login('admin');staff=login('restoreorigin');outside=login('restoreoutside')
        ok('AT32 restored administrator and two restricted staff authenticate freshly',all(x[0]==200 for x in [a,staff,outside]))
        at,st,xt=[x[1]['access_token'] for x in [a,staff,outside]]
        for token in [at,st,xt]:ok('AT32 fresh session resolves restored staff mapping',request('/rest/v1/rpc/get_session_profile',{},token)[0]==200)
        rows=request('/rest/v1/trips?select=id',token=st,method='GET');outs=request('/rest/v1/trips?select=id',token=xt,method='GET')
        expected_ids=json.loads(query(container,"select coalesce(jsonb_agg(id::text),'[]') from public.trips where origin_office_id in(select office_id from public.staff_offices where staff_id=(select id from public.staff_profiles where username='restoreorigin')) or destination_office_id in(select office_id from public.staff_offices where staff_id=(select id from public.staff_profiles where username='restoreorigin'))"))
        ok('AT32 fresh staff RLS matches restored office assignments',rows[0]==200 and {r['id'] for r in rows[1]}==set(expected_ids))
        hidden=set(expected_ids)-{r['id'] for r in outs[1]};ok('AT32 different-office identities retain restricted visibility',outs[0]==200 and len(hidden)>0)
        tid=next(iter(hidden));ok('AT32 direct cross-office operation denied',request('/rest/v1/rpc/authorize_trip_operation',{'trip_id':tid,'operation':'EDIT_FARE'},xt)[0]==403)
        ok('AT32 restored staff direct financial writes denied',request('/rest/v1/financial_events',{},st)[0]==403)
        for item in manifest['receipts']:
            code,data=request('/storage/v1/object/receipts/'+item['object_path'],priv=True,method='GET')
            ok('AT32 restored actual receipt hash and size match',code==200 and len(data)==item['byte_size'] and digest(data)==item['sha256'])
            ok('AT32 anonymous receipt download denied',request('/storage/v1/object/authenticated/receipts/'+item['object_path'],method='GET')[0]!=200)
        receipt=next(item for item in manifest['receipts'] if item['object_path'].endswith('/synthetic.png'))
        ok('AT32 assigned staff can retrieve restored receipt',request('/storage/v1/object/authenticated/receipts/'+receipt['object_path'],token=st,method='GET')[0]==200)
        ok('AT32 cross-office staff cannot retrieve restored receipt',request('/storage/v1/object/authenticated/receipts/'+receipt['object_path'],token=xt,method='GET')[0]!=200)
        docs=json.loads(query(container,'select jsonb_agg(jsonb_build_object(\'id\',id,\'snapshot\',snapshot,\'digest\',content_digest)) from public.issued_documents'))
        # JSON canonical digest is server-defined; compare every retained digest
        # and snapshot with the source, then exercise the actual reprint RPC.
        source_docs=source_query('select jsonb_agg(jsonb_build_object(\'id\',id,\'snapshot\',snapshot,\'digest\',content_digest) order by id) from public.issued_documents')
        ok('AT32 immutable issued snapshots and digests identical',query(container,'select jsonb_agg(jsonb_build_object(\'id\',id,\'snapshot\',snapshot,\'digest\',content_digest) order by id) from public.issued_documents')==source_docs)
        ok('AT32 restored issued document reprint authorized',request('/rest/v1/rpc/get_issued_document',{'document_id':docs[0]['id']},at)[0]==200)
        try:restore_database(container,database,metadata);ok('AT32 refuses nonempty target overwrite',False)
        except BackupError as err:ok('AT32 refuses nonempty target overwrite',err.code=='RESTORE_TARGET_NOT_EMPTY')
        elapsed=time.perf_counter()-timer
        evidence={'recovery_seconds':round(elapsed,3),'counts':counts,'receipt_objects_restored':copied,'schema_equal':True,'history_equal':True,'balances_equal':True,'separate_key_recovery':True,'target_project':project,'target_url':base,'physical_pc_loss_simulated':True,'production_restore':False,'runtime_images':runtime_images,'original_vault_credentials_deleted':True,'stdin_archive_probe':{'exit_code':probe.returncode,'reason':probe_reason}}
        atomic_json(root/'evidence.json',evidence);atomic_json(ROOT/'tools/.local/t17-evidence.json',evidence)
        print('AT32 measured '+json.dumps(evidence),flush=True)
    except BaseException as error:
        if hasattr(error,'diagnostic'):print('RESTORE_DIAGNOSTIC '+error.diagnostic,flush=True)
        if hasattr(error,'restore_stage'):print('RESTORE_STAGE '+error.restore_stage,flush=True)
        if started:
            logs=subprocess.run(['docker','logs','--tail','120',container],capture_output=True)
            for line in (logs.stdout+logs.stderr).decode(errors='replace').splitlines():
                if ('server process' in line and 'signal' in line) or 'reinitializing' in line or 'database system was interrupted' in line:
                    print('RESTORE_SERVER_EVENT '+line[:240],flush=True)
            for service in ['auth','storage','rest']:
                logs=subprocess.run(['docker','logs','--tail','40','supabase_'+service+'_'+project],capture_output=True)
                for line in (logs.stdout+logs.stderr).decode(errors='replace').splitlines():
                    try:
                        item=json.loads(line);details=item.get('error',{});details=details if isinstance(details,dict) else {}
                        if item.get('level') in [50,60,'error','fatal']:
                            safe={k:str(details.get(k,'UNKNOWN')) for k in ['name','code']}
                            safe={k:v if re.fullmatch(r'[A-Za-z0-9_.-]{1,80}',v) else 'UNKNOWN' for k,v in safe.items()}
                            print('RESTORE_PROVIDER_ERROR '+service+' '+json.dumps(safe),flush=True)
                    except (ValueError,AttributeError):pass
        raise
    finally:
        if started:
            # Explicit unique project only; never --all or the source project.
            target_guard(container)
            subprocess.run([str(cli),'stop','--workdir',str(work),'--project-id',project,'--no-backup'],capture_output=True,check=True)
            ok('AT32 isolated target containers removed',subprocess.run(['docker','ps','-a','--filter','name='+project,'--format','{{.Names}}'],capture_output=True,text=True,check=True).stdout.strip()=='')
        (work/'supabase/.temp/start-secrets').unlink(missing_ok=True)
        for target in targets:v.delete(target)
        print('PASS AT32 temporary backup credentials removed',flush=True)

if __name__=='__main__':main()
