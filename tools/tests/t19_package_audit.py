"""Audit actual staged and installed Windows release bytes; never emit secrets."""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('manifest', type=Path)
parser.add_argument('--installed', type=Path)
args = parser.parse_args()
manifest = json.loads(args.manifest.read_text(encoding='utf-8-sig'))
assert manifest['environment'] == 'production'
cfg = json.loads(subprocess.run(
    ['powershell', '-NoProfile', '-File', str(ROOT / 'tools/supabase.ps1'),
     'status', '-o', 'json'], capture_output=True, text=True, check=True).stdout)
values = [value for key, value in cfg.items() if isinstance(value, str) and value
          and any(part in key for part in ('KEY', 'SECRET'))]
# A real local public key is also forbidden: release must have no test config.
needles = [value.encode(encoding) for value in values
           for encoding in ('utf-8', 'utf-16le')]
patterns = [rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
            rb'sb_secret_[A-Za-z0-9_-]{20,}',
            rb'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}',
            rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})',
            rb'^PGDMP|^-- PostgreSQL database dump']
count = 0
expected = {entry['path'].replace('\\', '/') for entry in manifest['files']}
staged = args.manifest.parent / 'payload'
assert {str(path.relative_to(staged)).replace('\\', '/') for path in staged.rglob('*') if path.is_file()} == expected
if args.installed:
    extra = {str(path.relative_to(args.installed)).replace('\\', '/') for path in args.installed.rglob('*') if path.is_file()} - expected
    assert extra <= {'unins000.exe', 'unins000.dat', 'unins000.msg'}, 'Unexpected installed files'
for entry in manifest['files']:
    name = entry['path']
    assert not re.search(r'(?i)(\.pdb$|\.env|\.dump$|\.key$|\.pem$|\.pfx$|\.jks$|\.crb$|\.recovery\.|receipts|backups|test_config)', name)
    for base in [args.manifest.parent / 'payload'] + ([args.installed] if args.installed else []):
        data = (base / name).read_bytes()
        assert len(data) == entry['bytes']
        assert hashlib.sha256(data).hexdigest() == entry['sha256'], 'Payload hash mismatch'
        assert not any(needle in data for needle in needles), 'Credential/test configuration detected'
        assert not any(re.search(pattern, data, re.MULTILINE) for pattern in patterns), 'Sensitive material detected'
        count += 1
installer = Path(manifest['installer'])
assert hashlib.sha256(installer.read_bytes()).hexdigest() == manifest['installerSha256']
print(f'PASS release audit: {count} staged/installed files; exact manifest hashes; no actual local keys or privileged/signing material.')
