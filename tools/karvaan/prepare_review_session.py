"""Native protected-store fixture for the ordinary local candidate, no password logging."""
import json,shutil,subprocess,sys
from local_environment import ROOT,boundary,require,validate_defines
boundary();username=sys.argv[1] if len(sys.argv)>1 else 'review_admin'
require(username in {'review_admin','review_khi','review_isb'},'Only labelled synthetic accounts.')
cfg=json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text());validate_defines(cfg)
auth=json.loads((ROOT/'tools/.local/karvaan-review-auth.json').read_text())
path=ROOT/'tools/.local/karvaan-session-fixture-defines.json'
path.write_text(json.dumps(cfg|{'TEST_USERNAME':username,'TEST_PASSWORD':auth['usernames'][username]}),encoding='utf-8')
# Preserve prior native verification artifacts; never copy them into candidates.
debug=ROOT/'app/build/windows/x64/runner/Debug'
preserved=ROOT/'tools/.local/preserved-artifacts'/('session-'+username)
if debug.exists() and not preserved.exists():shutil.copytree(debug,preserved)
try:
 with (ROOT/'tools/.local'/('karvaan-session-'+username+'.log')).open('w',encoding='utf-8') as log:
  result=subprocess.run(['powershell','-NoProfile','-File',str(ROOT/'tools/flutter.ps1'),'test','integration_test/candidate_review_session_test.dart','-d','windows','--no-pub','--dart-define=KARVAAN_LOCAL_ONLY=true','--dart-define=use_arabic=true','--dart-define-from-file='+str(path)],cwd=ROOT/'app',stdout=log,stderr=subprocess.STDOUT)
 require(result.returncode==0,'Native synthetic session fixture failed; see safe log.')
 print('PASS verified synthetic protected candidate session; ordinary executable startup still reauthorizes.')
finally:path.unlink(missing_ok=True)
