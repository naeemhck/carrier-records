"""Actual Windows vault, local pg_dump/Auth, private Storage and encrypted archive checks."""
import base64,copy,json,os,subprocess,sys,uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backup'))
from core import BackupError,atomic_json,digest,export_recovery,key_id,read_manifest,recover_key,run_backup,unseal,verify_archive
from backup import protect,validate_config
from vault import WindowsVault
from transport import Transport

def main():
    e=json.loads(sys.stdin.read());b=e['business_id'];root=Path(e['root']).resolve();root.mkdir(parents=True,exist_ok=True);v=WindowsVault();prefix='CarrierRecordsBackup/test/'+str(uuid.uuid4());key=os.urandom(32)
    config={'format_version':1,'business_id':b,'supabase_url':e['url'],'credential_prefix':prefix,'backup_root':str(root/'archives-root'),'status_path':str(root/'local-status.json'),'daily_time':'18:00','time_zone':'Pacific Standard Time','task_name':'CarrierRecordsBackup-'+str(uuid.uuid4()),'config_path':str(root/'config.json'),'docker_container':'supabase_db_transport_project','retention_days':30,'isolated_test':True,'python_exe':sys.executable}
    creds={'service':e['service'],'publishable':e['publishable'],'auth':{'username':'admin','password':e['password']},'database':{'database':'postgres'}}
    def ok(name,value):
        if not value:raise AssertionError(name)
        print('PASS '+name,flush=True)
    validate_config(config)
    protect(root);protect(root/'archives-root');atomic_json(root/'config.json',config)
    targets=[];results=[];schedule_installed=False
    try:
        for name,value in creds.items():target=prefix+'/'+name;v.write(target,json.dumps(value).encode());targets.append(target)
        v.write(prefix+'/key',key);targets.append(prefix+'/key')
        recovery=root/'separate-recovery'/'recovery.json';recovery.parent.mkdir();passphrase=base64.b64encode(os.urandom(24)).decode();export_recovery(key,recovery,passphrase)
        ok('AT31 separate portable recovery key protected by passphrase',recover_key(recovery,passphrase)==v.read(prefix+'/key') and not recovery.is_relative_to(root/'archives-root'))
        try:recover_key(recovery,'invalid passphrase');ok('AT31 wrong recovery passphrase denied',False)
        except BackupError:ok('AT31 wrong recovery passphrase denied',True)
        for run in range(2):
            t=Transport(config,v);r=run_backup(config,key,t);results.append(r)
            ok('AT31 actual database Auth and receipt encrypted backup '+str(run),r['outcome']=='SUCCESS')
        ok('AT31 second backup copies no unchanged receipts',results[0]['metrics']['downloaded_receipts']>0 and results[1]['metrics']['downloaded_receipts']==0 and results[1]['metrics']['reused_receipts']==results[0]['metrics']['downloaded_receipts']+results[0]['metrics']['reused_receipts'])
        archive=next((root/'archives-root/archives').glob('*.crb'));t=Transport(config,v);manifest=verify_archive(archive,key,root/'archives-root',t)
        ok('AT31 real archive manifest matches business and no restoration claimed',manifest['business_id']==b and not manifest['restoration_verified'])
        with unseal(archive,key,'archive') as plain:
            import zipfile
            with zipfile.ZipFile(plain) as z:
                db=z.read('database.dump');metadata=json.loads(z.read('roles.json'))
                q=['docker','exec','-i','supabase_db_transport_project','pg_restore','--list'];toc=subprocess.run(q,input=db,capture_output=True,check=True).stdout
                ok('AT31 actual dump contains Auth identities and staff office mappings',b'TABLE DATA auth users' in toc and b'TABLE DATA auth identities' in toc and b'TABLE DATA public staff_offices' in toc and metadata['identity_count']>0)
                ok('AT31 active session and refresh token data excluded',b'TABLE DATA auth sessions' not in toc and b'TABLE DATA auth refresh_tokens' not in toc)
        cipher=archive.read_bytes();ok('AT31 archives contain no plaintext password database magic or receipt bytes',e['password'].encode() not in cipher and b'PGDMP' not in cipher and b'synthetic-t03-receipt' not in cipher)
        try:read_manifest(archive,os.urandom(32));ok('AT31 wrong archive key denied',False)
        except BackupError:ok('AT31 wrong archive key denied',True)
        # Real new receipt is supplied by the parent through the same Storage/reference flow.
        t=Transport(config,v);t.authorize()
        new=b'\x89PNG\r\n\x1a\nsynthetic-t16-incremental';path=b+'/t16-new.png'
        req=__import__('urllib.request',fromlist=['Request']).Request(config['supabase_url']+'/storage/v1/object/receipts/'+path,data=new,headers={'apikey':e['service'],'Authorization':'Bearer '+e['service'],'Content-Type':'image/png'},method='POST')
        with __import__('urllib.request',fromlist=['urlopen']).urlopen(req,timeout=30):pass
        sql="insert into public.receipt_files(business_id,office_id,object_path,mime_type,byte_size,sha256) values('"+b+"','"+e['office_id']+"','"+path+"','image/png',"+str(len(new))+",'"+digest(new)+"');"
        subprocess.run(['docker','exec','-i','supabase_db_transport_project','psql','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=sql.encode(),capture_output=True,check=True);t.close()
        r=run_backup(config,key,Transport(config,v));ok('AT31 only new real receipt downloaded',r['outcome']=='SUCCESS' and r['metrics']['downloaded_receipts']==1 and r['metrics']['reused_receipts']==results[1]['metrics']['reused_receipts']);last=r['last_verified_success_at']
        class Interrupted(Transport):
            def dump(self,f):raise KeyboardInterrupt()
        try:run_backup(config,key,Interrupted(config,v))
        except KeyboardInterrupt:pass
        s=json.loads((root/'local-status.json').read_text());ok('AT31 actual interrupted job reports failure preserves verified success',s['outcome']=='FAILED' and s['safe_error_code']=='INTERRUPTED' and s['last_verified_success_at']==last)
        class ReceiptFailure(Transport):
            def receipts(self):return [{'object_path':b+'/missing.png','sha256':'a'*64,'byte_size':20}]
        failure=run_backup(config,key,ReceiptFailure(config,v));ok('AT31 failed real object download pending and no false success',failure['outcome']=='FAILED' and failure['pending_receipt_count']==1 and failure['last_verified_success_at']==last)
        class ReportFailure(Transport):
            def report(self,run_id,outcome,*a):
                if outcome=='SUCCESS':raise BackupError('STATUS_REPORT_FAILED')
                return super().report(run_id,outcome,*a)
        failure=run_backup(config,key,ReportFailure(config,v));ok('AT31 status delivery failure not reported successful',failure['outcome']=='FAILED' and failure['last_verified_success_at']==last)
        v.write(prefix+'/auth',json.dumps({'username':'outside','password':e['password']}).encode())
        try:
            denied=run_backup(config,key,Transport(config,v));ok('AT31 configured staff identity cannot run privileged export',denied['outcome']=='FAILED' and denied['safe_error_code']=='AUTHORIZATION_FAILED' and denied['last_verified_success_at']==last)
        finally:v.write(prefix+'/auth',json.dumps(creds['auth']).encode())
        abrupt=subprocess.run([sys.executable,str(Path(__file__)),'--abrupt-test'],input=json.dumps(config),text=True,capture_output=True)
        s=json.loads((root/'local-status.json').read_text());ok('AT31 abrupt exit leaves RUNNING with unchanged verified success',abrupt.returncode==17 and s['outcome']=='RUNNING' and s['last_verified_success_at']==last)
        # Verify a temporary real per-user schedule. No production schedule is left installed.
        script=Path(__file__).resolve().parents[1]/'backup/install-schedule.ps1'
        invalid=dict(config,unknown_field='rejected');atomic_json(root/'invalid-config.json',invalid)
        denied_registration=subprocess.run(['powershell','-NoProfile','-File',str(script),'-ConfigPath',str(root/'invalid-config.json'),'-PythonExe',sys.executable],capture_output=True,text=True)
        absent=subprocess.run(['powershell','-NoProfile','-Command',"if(Get-ScheduledTask -TaskName '"+config['task_name']+"' -ErrorAction SilentlyContinue){exit 1}"],capture_output=True)
        ok('AT31 invalid configuration cannot register a task',denied_registration.returncode!=0 and absent.returncode==0 and 'CONFIGURATION_INVALID' in denied_registration.stdout)
        reg=subprocess.run(['powershell','-NoProfile','-File',str(script),'-ConfigPath',str(root/'config.json'),'-PythonExe',sys.executable],capture_output=True,text=True)
        if reg.returncode:
            raise AssertionError('AT31 schedule registration failed; no active schedule claimed')
        else:
            schedule_installed=True
            query=subprocess.run(['powershell','-NoProfile','-Command',"$t=Get-ScheduledTask -TaskName '"+config['task_name']+"';@{active=($t.State -ne 'Disabled');start_when_available=$t.Settings.StartWhenAvailable;triggers=@($t.Triggers).Count;logon_type=[string]$t.Principal.LogonType}|ConvertTo-Json -Compress"],capture_output=True,text=True,check=True)
            state=json.loads(query.stdout);ok('AT31 temporary daily logon hourly catchup schedule active',state['active'] and state['start_when_available'] and state['triggers']==3 and state['logon_type']=='Interactive')
            # Simulated offline gap, then an actual Task Scheduler run while online.
            from datetime import datetime,timezone,timedelta
            import time
            old=json.loads((root/'local-status.json').read_text());old_id=old['run_id'];old['last_verified_success_at']=(datetime.now(timezone.utc)-timedelta(days=2)).isoformat();atomic_json(root/'local-status.json',old)
            subprocess.run(['powershell','-NoProfile','-Command',"Start-ScheduledTask -TaskName '"+config['task_name']+"'"],capture_output=True,check=True)
            deadline=time.monotonic()+60;current=old
            while time.monotonic()<deadline:
                time.sleep(1)
                current=json.loads((root/'local-status.json').read_text())
                if current['run_id']!=old_id and current['outcome']!='RUNNING':break
            ok('AT31 actual online scheduled catchup after simulated missed run',current['run_id']!=old_id and current['outcome']=='SUCCESS')
            no_repeat=subprocess.run([sys.executable,str(script.parent/'backup.py'),'run','--config',str(root/'config.json'),'--scheduled'],capture_output=True,text=True)
            ok('AT31 scheduled retry skips an already verified daily backup',no_repeat.returncode==0 and json.loads(no_repeat.stdout)['outcome']=='NOT_DUE' and json.loads((root/'local-status.json').read_text())['run_id']==current['run_id'])
        summary={'successful_backups':3,'manifest_receipts':len(manifest['receipts']),'second_receipt_download_bytes':results[1]['metrics']['receipt_bytes'],'new_receipt_download_bytes':r['metrics']['receipt_bytes'],'separate_recovery_key':True,'temporary_schedule_registered':schedule_installed,'production_schedule_active':False,'restoration_verified':False}
        atomic_json(root/'evidence.json',summary)
        for f in root.rglob('*'):
            if f.is_file() and f.suffix not in('.lock',):
                contents=f.read_bytes()
                ok('AT31 local helper file contains no plaintext privileged secret',all(x not in contents for x in [key,e['password'].encode(),e['service'].encode()]))
    finally:
        if schedule_installed:
            subprocess.run(['powershell','-NoProfile','-Command',"Unregister-ScheduledTask -TaskName '"+config['task_name']+"' -Confirm:$false"],capture_output=True,check=True)
            check=subprocess.run(['powershell','-NoProfile','-Command',"if(Get-ScheduledTask -TaskName '"+config['task_name']+"' -ErrorAction SilentlyContinue){exit 1}"],capture_output=True)
            ok('AT31 temporary schedule removed',check.returncode==0)
        for target in targets:v.delete(target)
        ok('AT31 temporary vault credentials removed',all(_missing(v,x) for x in targets))
def _missing(v,target):
    try:v.read(target);return False
    except RuntimeError:return True
if __name__=='__main__':
    if '--abrupt-test' in sys.argv:
        c=json.loads(sys.stdin.read());v=WindowsVault()
        class Abrupt(Transport):
            def dump(self,f):
                super().dump(f)
                os._exit(17)
        run_backup(c,v.read(c['credential_prefix']+'/key'),Abrupt(c,v))
    else:main()
