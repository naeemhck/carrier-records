"""Scan actual local packages and tracked source for local privileged values.
Values are read only in memory and never printed.
"""
import json,subprocess,zipfile
from pathlib import Path
root=Path(__file__).resolve().parents[2]
r=subprocess.run(['powershell','-NoProfile','-File',str(root/'tools/supabase.ps1'),'status','-o','json'],capture_output=True,text=True,check=True)
cfg=json.loads(r.stdout)
values=[cfg[k] for k in ('SERVICE_ROLE_KEY','SECRET_KEY','JWT_SECRET','S3_PROTOCOL_ACCESS_KEY_SECRET') if cfg.get(k)]
needles=[v.encode(e) for v in values for e in ['utf-8','utf-16-le']]
count=0
def inspect(data):
 global count
 count+=1
 if any(n in data for n in needles):raise AssertionError('Privileged value found; package audit failed. No secret was printed.')
package=root/'app/build/app/outputs/flutter-apk/app-debug.apk'
assert package.is_file()
with zipfile.ZipFile(package) as archive:
 for item in archive.infolist():
  if not item.is_dir():inspect(archive.read(item))
windows=root/'app/build/windows/x64/runner/Debug'
assert (windows/'carrier_records.exe').is_file()
for p in windows.rglob('*'):
 if p.is_file():inspect(p.read_bytes())
tracked=subprocess.run(['git','ls-files','-z'],cwd=root,capture_output=True,check=True).stdout.split(b'\0')
for name in tracked:
 if name:
  p=root/name.decode('utf-8')
  if p.is_file():inspect(p.read_bytes())
print(f'PASS privileged-value audit: {count} APK entries, Windows files and tracked source files scanned. No privileged value found.')
