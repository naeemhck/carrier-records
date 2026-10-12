"""Recovery boundary tests; actual restoration is covered by AT-32 separately."""
import sys,unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'backup'))
from core import BackupError,digest
from restore import ArchiveInspector,isolated_port_block,target_guard,restore_database

class RecoveryBoundaryTests(unittest.TestCase):
    def test_reserved_port_block_falls_back_and_closes_every_probe(self):
        from unittest.mock import MagicMock
        probes=[MagicMock() for _ in range(11)]
        probes[0].bind.side_effect=OSError('Windows reserved range')
        with patch('restore.socket.socket',side_effect=probes):
            self.assertEqual(isolated_port_block(),58320)
        self.assertTrue(all(p.close.call_count==1 for p in probes))
    def test_no_available_ports_and_development_ports_fail_closed(self):
        from unittest.mock import MagicMock
        probe=MagicMock();probe.bind.side_effect=OSError('reserved')
        with patch('restore.socket.socket',return_value=probe):
            with self.assertRaises(BackupError) as error:isolated_port_block()
            self.assertEqual(error.exception.code,'RESTORE_PORTS_UNAVAILABLE')
        with self.assertRaises(BackupError):isolated_port_block((54320,))
    def test_archive_inspection_has_no_vault_or_source_network_dependency(self):
        from types import SimpleNamespace
        toc=b'TABLE DATA auth users\nTABLE DATA auth identities'
        with patch('restore.subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=toc)) as command:
            ArchiveInspector().verify_dump(b'PGDMP')
            args=command.call_args.args[0]
            self.assertIn('--rm',args);self.assertEqual(args[args.index('--network')+1],'none')
            self.assertNotIn('supabase_db_transport_project',args)
        with self.assertRaises(BackupError):ArchiveInspector('untrusted/utility:latest')
    def test_source_hosted_and_arbitrary_targets_rejected(self):
        target_guard('supabase_db_carrier_restore_0123456789ab')
        for target in ['supabase_db_transport_project','postgres','supabase_db_carrier_restore_bad','supabase_db_carrier_restore_0123456789ab;drop']:
            with self.subTest(target=target),self.assertRaises(BackupError):target_guard(target)
    def test_nonempty_target_stops_before_any_restore_command(self):
        with patch('restore.query',return_value='false'),patch('restore.subprocess.run') as command:
            with self.assertRaises(BackupError) as error:restore_database('supabase_db_carrier_restore_0123456789ab',b'PGDMP',{'roles':[]})
            self.assertEqual(error.exception.code,'RESTORE_TARGET_NOT_EMPTY');command.assert_not_called()
    def test_unsafe_command_owner_role_refused(self):
        for role in [{'name':'carrier_finance','login':True,'bypass_rls':False,'inherit':False},{'name':'carrier_finance','login':False,'bypass_rls':True,'inherit':False},{'name':'carrier_bad;sql','login':False,'bypass_rls':False,'inherit':False}]:
            with self.subTest(role=role),patch('restore.query',return_value='true'),patch('restore.subprocess.run') as command:
                with self.assertRaises(BackupError):restore_database('supabase_db_carrier_restore_0123456789ab',b'PGDMP',{'roles':[role]})
                command.assert_not_called()
    def test_full_dump_uses_pristine_database_and_keeps_default_public_schema(self):
        from types import SimpleNamespace
        with patch('restore.query',return_value='true') as sql,patch('restore.subprocess.run',return_value=SimpleNamespace(returncode=0,stdout=digest(b'PGDMP').encode()+b' file')) as command:
            restore_database('supabase_db_carrier_restore_0123456789ab',b'PGDMP',{'roles':[],'memberships':[]})
            calls=command.call_args_list
            self.assertEqual(len(calls),6)
            self.assertIn(b'template template0',calls[1].kwargs['input'])
            self.assertIn('umask 077',calls[2].args[0][-1])
            self.assertIn('sha256sum',calls[3].args[0])
            self.assertIn('--single-transaction',calls[4].args[0])
            self.assertNotIn('--clean',calls[4].args[0])
            self.assertEqual(calls[4].args[0][-1],'/tmp/carrier-restore.dump')
            self.assertIn('rm',calls[5].args[0])
            self.assertTrue(all('drop schema public' not in str(c) for c in sql.call_args_list))
    def test_failed_restore_never_emits_utility_credentials_or_sql(self):
        from types import SimpleNamespace
        responses=[SimpleNamespace(returncode=0),SimpleNamespace(returncode=0),SimpleNamespace(returncode=0),SimpleNamespace(returncode=0,stdout=digest(b'PGDMP').encode()+b' file'),SimpleNamespace(returncode=1,stderr=b'ERROR: synthetic-sensitive-value; command: private SQL'),SimpleNamespace(returncode=0)]
        with patch('restore.query',return_value='true'),patch('restore.subprocess.run',side_effect=responses):
            with self.assertRaises(BackupError) as error:restore_database('supabase_db_carrier_restore_0123456789ab',b'PGDMP',{'roles':[],'memberships':[]})
            self.assertEqual(error.exception.code,'RESTORE_DATABASE_FAILED_UNKNOWN')

if __name__=='__main__':unittest.main()
