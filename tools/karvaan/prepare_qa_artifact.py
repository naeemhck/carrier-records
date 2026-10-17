"""Audit an explicit public TEST web artifact; preserve existing candidates."""
import argparse,hashlib,json,re,subprocess,sys
from qa_preview import FOLDER,ROOT,REF,require
from qa_seed import unprotect
sys.path.insert(0,str(ROOT/'tools/tests'))
from web_artifact_audit import audit
parser=argparse.ArgumentParser();parser.add_argument('--version',required=True);parser.add_argument('--source-commit',required=True);args=parser.parse_args()
require(re.fullmatch(r'0\.2\.0\+[0-9]+',args.version) is not None and re.fullmatch(r'[a-f0-9]{40}',args.source_commit) is not None,'Explicit version and full source commit required')
web=FOLDER/'artifacts'/args.version/'web'
require(not (web.parent/'manifest.json').exists(),'Preserve an already audited artifact')
require(not subprocess.check_output(['git','diff',args.source_commit,'--','app'],cwd=ROOT),'App differs from named source')
require(web.is_dir() and (web/'main.dart.js').is_file(),'Completed preview build absent')
config=json.loads((FOLDER/'web-public-defines.json').read_text());require(set(config)=={'APP_ENV','SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','APP_BUSINESS_ID','KARVAAN_QA_PREVIEW','KARVAAN_LOCAL_ONLY','use_arabic'} and config['SUPABASE_URL']=='https://'+REF+'.supabase.co' and config['APP_ENV']=='test' and config['KARVAAN_QA_PREVIEW'] is True and config['KARVAAN_LOCAL_ONLY'] is True and config['use_arabic'] is True and config['APP_BUSINESS_ID']=='9807abdd-e187-4774-8d08-7220a9062524','Only exact QA public defines allowed')
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
 for match in re.findall(rb'https://[a-z0-9]{20}\.supabase\.co',data):origins.add(match.decode())
 if any(v.encode() in data or v.encode('utf-16le') in data for v in passwords):report['findings'].append((p.relative_to(web).as_posix(),'test password'))
require(origins=={config['SUPABASE_URL']},'Web contains unexpected hosted backend target')
report['passed']=not report['findings'];report['backend_origins']=sorted(origins)
(web.parent/'artifact-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8');require(report['passed'],'Artifact audit failed')
version=json.loads((web/'version.json').read_text());require(version['version']+'+'+version['build_number']==args.version,'Wrong preview version')
manifest={'version':args.version,'source_commit':args.source_commit,'test_project_ref':REF,'main_js_sha256':report['main_js_sha256'],'configuration_sha256':hashlib.sha256((FOLDER/'web-public-defines.json').read_bytes()).hexdigest(),'files':[{'path':p.relative_to(web).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(web.rglob('*')) if p.is_file()]}
(web.parent/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
for root,name in [(ROOT/'tools/.local/candidates/0.2.0+12','manifest.json'),(ROOT/'tools/.local/candidates/0.2.0+12/review-pack','review-manifest.json'),(ROOT/'tools/.local/candidates/0.2.0+17','manifest.json'),(ROOT/'tools/.local/candidates/0.2.0+17/review-pack','review-manifest.json'),(FOLDER/'artifacts/0.2.0+13/web','../manifest.json')]:
 m=json.loads((root/name).read_text());require(all(hashlib.sha256((root/f['path']).read_bytes()).hexdigest()==f['sha256'] for f in m['files']),'Preserved candidate12 hash mismatch')
print(json.dumps({'audit':report,'version':args.version,'source_commit':manifest['source_commit'],'candidate12_preserved':True}))
