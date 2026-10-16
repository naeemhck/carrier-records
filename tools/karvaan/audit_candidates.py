"""Audit actual public-client candidate bytes, including compressed APK entries."""
import base64,hashlib,json,re,sys,zipfile
from pathlib import Path
from local_environment import ROOT,boundary,status,require
from material_scan import has_private_key_material,PRIVATE_KEY_HEADER
boundary();cfg=status()
version=(ROOT/'app/pubspec.yaml').read_text(encoding='utf-8').split('version: ',1)[1].splitlines()[0].strip()
if len(sys.argv)>1:version=sys.argv[1]
require(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+',version) is not None,'Invalid candidate version.')
root=ROOT/'tools/.local/candidates'/version
require(root.exists(),'Candidates absent.')
secrets=[v for k,v in cfg.items() if isinstance(v,str) and len(v)>16 and any(x in k for x in ['SECRET','SERVICE_ROLE','DB_URL'])]
# Exact-match every locally generated review/performance password in memory.
# These ignored files are never copied into a candidate or printed.
for auth in list((ROOT/'tools/.local').glob('karvaan-*-auth.json'))+list((ROOT/'tools/.local').glob('karvaan-report-regression-*.json')):
 values=json.loads(auth.read_text(encoding='utf-8'))
 if 'usernames' in values:secrets+=list(values['usernames'].values())
 elif auth.name=='karvaan-performance-auth.json':secrets+=list(values.values())
 else:secrets += [v for k,v in values.items() if 'password' in k and isinstance(v,str)]
findings=[];count=0;header_literals=[]
def scan(name,data):
 global count
 count+=1
 if has_private_key_material(data):findings.append({'file':name,'reason':'private key material'})
 elif PRIVATE_KEY_HEADER.search(data):header_literals.append(name)
 for value in secrets:
  if value.encode() in data or value.encode('utf-16le') in data:findings.append({'file':name,'reason':'privileged credential or test password'})
 patterns={
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
if '--review-pack' in sys.argv:
 pack=root/'review-pack';require(pack.is_dir(),'Review pack absent.')
 for p in pack.rglob('*'):
  if not p.is_file():continue
  require(p.suffix.lower() in {'.json','.md','.png','.pdf','.xlsx'},'Unexpected review file type.')
  name='review-pack/'+p.relative_to(pack).as_posix();data=p.read_bytes();scan(name,data)
  if p.suffix=='.xlsx':
   with zipfile.ZipFile(p) as z:
    for n in z.namelist():scan(name+'!'+n,z.read(n))
 review_manifest=json.loads((pack/'review-manifest.json').read_text(encoding='utf-8'))
 for item in review_manifest['files']:
  p=pack/item['path'];require(p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],'Review manifest mismatch.')
manifest_path=root/'artifact-manifest.json'
if not manifest_path.exists():manifest_path=root/'manifest.json'
manifest=json.loads(manifest_path.read_text())
for item in manifest['files']:
 p=root/item['path'];require(p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],'Manifest mismatch: '+item['path'])
report={'source_commit':manifest['source_commit'],'version':manifest['version'],'manifest':manifest_path.name,'scanned_entries':count,'findings':findings,'header_literals_without_key_material':header_literals,'passed':not findings,'installer':'compiled but not installed; Windows payload audited before compression','android':'test-signed local candidate; build mode in manifest; not T20 release'}
(root/('review-audit.json' if '--review-pack' in sys.argv else 'audit.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report));require(not findings,'Candidate audit failed.')
