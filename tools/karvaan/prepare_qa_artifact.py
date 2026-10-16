"""Audit only the distinct public TEST web artifact; preserve candidate12 bytes."""
import hashlib,json,re,subprocess,sys
from qa_preview import FOLDER,ROOT,REF,require
from qa_seed import unprotect
sys.path.insert(0,str(ROOT/'tools/tests'))
from web_artifact_audit import audit
web=FOLDER/'artifacts/0.2.0+13/web'
require(web.is_dir() and (web/'main.dart.js').is_file(),'Completed preview build absent')
config=json.loads((FOLDER/'web-public-defines.json').read_text());require(config['SUPABASE_URL']=='https://'+REF+'.supabase.co' and config['APP_ENV']=='test' and config['KARVAAN_QA_PREVIEW'] is True,'Only QA public defines allowed')
require(config['SUPABASE_PUBLISHABLE_KEY'].startswith('sb_publishable_'),'Publishable key required')
# Testing-specific static metadata, never applied to other artifact directories.
index=web/'index.html';text=index.read_text(encoding='utf-8');text=text.replace('<title>Karvaan</title>','<title>Karvaan — Testing</title>').replace('Internal transport records, reports and bills.','Testing — synthetic data only.');index.write_text(text,encoding='utf-8')
(web/'_redirects').write_bytes(b'/* /index.html 200\n')
(web/'_headers').write_text('/*\n  X-Robots-Tag: noindex, nofollow\n  Referrer-Policy: no-referrer\n  X-Content-Type-Options: nosniff\n',encoding='utf-8')
report=audit(web)
passwords=[v for c in unprotect(FOLDER/'tester-credentials.dpapi').values() for v in c.values()]
origins=set()
for p in web.rglob('*'):
 if not p.is_file():continue
 data=p.read_bytes()
 for match in re.findall(rb'https://[a-z]{20}\.supabase\.co',data):origins.add(match.decode())
 if any(v.encode() in data or v.encode('utf-16le') in data for v in passwords):report['findings'].append((p.relative_to(web).as_posix(),'test password'))
require(origins=={config['SUPABASE_URL']},'Web contains unexpected hosted backend target')
report['passed']=not report['findings'];report['backend_origins']=sorted(origins)
(FOLDER/'artifact-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8');require(report['passed'],'Artifact audit failed')
version=json.loads((web/'version.json').read_text());require(version['version']=='0.2.0' and version['build_number']=='13','Wrong preview version')
manifest={'version':'0.2.0+13','source_commit':'11e8de115841fcfac15dc4f8f15b9c073587871e','test_project_ref':REF,'main_js_sha256':report['main_js_sha256'],'configuration_sha256':hashlib.sha256((FOLDER/'web-public-defines.json').read_bytes()).hexdigest(),'files':[{'path':p.relative_to(web).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(web.rglob('*')) if p.is_file()]}
(web.parent/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
for root,name in [(ROOT/'tools/.local/candidates/0.2.0+12','manifest.json'),(ROOT/'tools/.local/candidates/0.2.0+12/review-pack','review-manifest.json')]:
 m=json.loads((root/name).read_text());require(all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in m['files']),'Preserved candidate12 hash mismatch')
print(json.dumps({'audit':report,'version':'0.2.0+13','source_commit':manifest['source_commit'],'candidate12_preserved':True}))
