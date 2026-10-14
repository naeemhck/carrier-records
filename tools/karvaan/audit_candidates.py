"""Audit actual public-client candidate bytes, including compressed APK entries."""
import base64,hashlib,json,re,sys,zipfile
from pathlib import Path
from local_environment import ROOT,boundary,status,require
boundary();cfg=status()
root=ROOT/'tools/.local/candidates/0.2.0+8'
require(root.exists(),'Candidates absent.')
secrets=[v for k,v in cfg.items() if isinstance(v,str) and len(v)>16 and any(x in k for x in ['SECRET','SERVICE_ROLE','DB_URL'])]
auth=ROOT/'tools/.local/karvaan-review-auth.json'
if auth.exists():secrets+=list(json.loads(auth.read_text())['usernames'].values())
findings=[];count=0
def scan(name,data):
 global count
 count+=1
 for value in secrets:
  if value.encode() in data or value.encode('utf-16le') in data:findings.append({'file':name,'reason':'privileged credential or test password'})
 patterns={
  'private key':rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
  'secret API key':rb'sb_secret_[A-Za-z0-9_-]{20,}',
  'database credential':rb'postgres(?:ql)?://[^\s\x00]+',
  'GitHub credential':rb'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,})',
  'hosted Supabase configuration':rb'https://[a-z0-9]{20}\.supabase\.co',
  'private fixture marker':rb'FORBIDDEN_(?:OWNER|CUSTOMER|BROKER|RECEIPT|INTERNAL)',
 }
 for label,pattern in patterns.items():
  if re.search(pattern,data):findings.append({'file':name,'reason':label})
 for token in re.findall(rb'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',data):
  try:
   value=json.loads(base64.urlsafe_b64decode(token.split(b'.')[1]+b'==='))
   if value.get('role')=='service_role':findings.append({'file':name,'reason':'service role JWT'})
  except (ValueError,UnicodeError):pass
def files():
 for sub in ['windows/payload','web','android']:
  for p in (root/sub).rglob('*'):
   if not p.is_file():continue
   name=p.relative_to(root).as_posix()
   if p.suffix.lower() in {'.sql','.gz','.dump','.pem','.key','.pfx','.jks','.crb'} or p.name.startswith('.env') or any(x in p.parts for x in ['receipts','backups','storage-backup']):findings.append({'file':name,'reason':'private file'})
   data=p.read_bytes();scan(name,data)
   if p.suffix=='.apk':
    with zipfile.ZipFile(p) as z:
     for n in z.namelist():scan(name+'!'+n,z.read(n))
files()
manifest=json.loads((root/'manifest.json').read_text())
for item in manifest['files']:
 p=root/item['path'];require(p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],'Manifest mismatch: '+item['path'])
report={'source_commit':manifest['source_commit'],'version':manifest['version'],'scanned_entries':count,'findings':findings,'passed':not findings,'installer':'compiled but not installed; Windows payload audited before compression','android':'debug-signed test candidate, not T20 release'}
(root/'audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report));require(not findings,'Candidate audit failed.')
