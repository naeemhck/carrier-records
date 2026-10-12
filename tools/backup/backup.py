"""Separate Windows administrator utility, never bundled into the staff app."""
import argparse,base64,getpass,json,os,re,subprocess,sys,uuid
from pathlib import Path
from core import BackupError,atomic_json,export_recovery,run_backup
from vault import WindowsVault
from transport import Transport

def in_git_workspace(path):
    path=Path(path).resolve()
    return any((p/'.git').exists() for p in [path,*path.parents])
def protect(path):
    path=Path(path).resolve();path.mkdir(parents=True,exist_ok=True)
    sid=subprocess.run(['powershell','-NoProfile','-Command','[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value'],capture_output=True,text=True,check=True).stdout.strip()
    reset=subprocess.run(['icacls',str(path),'/reset'],capture_output=True)
    if reset.returncode:raise BackupError('LOCAL_IO_FAILED')
    r=subprocess.run(['icacls',str(path),'/inheritance:r','/grant:r','*'+sid+':(OI)(CI)F','*S-1-5-18:(OI)(CI)F'],capture_output=True)
    if r.returncode:raise BackupError('LOCAL_IO_FAILED')
def validate_config(c):
    allowed={'supabase_url','format_version','business_id','credential_prefix','backup_root','status_path','daily_time','time_zone','task_name','config_path','postgres_bin','docker_container','retention_days','egress_budget_bytes','other_egress_bytes','isolated_test','python_exe'}
    if not isinstance(c,dict):raise BackupError('CONFIGURATION_INVALID')
    if c.get('format_version')!=1 or set(c)-allowed:raise BackupError('CONFIGURATION_INVALID')
    required=['supabase_url','business_id','credential_prefix','backup_root','status_path','daily_time','time_zone','task_name','config_path']
    if any(not isinstance(c.get(k),str) or not c[k].strip() for k in required):raise BackupError('CONFIGURATION_INVALID')
    from transport import validate_endpoint
    validate_endpoint(c['supabase_url'])
    try:uuid.UUID(c['business_id'])
    except ValueError:raise BackupError('CONFIGURATION_INVALID') from None
    if type(c.get('retention_days',30)) is not int or ('isolated_test' in c and type(c['isolated_test']) is not bool):raise BackupError('CONFIGURATION_INVALID')
    if any(not c.get(k) for k in required) or not re.fullmatch(r'([01]\d|2[0-3]):[0-5]\d',c['daily_time']) or not 1<=c.get('retention_days',30)<=365:raise BackupError('CONFIGURATION_INVALID')
    if not re.fullmatch(r'CarrierRecordsBackup-[0-9a-f-]{36}',c['task_name']):raise BackupError('CONFIGURATION_INVALID')
    root=Path(c['backup_root']).resolve()
    if Path(c['status_path']).resolve()!=Path(c['config_path']).resolve().parent/'local-status.json':raise BackupError('CONFIGURATION_INVALID')
    if root==Path(root.anchor) or root==Path.home():raise BackupError('CONFIGURATION_INVALID')
    if not c.get('isolated_test') and (in_git_workspace(root) or in_git_workspace(c['config_path'])):raise BackupError('CONFIGURATION_INVALID')
