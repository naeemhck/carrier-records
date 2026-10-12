"""T19 read-only permission probes using an existing staff user's real Auth token.

Run interactively. No privileged key, fixture creation, SQL impersonation or financial
command. A separate short-lived probe session is signed out locally afterward.
"""
import argparse
import base64
import getpass
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request
import uuid
import warnings

ROOT = Path(__file__).resolve().parents[1]
OFFICES = {'pilot_khi': 'Karachi', 'pilot_isb': 'Islamabad'}
PILOT_URL = 'https://tuasxnfwrepbcelnrlgb.supabase.co'


def load_config(path):
    data = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    if set(data) != {'version', 'url', 'publishableKey', 'businessId'} or type(data['version']) is not int or data['version'] != 1 or data['url'] != PILOT_URL:
        raise ValueError('Invalid pilot public configuration.')
    uuid.UUID(data['businessId'])
    key = data['publishableKey']
    public = isinstance(key, str) and key.startswith('sb_publishable_') and len(key) > 20
    if isinstance(key, str) and key.startswith('eyJ'):
        try:
            part = key.split('.')[1]
            public = json.loads(base64.urlsafe_b64decode(part + '=' * (-len(part) % 4))).get('role') == 'anon'
        except (ValueError, IndexError, TypeError):
            public = False
    if not public:
        raise ValueError('A public client key is required.')
    return data


class Probe:
    def __init__(self, config, username):
        self.config, self.username = config, username
        self.token = None
        self.results = []

    def request(self, path, body):
        headers = {'apikey': self.config['publishableKey'], 'Content-Type': 'application/json'}
        if self.token:
            headers['Authorization'] = 'Bearer ' + self.token
        request = urllib.request.Request(self.config['url'] + path, data=json.dumps(body).encode(), headers=headers, method='POST')
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                status, raw = response.status, response.read()
        except urllib.error.HTTPError as error:
            status, raw = error.code, error.read()
        try:
            body = json.loads(raw)
        except (ValueError, UnicodeError):
            body = None
        return status, body

    def rpc(self, name, body=None):
        return self.request('/rest/v1/rpc/' + name, body or {})

    def record(self, name, status, passed):
        self.results.append({'check': name, 'http': status, 'result': 'PASS' if passed else 'FAIL'})
        print(('PASS' if passed else 'FAIL') + ' ' + name + ' (HTTP ' + str(status) + ')', flush=True)
        if not passed:
            raise ValueError('Permission probe failed. Stop and inspect the sanitized result.')

    def denied(self, name, response):
        status, body = response
        self.record(name, status, status == 403 and isinstance(body, dict) and body.get('code') == '42501')

    def verify(self, password, trip_checks=False):
        status, body = self.request('/auth/v1/token?grant_type=password', {
            'email': self.username + '.' + self.config['businessId'] + '@staff.invalid', 'password': password,
        })
        if status != 200 or not isinstance(body, dict) or not isinstance(body.get('access_token'), str):
            self.record('existing staff authentication', status, False)
        self.token = body['access_token']
        self.record('existing staff authentication', status, True)
        status, profile = self.rpc('get_session_profile')
        ready = status == 200 and isinstance(profile, dict) and profile.get('username') == self.username and profile.get('business_id') == self.config['businessId'] and profile.get('role') == 'STAFF' and profile.get('must_change_password') is False and [o.get('name') for o in profile.get('offices', [])] == [OFFICES[self.username]]
        self.record('ready staff with exactly the assigned office', status, ready)
        self.denied('staff account administration denied', self.rpc('list_staff_accounts'))
        self.denied('complete business balance denied', self.rpc('get_balance_summary', {'scope': 'ALL'}))
        status, balance = self.rpc('get_balance_summary', {'scope': 'ASSIGNED'})
        self.record('explicitly scoped balance allowed', status, status == 200 and isinstance(balance, dict) and balance.get('complete') is False and balance.get('scope') == 'ASSIGNED')
        status, page = self.rpc('list_trips', {'search_text': '', 'page_offset': 0, 'trip_state': 'DRAFT'})
        self.record('office-scoped draft list allowed', status, status == 200 and isinstance(page, dict) and page.get('scope') == 'ASSIGNED_OFFICES' and isinstance(page.get('rows'), list) and all(OFFICES[self.username] in (row.get('origin_name'), row.get('destination_name')) for row in page['rows']))
        if not trip_checks:
            self.results.append({'check': 'trip operation matrix', 'result': 'NOT_RUN'})
            print('NOT RUN trip operations; rerun with --trip-checks after creating one Karachi-to-Islamabad pilot draft.')
            return
        candidates = [r for r in page['rows'] if r.get('origin_name') == 'Karachi' and r.get('destination_name') == 'Islamabad' and r.get('state') == 'DRAFT']
        if len(candidates) != 1 or len(page['rows']) >= 50:
            self.results.append({'check': 'unique pilot draft required', 'result': 'NOT_RUN'})
            raise ValueError('Exactly one visible Karachi-to-Islamabad draft is required; no trip operations tested.')
        trip = str(uuid.UUID(candidates[0]['id']))
        origin = self.username == 'pilot_khi'
        for operation, allowed in [('EDIT_FARE', origin), ('DISPATCH', origin), ('ARRIVAL', not origin), ('POST_MONEY', True), ('EXPENSE', True)]:
            response = self.rpc('authorize_trip_operation', {'trip_id': trip, 'operation': operation})
            if allowed:
                self.record(operation + ' permission allowed', response[0], response == (200, True))
            else:
                self.denied(operation + ' cross-office permission denied', response)

    def close(self):
        if self.token:
            try:
                status, _ = self.request('/auth/v1/logout?scope=local', {})
                self.record('probe session logout', status, status == 204)
            finally:
                self.token = None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('username', choices=OFFICES)
    parser.add_argument('--trip-checks', action='store_true')
    args = parser.parse_args()
    probe = None
    result = 1
    try:
        if not sys.stdin.isatty():
            raise ValueError('Run in an interactive terminal with a hidden password prompt.')
        config = load_config(Path(os.environ['LOCALAPPDATA']) / 'CarrierRecords/client.json')
        probe = Probe(config, args.username)
        with warnings.catch_warnings():
            warnings.simplefilter('error', getpass.GetPassWarning)
            credential = getpass.getpass('Current staff password (hidden, never saved): ')
        try:
            probe.verify(credential, args.trip_checks)
            result = 0
        finally:
            credential = None
    except (Exception, KeyboardInterrupt):
        print('Probe incomplete. No credentials or upstream response details are printed. Check account readiness/configuration and sanitized check results.')
    finally:
        if probe:
            try:
                probe.close()
            except Exception:
                result = 1
                print('Probe logout not confirmed; session cleanup remains pending.')
            report = {'username': args.username, 'trip_checks_requested': args.trip_checks, 'exit_code': result, 'checks': probe.results}
            directory = ROOT / 'tools/.local'
            directory.mkdir(exist_ok=True)
            (directory / ('t19-permissions-' + args.username + '.json')).write_text(json.dumps(report, indent=2), encoding='utf-8')
    return result


if __name__ == '__main__':
    sys.exit(main())
