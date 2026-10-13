"""Byte-for-byte source/assets preservation against the committed main base."""
import hashlib,json,subprocess
from local_environment import ROOT,boundary,require
boundary()
base='a0bd553b6de18352f587cb1cc6fc662443f9178b'
paths=['app/lib/features/reports/authorized_output.dart','app/lib/features/reports/output_pdf.dart',
 'app/lib/features/reports/output_xlsx.dart','app/assets/fonts/NotoSans-Regular.ttf','app/assets/fonts/NotoSans-Bold.ttf']
report=[]
for path in paths:
 original=subprocess.run(['git','show',base+':'+path],cwd=ROOT,check=True,capture_output=True).stdout
 actual=(ROOT/path).read_bytes()
 # Git LF normalization applies to source, never binary assets.
 if path.endswith('.dart'):actual=actual.replace(b'\r\n',b'\n')
 require(actual==original,'Legacy renderer/asset changed: '+path)
 report.append({'path':path,'sha256':hashlib.sha256(actual).hexdigest()})
(ROOT/'tools/.local/karvaan-legacy-audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS all three legacy parser/renderers and both Latin font assets identical to base main.')