def setup(args):
    cfgpath=Path(args.config).resolve()
    if cfgpath.exists():raise BackupError('CONFIGURATION_INVALID')
    business=str(uuid.UUID(input('Business UUID: ').strip()));base=input('Supabase HTTPS URL (or loopback local URL): ').strip();backup=Path(input('Backup directory outside the project: ').strip()).resolve();recovery=Path(input('NEW recovery key file on a separate recovery location: ').strip()).resolve()
    if in_git_workspace(backup) or in_git_workspace(cfgpath) or in_git_workspace(recovery) or recovery.is_relative_to(backup) or recovery.exists():raise BackupError('CONFIGURATION_INVALID')
    identifier=str(uuid.uuid4());prefix='CarrierRecordsBackup/'+business+'/'+identifier
    user=input('Managed administrator username: ').strip().lower();password=getpass.getpass('Administrator password (hidden): ');publishable=getpass.getpass('Publishable key (hidden): ');service=getpass.getpass('Service/secret key (hidden): ')
    docker=input('Use existing loopback Docker PostgreSQL utilities? [y/N]: ').strip().lower()=='y'
    if docker:
        if not base.startswith(('http://127.0.0.1:','http://localhost:')):raise BackupError('CONFIGURATION_INVALID')
        container=input('Existing local database container [supabase_db_transport_project]: ').strip() or 'supabase_db_transport_project'
        pg='';db={'database':'postgres'}
    else:
        pg=input('PostgreSQL client bin directory containing pg_dump/pg_restore/psql: ').strip();host=input('Database host: ').strip();port=int(input('Database port: ').strip());database=input('Database name: ').strip();dbuser=input('Database utility user: ').strip();dbpassword=getpass.getpass('Database password (hidden): ')
        db={'host':host,'port':port,'database':database,'user':dbuser,'password':dbpassword,'sslmode':'disable' if host in('127.0.0.1','localhost') else 'verify-full'}
        if host not in('127.0.0.1','localhost'):db['sslrootcert']=input('Database CA certificate path for TLS verification: ').strip()

    time=input('Daily local backup time HH:MM [18:00]: ').strip() or '18:00';zone=subprocess.run(['powershell','-NoProfile','-Command','(Get-TimeZone).Id'],capture_output=True,text=True,check=True).stdout.strip()
    c={'format_version':1,'business_id':business,'supabase_url':base,'credential_prefix':prefix,'backup_root':str(backup),'status_path':str(cfgpath.parent/'local-status.json'),'daily_time':time,'time_zone':zone,'task_name':'CarrierRecordsBackup-'+identifier,'config_path':str(cfgpath),'postgres_bin':pg,'retention_days':30,'egress_budget_bytes':5000000000}
    passphrase=getpass.getpass('Separate recovery passphrase, at least 12 characters (hidden): ')
    if passphrase!=getpass.getpass('Repeat recovery passphrase (hidden): ') or len(passphrase)<12:raise BackupError('CONFIGURATION_INVALID')
    if docker:c['docker_container']=container
    if backup.exists() and any(backup.iterdir()):raise BackupError('CONFIGURATION_INVALID')
    validate_config(c);protect(cfgpath.parent);protect(backup);recovery.parent.mkdir(parents=True,exist_ok=True)
    v=WindowsVault();key=os.urandom(32);values={'auth':{'username':user,'password':password},'publishable':publishable,'service':service,'database':db};written=[]
    try:
        for name,value in values.items():v.write(prefix+'/'+name,json.dumps(value).encode());written.append(prefix+'/'+name)
        v.write(prefix+'/key',key);written.append(prefix+'/key')
        t=Transport(c,v)
        try:t.authorize()
        finally:t.close()
        export_recovery(key,recovery,passphrase)
        atomic_json(cfgpath,c)
    except BaseException:
        for name in written:v.delete(name)
        raise
    print(json.dumps({'configured':True,'schedule_active':False,'recovery_key_exported':True,'reminder':'Copy recovery material off this PC separately from encrypted backups. T17 restoration is still required.'}))
def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['setup','run','check','update-auth']);p.add_argument('--config',required=True);p.add_argument('--scheduled',action='store_true');args=p.parse_args()
    c=None;validated=False
    try:
        if args.action=='setup':setup(args);return 0
        c=json.loads(Path(args.config).read_text(encoding='utf-8-sig'));validate_config(c);validated=True;vault=WindowsVault()
        if args.action=='update-auth':
            target=c['credential_prefix']+'/auth';previous=vault.read(target)
            value={'username':input('Managed administrator username: ').strip().lower(),'password':getpass.getpass('New current administrator password (hidden): ')}
            vault.write(target,json.dumps(value).encode())
            t=None
            try:t=Transport(c,vault);t.authorize()
            except BaseException:vault.write(target,previous);raise
            finally:
                if t is not None:t.close()
            print(json.dumps({'administrator_credential_updated':True,'encryption_key_changed':False}));return 0
        if args.action=='check':
            t=Transport(c,vault)
            try:t.authorize()
            finally:t.close()
            print(json.dumps({'administrator_verified':True}));return 0
        # A file lock survives interruption safely: Windows releases it at process exit.
        import msvcrt
        lock_path=Path(c['status_path']).parent/'run.lock'
        with lock_path.open('a+b') as lock:
            lock.seek(0);lock.write(b'0');lock.flush();lock.seek(0)
            try:msvcrt.locking(lock.fileno(),msvcrt.LK_NBLCK,1)
            except OSError:print(json.dumps({'outcome':'ALREADY_RUNNING'}));return 0
            try:result=run_backup(c,vault.read(c['credential_prefix']+'/key'),Transport(c,vault),args.scheduled)
            finally:lock.seek(0);msvcrt.locking(lock.fileno(),msvcrt.LK_UNLCK,1)
        print(json.dumps(result));return 1 if result['outcome']=='FAILED' else 0
    except BaseException as e:
        code=e.code if isinstance(e,BackupError) else 'INTERRUPTED' if isinstance(e,(KeyboardInterrupt,SystemExit)) else 'CREDENTIAL_UNAVAILABLE'
        # No exceptions, credential text, endpoint bodies or dump output enter logs.
        if validated and args.action=='run':
            try:
                from core import utcnow
                status_path=Path(c['status_path']);old=json.loads(status_path.read_text(encoding='utf-8')) if status_path.exists() else {}
                atomic_json(status_path,{'business_id':c['business_id'],'outcome':'FAILED','run_id':str(uuid.uuid4()),'last_attempt_at':utcnow().isoformat(),'last_verified_success_at':old.get('last_verified_success_at'),'safe_error_code':code})
            except Exception:pass
        print(json.dumps({'outcome':'FAILED','safe_error_code':code}));return 1
if __name__=='__main__':sys.exit(main())
