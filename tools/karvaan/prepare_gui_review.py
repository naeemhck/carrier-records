"""New GUI review pack only; immutable existing candidates and synthetic audited samples."""
import hashlib,json,re,shutil,sys
from pathlib import Path
from local_environment import ROOT,boundary,require
boundary()
version=sys.argv[1]
require(re.fullmatch(r'0\.2\.0\+\d+',version) is not None,'Explicit candidate required.')
root=ROOT/'tools/.local/candidates'/version
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
pack=root/'review-pack';pack.mkdir(exist_ok=False)
def copy(source,target):
    require(source.is_file(),'Missing review evidence: '+source.name)
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
documents=ROOT/'tools/.local/karvaan-documents'
inspection=json.loads((documents/'inspection.json').read_text(encoding='utf-8'))
for item in inspection:
    name=item['file'];source=documents/name
    require(source.name==name and source.suffix in {'.pdf','.xlsx'},'Invalid sample path.')
    require(hashlib.sha256(source.read_bytes()).hexdigest()==item['sha256'],'Sample changed after inspection.')
    copy(source,pack/'samples'/name)
for name in ['unit_wide-page1.png','unit_wide-page10.png','unit_wide-page21.png','broker_v2-page7.png','owner_v2-page3.png']:
    copy(documents/name,pack/'samples'/name)
copy(documents/'inspection.json',pack/'samples/inspection.json')
for name in ['bilingual-glossary.md','docs/karvaan-gui-evidence.md']:
    copy(ROOT/name,pack/Path(name).name)
copy(root/'manifest.json',pack/'build-manifest.json');copy(root/'audit.json',pack/'candidate-audit.json')
# Explicit folders created by this GUI verification; never credential/config/log files.
for folder in sys.argv[2:]:
    require(re.fullmatch(r'gui[0-9]+-[a-z0-9-]+',folder) is not None,'Invalid evidence folder.')
    source=ROOT/'tools/.local'/folder
    require(source.is_dir(),'Evidence directory missing.')
    extra = json.loads((source/'inspection.json').read_text(encoding='utf-8')) if (source/'inspection.json').exists() else []
    for item in extra:
        name=item['file'];sample=source/name
        require(sample.name==name and sample.suffix in {'.pdf','.xlsx'} and hashlib.sha256(sample.read_bytes()).hexdigest()==item['sha256'],'Uninspected or changed browser export.')
        copy(sample,pack/'verification'/folder/name)
    if extra:copy(source/'inspection.json',pack/'verification'/folder/'inspection.json')
    for p in source.iterdir():
        if p.suffix=='.png' or p.name in {'result.json','failure.json','web-smoke.json','web-write-smoke.json'}:
            copy(p,pack/'verification'/folder/p.name)
artifacts=[x for x in manifest['files'] if x['path'].endswith(('.apk','setup.exe','.zip')) or x['path']=='windows/payload/carrier_records.exe']
(pack/'artifact-summary.json').write_text(json.dumps({'version':version,'compiled_source_commit':manifest['source_commit'],'artifacts':artifacts},indent=2),encoding='utf-8')
(pack/'README.md').write_text(f'''# Karvaan {version}: local GUI review candidate

Compiled source: {manifest['source_commit']}. See artifact-summary.json for exact paths, sizes and SHA256. Installer compiled, NOT installed; Android debug artifact is for testing, not T20 release readiness. Use local synthetic backend60321 only; no production configuration/session access. Earlier artifacts remain intact.

## Review material

verification/: actual release-web screenshots/results; native integration captures where included are Flutter-engine/framework-driven, not OS-input proof. Samples: eight synthetic PDF/XLSX pairs already inspected for content, embedded fonts, metadata, hidden sheets/columns and safe types. Three unit samples were generated during current GUI regression runs; five backend-derived v2 samples are retained output-verification fixtures, not newly issued here. Unchanged renderers preserve accounting, selected order and legacy snapshots. No mockup mapping: six reference PNGs were unavailable; written specification used.

## Remaining gates and dependencies

- Separate monthly five-user performance p955.871856s exceeds5s. Candidate12 default monthly report also returned HTTP500/57014 after successful authentication; baseline comparison is recorded in verification. No GUI diagnostic clears the performance gate.
- G07 remains IN PROGRESS: existing frozen v2 broker/wide PDFs can have an explanatory-text-only last page. Fixing issued layout needs a newly registered template version; backend contracts are outside this presentation task. Existing issued renderers unchanged.
- Windows launcher plain-path attempt returned the installed executable; no input was sent to it, and startup network activity is unverified. Explicit process identifier correctly launched the local candidate. Computer Use capture/input failed; framework-driven/native and browser tests are labelled separately. Physical keyboard/touch/device checks are not inferred.
- No connected Android device/emulator. Narrow desktop/browser/widget layouts do not establish Android-device validation.
- Six supplied mockups not available; glossary GUI/accounting wording still needs office review.
- T19 owner acceptance, exceptions and waivers remain intact; T20 unstarted.

This is available for local GUI review, NOT a declaration that every release/readiness gate passes. Do not push/merge/install/deploy or use hosted Supabase.

## Manual checks still needed

Launch only this candidate payload against the existing verified synthetic backend. Use separate candidate session. At wide/narrow Windows sizes check navigation scrolling/collapse, keyboard Tab/Enter/Escape and focused dropdown dismissal. Edit the labelled synthetic draft without saving; compare Journey/Consignments/Review values, origin/destination names, exact fare and mixed-script notes. Open dispatch review, require acknowledgement, then Cancel/Escape and verify unchanged draft/version. Exercise expense picker/proof failure handling without real records. Check new Documents list/configuration, authorized exports, long/mixed names, selected columns and all pages. Do not use real credentials/records in chat. Android-device validation stays pending until a device exists.
''',encoding='utf-8')
files=[{'path':p.relative_to(pack).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(pack.rglob('*')) if p.is_file()]
(pack/'review-manifest.json').write_text(json.dumps({'source_commit':manifest['source_commit'],'files':files},indent=2),encoding='utf-8')
print('PASS new local review pack '+str(pack)+'; '+str(len(files))+' hashed files.')
