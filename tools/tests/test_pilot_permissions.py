import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pilot_permissions import OFFICES, PILOT_URL, Probe, load_config


class PermissionProbeTests(unittest.TestCase):
    def test_public_configuration_and_secret_rejection(self):
        config = {'version': 1, 'url': PILOT_URL, 'publishableKey': 'sb_publishable_' + 'x'*24, 'businessId': str(uuid.uuid4())}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            path.write_text(json.dumps(config), encoding='utf-8-sig')
            self.assertEqual(load_config(path), config)
            invalid = [dict(config, publishableKey='sb_secret_'+'x'*24), dict(config, password='private'), dict(config, url='http://127.0.0.1:54321'), dict(config, version=True), dict(config, businessId='invalid')]
            for value in invalid:
                path.write_text(json.dumps(value))
                with self.assertRaises(ValueError):
                    load_config(path)

    def fake(self, username, wrong_denial=False, no_trip=False, wrong_office=False):
        config = {'businessId': str(uuid.uuid4())}
        probe = Probe(config, username)
        calls = []
        trip = {'id': str(uuid.uuid4()), 'origin_name': 'Karachi', 'destination_name': 'Islamabad', 'state': 'DRAFT'}
        def request(path, body):
            calls.append((path, body))
            if path.startswith('/auth/v1/token'):
                return 200, {'access_token': 'private_token'}
            if path.startswith('/auth/v1/logout'):
                return 204, None
            if path.endswith('get_session_profile'):
                return 200, {'username': username, 'business_id': config['businessId'], 'role': 'STAFF', 'must_change_password': False, 'offices': [{'name': 'wrong' if wrong_office else OFFICES[username]}]}
            if path.endswith('list_staff_accounts') or path.endswith('get_balance_summary') and body['scope'] == 'ALL':
                return 403, {'code': '22023' if wrong_denial else '42501', 'private': 'secret'}
            if path.endswith('get_balance_summary'):
                return 200, {'complete': False, 'scope': 'ASSIGNED', 'totals': {'private': '100.00'}}
            if path.endswith('list_trips'):
                return 200, {'scope': 'ASSIGNED_OFFICES', 'rows': [] if no_trip else [trip]}
            if path.endswith('authorize_trip_operation'):
                allowed = body['operation'] in ('POST_MONEY','EXPENSE') or (body['operation'] in ('EDIT_FARE','DISPATCH')) == (username=='pilot_khi')
                return (200, True) if allowed else (403, {'code':'42501'})
            raise AssertionError('Unexpected endpoint')
        probe.request = request
        return probe, calls

    def test_both_role_matrices_and_local_session_cleanup(self):
        for username in OFFICES:
            probe, calls = self.fake(username)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                probe.verify('private_password', True)
                probe.close()
            self.assertIsNone(probe.token)
            self.assertTrue(all(row['result']=='PASS' for row in probe.results))
            self.assertTrue(calls[-1][0].endswith('logout?scope=local'))
            for private in ('private_password','private_token','100.00','secret'):
                self.assertNotIn(private, output.getvalue())
                self.assertNotIn(private, json.dumps(probe.results))
            self.assertTrue(all('/auth/v1/' in path or path.rsplit('/',1)[-1] in ('get_session_profile','list_staff_accounts','get_balance_summary','list_trips','authorize_trip_operation') for path, _ in calls))

    def test_malformed_request_denial_is_not_authorization_evidence(self):
        probe, _ = self.fake('pilot_khi', wrong_denial=True)
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
            probe.verify('private_password')
        self.assertEqual(probe.results[-1]['result'], 'FAIL')

    def test_missing_trip_is_not_a_trip_permission_pass(self):
        probe, _ = self.fake('pilot_isb', no_trip=True)
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
            probe.verify('private_password', True)
        self.assertEqual(probe.results[-1]['result'], 'NOT_RUN')

    def test_wrong_office_stops_before_other_operations(self):
        probe, calls = self.fake('pilot_isb', wrong_office=True)
        with contextlib.redirect_stdout(io.StringIO()), self.assertRaises(ValueError):
            probe.verify('private_password')
        self.assertEqual(len(calls), 2)

    def test_preflight_does_not_claim_trip_operations(self):
        probe, calls = self.fake('pilot_khi')
        with contextlib.redirect_stdout(io.StringIO()):
            probe.verify('private_password')
        self.assertEqual(probe.results[-1]['result'], 'NOT_RUN')
        self.assertFalse(any(path.endswith('authorize_trip_operation') for path, _ in calls))


if __name__ == '__main__':
    unittest.main()
