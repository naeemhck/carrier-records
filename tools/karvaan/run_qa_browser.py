"""Run isolated QA browser checks; credentials only in child environment, not arguments."""
import json,os,subprocess,sys
from qa_seed import unprotect
from qa_preview import FOLDER,ROOT,guard
if __name__=='__main__':
 guard();env=os.environ.copy();env['KARVAAN_QA_CREDENTIALS']=json.dumps(unprotect(FOLDER/'tester-credentials.dpapi'))
 node='C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node.exe'
 r=subprocess.run([node,str(ROOT/'tools/karvaan/qa_browser_smoke.cjs'),*sys.argv[1:]],cwd=ROOT,env=env)
 env.pop('KARVAAN_QA_CREDENTIALS',None);sys.exit(r.returncode)
