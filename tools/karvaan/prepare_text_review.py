"""Copy only hashed synthetic text-QA evidence; never install or publish."""
import hashlib,json,re,shutil,sys
from pathlib import Path
from local_environment import ROOT,boundary,require
boundary()
version=sys.argv[1]
require(re.fullmatch(r'0\.2\.0\+\d+',version) is not None,'Explicit candidate version required.')
root=ROOT/'tools/.local/candidates'/version
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
audit=json.loads((root/'audit.json').read_text(encoding='utf-8'))
require(audit['passed'] and audit['source_commit']==manifest['source_commit'],'Audited matching candidate required.')
pack=root/'review-pack';require(not pack.exists(),'Preserve an existing review pack.')
for name in ['gui'+version.split('+')[1]+'-text-smoke','gui'+version.split('+')[1]+'-text-exports']:
 result=json.loads((ROOT/'tools/.local'/name/'result.json').read_text(encoding='utf-8'))
 require(result['source_commit']==manifest['source_commit'] and not result['errors'] and not result['blocked'] and not result.get('financial_or_draft_writes', result.get('writes', [])),'Matching successful browser evidence required.')
pack.mkdir()
def copy(source,target):
 require(source.is_file() and source.suffix in {'.png','.pdf','.xlsx','.json','.md'},'Only actual review files allowed.')
 target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
for phase in ['before','after']:
 for p in sorted((ROOT/'tools/.local/text-qa/widgets'/phase).glob('*.png')):copy(p,pack/'screens'/phase/p.name)
inspection=json.loads((ROOT/'tools/.local/karvaan-documents/inspection.json').read_text(encoding='utf-8'))
for item in inspection:
 require(Path(item['file']).name==item['file'] and Path(item['file']).suffix in {'.pdf','.xlsx'},'Invalid inspected sample path.')
 p=ROOT/'tools/.local/karvaan-documents'/item['file']
 require(hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256'],'Inspected document changed.')
 copy(p,pack/'samples'/p.name)
copy(ROOT/'tools/.local/karvaan-documents/inspection.json',pack/'samples/inspection.json')
for name in ['unit_owner-page1.png','unit_wide-page1.png','unit_wide-page21.png']:
 copy(ROOT/'tools/.local/karvaan-documents'/name,pack/'samples'/name)
for suffix in ['text-smoke','text-exports']:
 folder=ROOT/'tools/.local'/('gui'+version.split('+')[1]+'-'+suffix)
 for p in folder.iterdir():
  if p.suffix in {'.png','.pdf','.xlsx','.json'}:copy(p,pack/'browser'/suffix/p.name)
for name in ['bilingual-glossary.md','docs/karvaan-text-qa-evidence.md','docs/karvaan-text-review.md']:
 p=ROOT/name;copy(p,pack/p.name)
copy(root/'manifest.json',pack/'build-manifest.json');copy(root/'audit.json',pack/'candidate-audit.json')
readme=f"""# Karvaan {version} — LOCAL text-fix review

Compiled source: {manifest['source_commit']}. Do not install over Carrier Records or publish.
Only the pinned local synthetic backend60321 is allowed. Existing hosted sites are unchanged.

Review screens/before and screens/after for auth, expense sections, route/bidi/status cases,
wide/narrow100/200% layouts, account/sidebar controls and selected trip panels. Browser captures
come from the actual release artifact; framework captures are not native OS-input/device evidence.
Synthetic-mask captures use an invalid synthetic probe, never an account password.

Check readable Urdu joining/descenders, wrapping, route order, Latin digits, labels/error visibility,
grouped PKR amounts and integer counts. Review samples and browser exports for selected order,
privacy and authoritative totals. Legacy v1/v2 renderer sources remain unchanged.

Unresolved: historical monthly performance/timeouts, frozen-v2 wide continuation-only final page,
full native OS-input, Android-device checks and provisional office terminology. GUI approval does
not clear those gates or authorize deployment. T19 dispositions unchanged; T20 unstarted.
"""
(pack/'README.md').write_text(readme,encoding='utf-8')
files=[dict(path=p.relative_to(pack).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(pack.rglob('*')) if p.is_file()]
(pack/'review-manifest.json').write_text(json.dumps(dict(version=version,source_commit=manifest['source_commit'],files=files),indent=2),encoding='utf-8')
print('PASS new local synthetic review pack',len(files),'hashed files',pack)
