"""Trusted helper I/O: server credentials are read from the Windows vault only."""
import json,os,re,subprocess,urllib.request,urllib.error,urllib.parse
from pathlib import Path
from core import BackupError

EXCLUDED=['auth.sessions','auth.refresh_tokens','auth.flow_state','auth.one_time_tokens','auth.mfa_challenges','auth.mfa_amr_claims','auth.sso_sessions','auth.oauth_authorizations','auth.oauth_client_states']
def validate_endpoint(value):
    if not isinstance(value,str) or not value.strip() or value!=value.strip():raise BackupError('CONFIGURATION_INVALID')
    try:
        u=urllib.parse.urlparse(value.rstrip('/'));port=u.port
        if not u.hostname or u.username or u.password or u.query or u.fragment or u.path or (u.scheme!='https' and not(u.scheme=='http' and u.hostname in('127.0.0.1','localhost'))):raise BackupError('CONFIGURATION_INVALID')
    except ValueError:raise BackupError('CONFIGURATION_INVALID') from None
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args):return None
class Transport:
    excluded_sessions=EXCLUDED
    def __init__(self,config,vault):
        self.config=config;self.vault=vault;self.http_bytes=0;self.token=None;self.admin_id=None
        prefix=config['credential_prefix'];self.credentials={k:json.loads(vault.read(prefix+'/'+k)) for k in ['auth','database','service','publishable']}
        self.base=config['supabase_url'].rstrip('/');validate_endpoint(config['supabase_url'])
        self.opener=urllib.request.build_opener(NoRedirect());self.business=config['business_id']
        if not re.fullmatch(r'[0-9a-f-]{36}',self.business):raise BackupError('CONFIGURATION_INVALID')
    def http(self,path,body=None,privileged=False,token=None,method='POST'):
        key=self.credentials['service'] if privileged else self.credentials['publishable']
        req=urllib.request.Request(self.base+path,data=None if body is None else json.dumps(body).encode(),headers={'apikey':key,'Authorization':'Bearer '+(token or key),'Content-Type':'application/json'},method=method)
        try:
            with self.opener.open(req,timeout=120) as r:data=r.read()
        except Exception:raise BackupError('STATUS_REPORT_FAILED' if path.endswith('record_backup_status') else 'AUTHORIZATION_FAILED' if path.startswith('/auth/') or path.endswith('get_session_profile') else 'RECEIPT_COPY_FAILED') from None
        if not path.startswith('/storage/'):self.http_bytes+=len(data)
        return data
    def authorize(self):
        a=self.credentials['auth'];email=a['username']+'.'+self.business+'@staff.invalid'
        auth=json.loads(self.http('/auth/v1/token?grant_type=password',{'email':email,'password':a['password']}));self.token=auth['access_token']
        p=json.loads(self.http('/rest/v1/rpc/get_session_profile',{},token=self.token))
        if p.get('role')!='ADMIN' or p.get('must_change_password') or p.get('business_id')!=self.business:raise BackupError('AUTHORIZATION_FAILED')
        self.admin_id=p['id']
        # Match API and database identity. The pilot has exactly one business.
        identity=self.query("select json_build_object('count',count(*),'matches',coalesce(bool_and(id='"+self.business+"'::uuid),false)) from public.businesses;")
        if identity['count']!=1 or not identity['matches']:raise BackupError('AUTHORIZATION_FAILED')
    def command(self,tool,args):
        cfg=self.config
        if cfg.get('docker_container'):
            if not self.base.startswith(('http://127.0.0.1:','http://localhost:')) or not re.fullmatch(r'supabase_db_[A-Za-z0-9_-]+',cfg['docker_container']):raise BackupError('CONFIGURATION_INVALID')
            return ['docker','exec','-i',cfg['docker_container'],tool,'-U','postgres']+args,os.environ.copy()
        pg=Path(cfg['postgres_bin'])/(tool+'.exe')
        if not pg.is_file():raise BackupError('DATABASE_EXPORT_FAILED')
        d=self.credentials['database'];e=os.environ.copy();e.update(PGHOST=d['host'],PGPORT=str(d['port']),PGUSER=d['user'],PGPASSWORD=d['password'],PGDATABASE=d['database'],PGSSLMODE=d.get('sslmode','verify-full'))
        if d.get('sslrootcert'):e['PGSSLROOTCERT']=d['sslrootcert']
        return [str(pg)]+args,e
    def query(self,sql):
        args,env=self.command('psql',['-d',self.credentials['database']['database'],'-At','-v','ON_ERROR_STOP=1'])
        r=subprocess.run(args,input=sql.encode(),stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=120)
        if r.returncode:raise BackupError('DATABASE_EXPORT_FAILED')
        try:return json.loads(r.stdout)
        except Exception:raise BackupError('DATABASE_EXPORT_FAILED') from None
    def dump(self,destination):
        args,env=self.command('pg_dump',['-d',self.credentials['database']['database'],'--format=custom','--compress=0']+['--exclude-table-data='+x for x in EXCLUDED])
        try:
            r=subprocess.run(args,stdout=destination,stderr=subprocess.PIPE,env=env,timeout=3600)
            if r.returncode:raise BackupError('DATABASE_EXPORT_FAILED')
        except (OSError,subprocess.TimeoutExpired):raise BackupError('DATABASE_EXPORT_FAILED') from None
    def verify_dump(self,data):
        if not data.startswith(b'PGDMP'):raise BackupError('ARCHIVE_VERIFY_FAILED')
        args,env=self.command('pg_restore',['--list'])
        # pg_restore has no -U with --list on a stdin custom archive.
        if self.config.get('docker_container'):args=['docker','exec','-i',self.config['docker_container'],'pg_restore','--list']
        r=subprocess.run(args,input=data,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=120)
        if r.returncode or b'TABLE DATA auth users' not in r.stdout or b'TABLE DATA auth identities' not in r.stdout:raise BackupError('ARCHIVE_VERIFY_FAILED')
    def metadata(self):
        metadata=self.query("select jsonb_build_object('postgres_version',version(),'roles',(select jsonb_agg(jsonb_build_object('name',rolname,'login',rolcanlogin,'inherit',rolinherit,'bypass_rls',rolbypassrls)) from pg_roles),'memberships',(select coalesce(jsonb_agg(jsonb_build_object('role',r.rolname,'member',m.rolname,'admin_option',g.admin_option,'inherit_option',g.inherit_option,'set_option',g.set_option)),'[]') from pg_auth_members g join pg_roles r on r.oid=g.roleid join pg_roles m on m.oid=g.member),'migration_versions',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),'identity_count',(select count(*) from auth.users),'identity_mapping_count',(select count(*) from auth.identities));")
        if self.config.get('docker_container'):
            project=self.config['docker_container'].removeprefix('supabase_db_')
            images={}
            for key,service in [('database','db'),('auth','auth'),('rest','rest'),('storage','storage')]:
                r=subprocess.run(['docker','inspect','--format','{{.Config.Image}}','supabase_'+service+'_'+project],capture_output=True,text=True,check=True)
                images[key]=r.stdout.strip()
            metadata['local_runtime_images']=images
        return metadata
    def receipts(self):
        return self.query("select coalesce(jsonb_agg(jsonb_build_object('object_path',object_path,'sha256',sha256,'byte_size',byte_size)),'[]') from public.receipt_files where business_id='"+self.business+"';")
    def usage(self):
        return self.query("select jsonb_build_object('database_bytes',pg_database_size(current_database()),'storage_bytes',(select coalesce(sum((metadata->>'size')::bigint),0) from storage.objects));")
    def download(self,path):
        if not path.startswith(self.business+'/') or '..' in path:raise BackupError('RECEIPT_COPY_FAILED')
        return self.http('/storage/v1/object/receipts/'+urllib.parse.quote(path,safe='/'),privileged=True,method='GET')
    def report(self,run_id,outcome,metrics,pending,code,archive_digest):
        if self.admin_id is None:raise BackupError('AUTHORIZATION_FAILED')
        schedule={'active':False,'daily_time':self.config['daily_time'],'time_zone':self.config['time_zone']}
        script=Path(__file__).with_name('schedule-status.ps1')
        if script.exists():
            r=subprocess.run(['powershell','-NoProfile','-File',str(script),'-TaskName',self.config['task_name'],'-ConfigPath',self.config['config_path']],capture_output=True,text=True,timeout=30)
            if r.returncode==0:
                try:schedule.update(json.loads(r.stdout))
                except Exception:pass
        self.http('/rest/v1/rpc/record_backup_status',{'business_id':self.business,'admin_staff_id':self.admin_id,'run_id':run_id,'outcome':outcome,'verified_digest':archive_digest,'metrics':metrics,'pending_receipts':pending,'safe_error_code':code,'schedule':schedule},privileged=True)
    def close(self):
        if self.token:
            try:self.http('/auth/v1/logout?scope=local',None,token=self.token)
            except Exception:pass
