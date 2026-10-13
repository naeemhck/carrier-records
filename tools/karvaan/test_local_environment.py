import io,json,unittest
from unittest.mock import patch
import local_environment as local

class LocalBoundaryTests(unittest.TestCase):
    def valid(self):
        return {'APP_ENV':'test','SUPABASE_URL':local.API,'SUPABASE_PUBLISHABLE_KEY':'synthetic-anon','APP_BUSINESS_ID':'synthetic-business'}

    def test_endpoint_rejection_precedes_any_connection(self):
        for url in ['https://example.supabase.co','http://127.0.0.1:54321','http://localhost:60321',local.API+'/rest/v1',local.API+'?project=test']:
            with self.subTest(url=url),patch.object(local,'status') as status:
                with self.assertRaises(RuntimeError):local.validate_defines({**self.valid(),'SUPABASE_URL':url})
                status.assert_not_called()
        for value in [{**self.valid(),'APP_ENV':'production'},{**self.valid(),'password':'not-allowed'},{}]:
            with patch.object(local,'status') as status:
                with self.assertRaises(RuntimeError):local.validate_defines(value)
                status.assert_not_called()

    def test_complete_verified_configuration(self):
        with patch.object(local,'status',return_value={'ANON_KEY':'synthetic-anon'}),patch.object(local,'sql',return_value='synthetic-business'),patch.object(local.urllib.request,'urlopen',return_value=io.StringIO(json.dumps(local.IDENTITY))):
            local.validate_defines(self.valid())

    def test_wrong_key_identity_and_business_rejected(self):
        for key,identity,business in [('other',local.IDENTITY,'synthetic-business'),('synthetic-anon',{**local.IDENTITY,'project_id':'transport_project'},'synthetic-business'),('synthetic-anon',local.IDENTITY,'other-business')]:
            with self.subTest(key=key,identity=identity,business=business),patch.object(local,'status',return_value={'ANON_KEY':key}),patch.object(local,'sql',return_value=business),patch.object(local.urllib.request,'urlopen',return_value=io.StringIO(json.dumps(identity))):
                with self.assertRaises(RuntimeError):local.validate_defines(self.valid())

if __name__=='__main__':unittest.main()
