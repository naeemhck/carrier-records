"""Isolated backup-engine tests. Synthetic dump mocks do not prove a restore."""
import copy,io,json,os,sys,tempfile,unittest,uuid
from datetime import datetime,timezone,timedelta
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backup'))
from core import BackupError,atomic_json,digest,due,export_recovery,recover_key,read_manifest,retention,run_backup,unseal,verify_archive
from vault import WindowsVault
from backup import validate_config
from transport import Transport

class FakeTransport:
    excluded_sessions=['auth.sessions','auth.refresh_tokens']
    def __init__(self):self.http_bytes=17;self.files={'synthetic/receipt':b'SYNTHETIC RECEIPT'};self.reported=[];self.downloads=0;self.fail=None
    def authorize(self):
        if self.fail=='auth':raise BackupError('AUTHORIZATION_FAILED')
    def report(self,*a):self.reported.append(a)
    def dump(self,f):
        if self.fail=='dump':raise BackupError('DATABASE_EXPORT_FAILED')
        if self.fail=='interrupt':raise KeyboardInterrupt()
        f.write(b'PGDMP-SYNTHETIC UNIT FIXTURE')
    def metadata(self):return {'synthetic':True}
    def usage(self):return {'database_bytes':100,'storage_bytes':len(next(iter(self.files.values())))}
    def receipts(self):return [{'object_path':k,'sha256':digest(v),'byte_size':len(v)} for k,v in self.files.items()]
    def download(self,k):
        self.downloads+=1
        if self.fail=='receipt':raise BackupError('RECEIPT_COPY_FAILED')
        return self.files[k]
    def verify_dump(self,b):
        if not b.startswith(b'PGDMP') or self.fail=='verify':raise BackupError('ARCHIVE_VERIFY_FAILED')
    def close(self):pass

class HelperTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.base=Path(self.temp.name);self.key=os.urandom(32);self.transport=FakeTransport();self.config={'business_id':str(uuid.uuid4()),'backup_root':str(self.base/'backups'),'status_path':str(self.base/'status.json'),'daily_time':'18:00','retention_days':30}
    def tearDown(self):self.temp.cleanup()
    def test_local_backup_records_runtime_images_without_environment_secrets(self):
        from types import SimpleNamespace
        from unittest.mock import patch
        transport=Transport.__new__(Transport);transport.config={'docker_container':'supabase_db_synthetic'}
        images=['supabase/postgres:17.11.0.004','ghcr.io/supabase/gotrue:v2.197.0','public.ecr.aws/supabase/postgrest:v16.4','ghcr.io/supabase/storage-api:v1.79.36']
        with patch.object(transport,'query',return_value={'roles':[]}),patch('transport.subprocess.run',side_effect=[SimpleNamespace(stdout=x+'\n') for x in images]) as command:
            metadata=transport.metadata();self.assertEqual(list(metadata['local_runtime_images'].values()),images)
            self.assertTrue(all('{{.Config.Image}}' in c.args[0] for c in command.call_args_list))
            self.assertTrue(all('Env' not in str(c) for c in command.call_args_list))
    def configuration(self):
        return {'format_version':1,'business_id':str(uuid.uuid4()),'supabase_url':'http://127.0.0.1:54321','credential_prefix':'CarrierRecordsBackup/test/'+str(uuid.uuid4()),'backup_root':str(self.base/'backups'),'status_path':str(self.base/'local-status.json'),'daily_time':'18:00','time_zone':'Pacific Standard Time','task_name':'CarrierRecordsBackup-'+str(uuid.uuid4()),'config_path':str(self.base/'config.json'),'docker_container':'supabase_db_transport_project','retention_days':30}
    def test_setup_configuration_required_backend_url_is_accepted(self):
        validate_config(self.configuration())
        validate_config(dict(self.configuration(),supabase_url='https://example.supabase.co'))
    def test_configuration_contract_rejects_invalid_and_secret_fields(self):
        cases=[{'supabase_url':'http://remote.example'},{'supabase_url':'https://user:secret@example.com'},{'supabase_url':'https://example.com/private'},{'supabase_url':'https://example.com?token=forbidden'},{'supabase_url':'https://example.com#secret'},{'supabase_url':'https://'},{'supabase_url':'https://example.com:invalid'},{'business_id':'invalid'},{'retention_days':'30'},{'isolated_test':'yes'},{'daily_time':18},{'service_key':'forbidden'},{'unknown':True},{'format_version':2},{'daily_time':'24:00'},{'daily_time':'6:00'},{'retention_days':0},{'retention_days':366},{'task_name':'UnrelatedTask'},{'status_path':str(self.base/'other.json')},{'backup_root':str(Path.home())},{'backup_root':str(Path(self.base.anchor))}]
        for changes in cases:
            with self.subTest(fields=list(changes)):
                c=dict(self.configuration(),**changes)
                with self.assertRaises(BackupError):validate_config(c)
        for field in ['supabase_url','business_id','credential_prefix','config_path','daily_time','task_name','time_zone','backup_root','status_path']:
            with self.subTest(missing=field):
                c=self.configuration();del c[field]
                with self.assertRaises(BackupError):validate_config(c)
    def test_configuration_valid_retention_bounds_and_git_exclusion(self):
        for days in [1,30,365]:validate_config(dict(self.configuration(),retention_days=days))
        (self.base/'.git').mkdir()
        with self.assertRaises(BackupError):validate_config(self.configuration())
        validate_config(dict(self.configuration(),isolated_test=True))
    def test_verified_archive_and_incremental_receipts(self):
        first=run_backup(self.config,self.key,self.transport);self.assertEqual(first['outcome'],'SUCCESS');self.assertEqual(self.transport.downloads,1)
        second=run_backup(self.config,self.key,self.transport);self.assertEqual(second['outcome'],'SUCCESS');self.assertEqual(self.transport.downloads,1);self.assertEqual(second['metrics']['reused_receipts'],1)
        self.transport.files['synthetic/new']=b'NEW SYNTHETIC RECEIPT'
        third=run_backup(self.config,self.key,self.transport);self.assertEqual(third['metrics']['downloaded_receipts'],1);self.assertEqual(self.transport.downloads,2)
        archives=list((self.base/'backups/archives').glob('*.crb'));self.assertEqual(len(archives),1)
        m=verify_archive(archives[0],self.key,self.base/'backups',self.transport);self.assertEqual(len(m['receipts']),2);self.assertFalse(m['restoration_verified'])
        self.assertNotIn(b'PGDMP',archives[0].read_bytes());self.assertNotIn(b'SYNTHETIC',archives[0].read_bytes())
    def test_wrong_key_and_tampered_archive_are_rejected(self):
        run_backup(self.config,self.key,self.transport);p=next((self.base/'backups/archives').glob('*.crb'))
        with self.assertRaises(BackupError):read_manifest(p,os.urandom(32))
        b=bytearray(p.read_bytes());b[-1]^=1;p.write_bytes(b)
        with self.assertRaises(BackupError):read_manifest(p,self.key)
    def test_recovery_key_separate_passphrase_protected_and_not_dpapi_only(self):
        p=self.base/'recovery.json';password='SyntheticRecoveryPassphrase'+str(uuid.uuid4())
        export_recovery(self.key,p,password);self.assertEqual(recover_key(p,password),self.key);self.assertNotIn(self.key,p.read_bytes())
        with self.assertRaises(BackupError):recover_key(p,'Wrong synthetic passphrase')
    def test_failures_preserve_last_verified_success(self):
        first=run_backup(self.config,self.key,self.transport)
        for stage in ['dump','verify','auth']:
            self.transport.fail=stage;r=run_backup(self.config,self.key,self.transport);self.assertEqual(r['outcome'],'FAILED');self.assertEqual(r['last_verified_success_at'],first['last_verified_success_at'])
        self.transport.fail='receipt';self.transport.files['synthetic/new']=b'SYNTHETIC NEW';r=run_backup(self.config,self.key,self.transport);self.assertEqual(r['outcome'],'FAILED');self.assertGreater(r['pending_receipt_count'],0)
    def test_interrupted_run_never_becomes_success(self):
        self.transport.fail='interrupt'
        with self.assertRaises(KeyboardInterrupt):run_backup(self.config,self.key,self.transport)
        s=json.loads((self.base/'status.json').read_text());self.assertEqual(s['outcome'],'FAILED');self.assertEqual(s['safe_error_code'],'INTERRUPTED');self.assertIsNone(s['last_verified_success_at']);self.assertFalse(list((self.base/'backups/archives').glob('*.crb')))
    def test_daily_due_missed_run_and_online_catchup(self):
        now=datetime(2026,10,12,17,0,tzinfo=timezone(timedelta(hours=-7)))
        self.assertTrue(due(None,now,'18:00'));self.assertFalse(due('2026-10-12T01:01:00+00:00',now,'18:00'))
        self.assertTrue(due('2026-10-12T01:01:00+00:00',now+timedelta(days=2),'18:00'))
        first=run_backup(self.config,self.key,self.transport);self.assertEqual(run_backup(self.config,self.key,self.transport,scheduled=True)['outcome'],'NOT_DUE')
    def test_thirty_daily_retention_and_no_source_deletion(self):
        self.config['retention_days']=30
        for day in range(32):
            now=datetime(2026,8,1,tzinfo=timezone.utc)+timedelta(days=day)
            r=run_backup(self.config,self.key,self.transport,clock=lambda:now);self.assertEqual(r['outcome'],'SUCCESS')
        self.assertEqual(len(list((self.base/'backups/archives').glob('*.crb'))),30);self.assertIn('synthetic/receipt',self.transport.files)
    @unittest.skipUnless(os.name=='nt','Windows only')
    def test_real_windows_vault_write_read_delete(self):
        v=WindowsVault();target='CarrierRecordsBackup/test/'+str(uuid.uuid4());secret=os.urandom(32)
        try:v.write(target,secret);self.assertEqual(v.read(target),secret)
        finally:v.delete(target)
        with self.assertRaises(RuntimeError):v.read(target)

if __name__=='__main__':unittest.main()
