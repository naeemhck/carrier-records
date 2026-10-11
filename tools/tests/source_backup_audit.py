"""Read-only source/history audit. Never emits credential values or file contents."""
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def git(*args, data=None):
    return subprocess.run(['git', '-C', str(ROOT), *args], input=data,
                          capture_output=True, check=True).stdout


tracked = git('ls-files', '-z').decode().split('\0')[:-1]
untracked = git('ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')[:-1]
ignored = git('ls-files', '--others', '--ignored', '--exclude-standard', '-z').decode().split('\0')[:-1]
status = subprocess.run(['powershell', '-NoProfile', '-File', str(ROOT / 'tools/supabase.ps1'),
                         'status', '-o', 'json'], capture_output=True, text=True, check=True)
cfg = json.loads(status.stdout)
assert cfg['API_URL'] == 'http://127.0.0.1:54321', 'Audit uses the isolated local environment only.'
values = [v for k, v in cfg.items() if isinstance(v, str) and v and
          any(p in k for p in ['SERVICE_ROLE', 'SECRET', 'ANON_KEY'])]
patterns = {
    'private key': rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'GitHub token': rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})',
    'Supabase privileged key': rb'sb_secret_[A-Za-z0-9_-]{20,}',
    'JWT credential': rb'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
    'AWS credential': rb'AKIA[A-Z0-9]{16}',
    'database dump': rb'^-- PostgreSQL database dump|^PGDMP',
}
findings = []


def audit(label, data):
    for name, pattern in patterns.items():
        if re.search(pattern, data, re.MULTILINE):
            findings.append({'source': label, 'type': name})
    for value in values:
        if any(value.encode(encoding) in data for encoding in ['utf-8', 'utf-16le']):
            findings.append({'source': label, 'type': 'actual local credential'})


def sensitive_name(name):
    p = Path(name)
    return (p.name.startswith('.env') and p.name != '.env.example' or
            p.suffix.lower() in {'.jks', '.keystore', '.pem', '.key', '.p12', '.pfx',
                                 '.dump', '.sqlite', '.sqlite3', '.db', '.bak'} or
            p.name.lower() == 'key.properties' or
            any(x.lower() in {'receipts', 'backups', 'exports'} for x in p.parts) or
            name.lower().endswith('.sql.gz'))


for name in tracked + untracked:
    if sensitive_name(name):
        findings.append({'source': name, 'type': 'sensitive filename'})
    path = ROOT / name
    if path.is_file():
        audit(name, path.read_bytes())

# Check every reachable historical blob, including local branches and tags.
objects = git('rev-list', '--objects', '--all').decode().splitlines()
names = dict((line.split(' ', 1) + [''])[:2] for line in objects)
batch = git('cat-file', '--batch', data=('\n'.join(names) + '\n').encode())
cursor = 0
blobs = 0
while cursor < len(batch):
    end = batch.index(b'\n', cursor)
    oid, kind, size = batch[cursor:end].decode().split()
    size = int(size)
    data = batch[end + 1:end + 1 + size]
    cursor = end + 1 + size + 1
    if kind == 'blob':
        blobs += 1
        label = 'history:' + (names[oid] or oid)
        if sensitive_name(names[oid]):
            findings.append({'source': label, 'type': 'sensitive historical filename'})
        audit(label, data)

report = {'tracked_files': len(tracked), 'untracked_intended_files': len(untracked),
          'historical_blobs': blobs, 'ignored_local_files': len(ignored),
          'findings': findings, 'passed': not findings}
(ROOT / 'tools/.local/t10-source-audit.json').write_text(json.dumps(report), encoding='utf-8')
print(json.dumps(report))
raise SystemExit(0 if not findings else 1)
