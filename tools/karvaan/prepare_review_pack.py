"""Assemble only inspected synthetic samples and numeric evidence for local review."""
import hashlib,json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
version=sys.argv[1]
if not __import__('re').fullmatch(r'0\.2\.0\+\d+',version):raise ValueError('Explicit candidate version required')
root=ROOT/'tools/.local/candidates'/version
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
pack=root/'review-pack';pack.mkdir(exist_ok=True)
documents=ROOT/'tools/.local/karvaan-documents'
inspections=json.loads((documents/'inspection.json').read_text(encoding='utf-8'))
for item in inspections:
 name=item['file'];source=documents/name
 if Path(name).name!=name or source.suffix not in {'.pdf','.xlsx'}:raise ValueError('Only inspected document files allowed')
 if hashlib.sha256(source.read_bytes()).hexdigest()!=item['sha256']:raise ValueError('Document changed since inspection')
 destination=pack/'samples'/name;destination.parent.mkdir(exist_ok=True);shutil.copyfile(source,destination)
for name in ['unit_wide-page1.png','unit_wide-page10.png','unit_wide-page21.png','issued_v2-page7.png','owner_v2-page3.png']:
 source=documents/name
 if not source.is_file():raise ValueError('Missing rendered review page')
 shutil.copyfile(source,pack/'samples'/name)
shutil.copyfile(documents/'inspection.json',pack/'samples/inspection.json')
shutil.copyfile(ROOT/'bilingual-glossary.md',pack/'bilingual-glossary.md')
shutil.copyfile(root/'manifest.json',pack/'build-manifest.json')
shutil.copyfile(root/'audit.json',pack/'candidate-audit.json')
for name in ['karvaan-report-profile-20261014-120344.json','karvaan-report-profile-20261014-120502.json','karvaan-db-profile-20261014-120233.json','karvaan-report-profile-20261014-153052.json']:
 source=ROOT/'tools/.local'/name
 if not source.is_file():raise ValueError('Missing numeric performance evidence')
 shutil.copyfile(source,pack/name)
artifacts=[item for item in manifest['files'] if item['path'].endswith(('.apk','setup.exe','.zip')) or item['path']=='windows/payload/carrier_records.exe']
(pack/'artifact-summary.json').write_text(json.dumps({'version':version,'compiled_source_commit':manifest['source_commit'],'artifacts':artifacts},indent=2)+'\n',encoding='utf-8')
readme=f"""# Karvaan {version}: local candidate review pack

Compiled source: {manifest['source_commit']}. QA/evidence changes afterward do not change compiled bytes. All artifacts are local synthetic candidates, NOT installed/deployed. Earlier candidates are preserved.

## Gate disposition

NOT fully review-ready. Controlled HTTP summaries passed p95 3.813052s / 4.516024s and screens 0.887998s / 1.318422s (50 each, five restricted users, annual 12,000 trips). Earlier failed results are retained in source evidence. Five-user release-browser verification remains unresolved: measured-response timeouts and a subsequent fifth-user warm-up HTTP500 / PostgreSQL57014. No passing browser p95 is inferred. A fresh HTTP recheck after browser closure also FAILED: 21/50 summaries returned500, all50 screens200; attempted-response p95 summaries8.395284s and screens3.239297s. These timings include failed responses and are not success-only performance claims. Latest required performance gate is unresolved.

Windows candidate launched and restored its isolated protected administrator session; bilingual dashboard/account statuses observed through accessibility. Native screenshot capture/fresh indexed click/keyboard focus failed in Computer Use; native form/connection/document workflows are NOT passed. Owner cannot manually check now. Android SDK debug build exists; no connected Android device/emulator, and T20 remains TODO.

## Completed evidence

Current-source analyzer and 114 Flutter tests; 74 affected backend checks and 220 transactional SQL assertions. New template2 selected order, required fields, recipient privacy, exact totals and immutable legacy reprints have executed evidence. Eight inspected PDF/XLSX pairs (61 PDF pages) are in samples; inspection.json records exact hashes/font/sheet observations. Embedded Arabic font and joining, mixed Latin text, wide21-page tables and long names were visually inspected. Unit stress-fixture generic metadata terms are deliberate test labels, not approved office vocabulary. Production version2 samples use the documented server-owned labels.

Actual release-browser basic smoke records three local synthetic roles, office labels, no admin controls for staff, bilingual navigation/narrow captures, exact report totals, read connection failure and recovery. See web-smoke.json. Browser measured timings in that basic run are NOT controlled five-user measurements. web-write-smoke.json records a normal synthetic category form: aborted save retained input and showed no success, identical retry committed exactly one record, then normal versioned archive retained it. Failure/recovery screenshots were visually inspected.

## Review route and unavailable checks

Do not run the installer over the existing app. Use only the copied Windows payload with its pinned local candidate policy/backend, or the served web artifact on localhost8767. Never substitute hosted or installed configuration. Native uses karvaan.candidate.session rather than carrier.session. Keep passwords in the local app, not this pack. No authentication material is included.

When available: check native single-click navigation/forms, dropdown dismissal, keyboard text/paste, retained values/no success on lost connection, retry without duplication, document generation and scope; capture actual rendered screens. Repeat five-user browser performance on the same annual dataset with captured failures/sample counts and no target/security relaxation. Test Android candidate locally on a device/emulator when available, without claiming T20 release readiness.

Review glossary's unresolved provisional terms and original554 preservation. Preserve T19 owner acceptance/waivers without calling skipped checks passed. No push, main merge, installation, deployment, hosted backend contact or production scheduling is authorized.

build-manifest.json is immutable compiled-file evidence; artifact-summary.json lists exact artifact sizes/SHA256. review-manifest.json independently covers this evolving QA pack. Credentials/raw session data, operational receipts, backups and recovery material are excluded.
"""
(pack/'README.md').write_text(readme,encoding='utf-8')
items=[]
for file in sorted(pack.rglob('*')):
 if file.is_file() and file.name!='review-manifest.json':items.append({'path':file.relative_to(pack).as_posix(),'bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
(pack/'review-manifest.json').write_text(json.dumps({'version':version,'source_commit':manifest['source_commit'],'files':items},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'review_files':len(items),'inspected_pairs':len(inspections)//2,'compiled_source_commit':manifest['source_commit'],'fully_review_ready':False}))
