"""Guarded, public-only local candidates. Never install or deploy."""
import hashlib,json,shutil,subprocess,time,zipfile
from pathlib import Path
from local_environment import ROOT,boundary,validate_defines,require
from verify_compiler import verify_compiler

boundary()
defines=ROOT/'tools/.local/karvaan-test-defines.json'
config=json.loads(defines.read_text(encoding='utf-8'))
validate_defines(config)
version=(ROOT/'app/pubspec.yaml').read_text().split('version: ',1)[1].splitlines()[0].strip()
require(version=='0.2.0+11','This unused candidate version must be explicit.')
out=ROOT/'tools/.local/candidates'/version
require(not out.exists(),'Preserve existing candidate artifacts; use a new version.')
commit=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
require(not subprocess.run(['git','status','--porcelain'],cwd=ROOT,capture_output=True,text=True,check=True).stdout,'Commit intended source before building.')
out.mkdir(parents=True)
manifest={'public_configuration_sha256':hashlib.sha256(defines.read_bytes()).hexdigest(),'version':version,'source_commit':commit,'environment':'isolated local synthetic only','builds':{},'files':[]}
def record():
 manifest['files']=[{'path':p.relative_to(out).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json' and p.relative_to(out).parts[0]!='review-pack']
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
def build(platform,source,target):
 if source.exists():shutil.copytree(source,ROOT/'tools/.local/preserved-artifacts'/version/platform)
 start=time.perf_counter()
 args=['powershell','-NoProfile','-File',str(ROOT/'tools/flutter.ps1'),'build',platform,'--no-pub','--release' if platform!='apk' else '--debug','--dart-define-from-file='+str(defines),'--dart-define=KARVAAN_LOCAL_ONLY=true','--dart-define=use_arabic=true']
 if platform=='web':args.append('--no-web-resources-cdn')
 if platform=='apk':
  mobile=config|{'SUPABASE_URL':'http://10.0.2.2:60321'}
  mobile_path=ROOT/'tools/.local/karvaan-android-defines.json';mobile_path.write_text(json.dumps(mobile),encoding='utf-8')
  args[args.index('--dart-define-from-file='+str(defines))]='--dart-define-from-file='+str(mobile_path)
 with (out/(platform+'-build.log')).open('w',encoding='utf-8') as log:result=subprocess.run(args,cwd=ROOT/'app',stdout=log,stderr=subprocess.STDOUT)
 manifest['builds'][platform]={'exit_code':result.returncode,'seconds':round(time.perf_counter()-start,3)};record()
 require(result.returncode==0,platform+' build failed; see candidate log.')

 if platform=='apk':
  target.mkdir(parents=True);shutil.copy2(source/'app-debug.apk',target/('Karvaan-'+version+'-android-debug.apk'))
 else:shutil.copytree(source,target)
 record();print('PASS '+platform+' candidate build '+str(manifest['builds'][platform]['seconds'])+'s',flush=True)
build('windows',ROOT/'app/build/windows/x64/runner/Release',out/'windows/payload')
payload=out/'windows/payload'
(payload/'LOCAL-CANDIDATE.txt').write_text('Karvaan '+version+' â€” ISOLATED LOCAL SYNTHETIC REVIEW ONLY.\nDo not install over Carrier Records or deploy. Run the copied payload directly for local review.\nOnly verified karvaan_bilingual_u20261013 backend port60321 is permitted. Production configuration and sessions are not read.\nNo production backup helper or scheduling is included. See the source docs/karvaan-candidate-evidence.md.\n',encoding='utf-8')
for p in payload.rglob('*.pdb'):p.unlink() # Candidate copy only; preserve original build symbols.
compiler=Path('D:/portfolio/transport_project/tools/.local/inno/compiler/ISCC.exe')
verify_compiler(compiler)
with (out/'installer-build.log').open('w',encoding='utf-8') as log:
 result=subprocess.run([str(compiler),'/DPayloadDir='+str(payload),'/DOutputDir='+str(out/'windows'),'/DAppVersion=0.2.0','/DBuildNumber='+version.split('+')[1],str(ROOT/'tools/windows/carrier-records.iss')],stdout=log,stderr=subprocess.STDOUT)
require(result.returncode==0,'Installer compilation failed.')
print('PASS candidate installer compiled; NOT installed.',flush=True);record()
build('web',ROOT/'app/build/web',out/'web')
(out/'web/_redirects').write_bytes(b'/* /index.html 200\n')
build('apk',ROOT/'app/build/app/outputs/flutter-apk',out/'android')
for folder in ['windows/payload','web']:
 target=out/(folder.split('/')[0]+'-candidate.zip')
 with zipfile.ZipFile(target,'x',zipfile.ZIP_DEFLATED) as archive:
  for p in sorted((out/folder).rglob('*')):
   if p.is_file():archive.write(p,p.relative_to(out/folder))
record();print('PASS candidate files and SHA256 manifest: '+str(out/'manifest.json'),flush=True)
