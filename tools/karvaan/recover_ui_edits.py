"""Recover this tool's uncommitted edits only; never touch main or other files."""
import json
import subprocess
from generate_catalogue import ROOT

branch = subprocess.run(['git', 'branch', '--show-current'], cwd=ROOT,
                        capture_output=True, text=True, check=True).stdout.strip()
if branch != 'update/karvaan-bilingual':
    raise RuntimeError('Wrong isolated branch.')
ledger = ROOT / 'tools/karvaan/ui-coverage.json'
files = sorted({entry['file'] for entry in json.loads(ledger.read_text(encoding='utf-8'))})
if any(not (file == 'app/lib/app/carrier_records_app.dart' or
            file.startswith('app/lib/features/')) or not file.endswith('.dart') for file in files):
    raise RuntimeError('Unexpected recovery target.')
subprocess.run(['git', 'restore', '--source=HEAD', '--', *files], cwd=ROOT, check=True)
ledger.write_text('[]\n', encoding='utf-8')
print(f'Restored {len(files)} generated screen edits only; guards/fonts/catalogue unchanged.')
