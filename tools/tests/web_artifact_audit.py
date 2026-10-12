"""Audit a release web directory without printing public keys or file contents."""
import argparse
import base64
import hashlib
import json
import re
from pathlib import Path


def audit(root):
    files = sorted(p for p in root.rglob('*') if p.is_file())
    findings = []
    for path in files:
        name = path.relative_to(root).as_posix()
        data = path.read_bytes()
        if len(data) > 25 * 1024 * 1024:
            findings.append((name, 'Pages file size limit'))
        if (path.name.startswith('.env') or path.suffix.lower() in
                {'.sql', '.gz', '.dump', '.key', '.pem', '.pfx', '.jks', '.exe'} or
                any(part in {'receipts', 'backups', 'storage-backup', '.local'}
                    for part in path.parts)):
            findings.append((name, 'private/artifact filename'))
        patterns = {
            'privileged project key': rb'sb_secret_[A-Za-z0-9_-]{20,}',
            'private signing material': rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
            'GitHub credential': rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})',
            'database connection credential': rb'postgres(?:ql)?://[^\s\x00]+',
            'database dump': rb'^-- PostgreSQL database dump|^PGDMP',
        }
        for label, pattern in patterns.items():
            if re.search(pattern, data, re.MULTILINE):
                findings.append((name, label))
        for match in re.finditer(rb'eyJ[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+', data):
            try:
                token = match[1]
                role = json.loads(base64.urlsafe_b64decode(token + b'=' * (-len(token) % 4))).get('role')
            except Exception:
                role = None
            if role != 'anon':
                findings.append((name, 'non-public JWT'))
    if len(files) > 20000:
        findings.append(('.', 'Pages file count limit'))
    if (root / '_redirects').read_bytes() != b'/* /index.html 200\n':
        findings.append(('_redirects', 'unexpected SPA rule'))
    for required in ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js']:
        if not (root / required).is_file():
            findings.append((required, 'missing release asset'))
    return {'files': len(files), 'bytes': sum(p.stat().st_size for p in files),
            'main_js_sha256': hashlib.sha256((root / 'main.dart.js').read_bytes()).hexdigest(),
            'findings': findings, 'passed': not findings}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    report = audit(parser.parse_args().directory)
    print(json.dumps(report))
    raise SystemExit(0 if report['passed'] else 1)
