"""Framework-driven native GUI check; pinned synthetic backend, private transient defines."""
import json, shutil, subprocess, time
from local_environment import ROOT, boundary, validate_defines, require


def main():
    boundary()
    config = json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text(encoding='utf-8'))
    validate_defines(config)
    auth = json.loads((ROOT/'tools/.local/karvaan-review-auth.json').read_text(encoding='utf-8'))
    stamp = time.strftime('%Y%m%d-%H%M%S')
    evidence = ROOT/'tools/.local'/('gui12-native-'+stamp)
    evidence.mkdir(exist_ok=False)
    private = evidence/'private-defines.json'
    credentials = evidence/'private-auth.json'
    credentials.write_text(json.dumps({'username':'review_admin','password':auth['usernames']['review_admin']}),encoding='utf-8')
    private.write_text(json.dumps(config | {'TEST_USERNAME':'review_admin','TEST_AUTH_FILE':str(credentials),'TEST_TRIP_ID':auth['trip_id'],'TEST_EVIDENCE_DIR':str(evidence)}), encoding='utf-8')
    debug = ROOT/'app/build/windows/x64/runner/Debug'
    try:
        if debug.exists():
            shutil.copytree(debug, ROOT/'tools/.local/preserved-artifacts'/('gui12-native-'+stamp))
        args = ['powershell','-NoProfile','-File',str(ROOT/'tools/flutter.ps1'),'test','integration_test/karvaan_gui_test.dart','-d','windows','--no-pub','--dart-define=KARVAAN_LOCAL_ONLY=true','--dart-define=use_arabic=true','--dart-define-from-file='+str(private)]
        started = time.perf_counter()
        with (evidence/'test.log').open('w',encoding='utf-8') as log:
            result = subprocess.run(args,cwd=ROOT/'app',stdout=log,stderr=subprocess.STDOUT)
        (evidence/'result.json').write_text(json.dumps({'exit_code':result.returncode,'seconds':round(time.perf_counter()-started,3),'method':'native Flutter integration_test; not OS input','backend':'local synthetic 60321','session_prefix':'karvaan.gui.integration','source_commit':subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()},indent=2),encoding='utf-8')
        print('Native integration exit '+str(result.returncode)+'; evidence '+str(evidence),flush=True)
        require(result.returncode==0,'Native GUI verification failed; inspect ignored log, not a pass.')
    finally:
        private.unlink(missing_ok=True)
        credentials.unlink(missing_ok=True)

if __name__=='__main__': main()
