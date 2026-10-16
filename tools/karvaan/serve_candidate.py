"""Serve one preserved local candidate on a pinned loopback port; never deploy."""
import hashlib,json,socket,subprocess,sys,time,urllib.request
from local_environment import ROOT,boundary,require
boundary()
version,port=sys.argv[1:3]
require(__import__('re').fullmatch(r'0\.2\.0\+\d+',version) is not None and port in {'8767','8768','8769','8771'},'Explicit candidate and pinned local port required.')
root=ROOT/'tools/.local/candidates'/version
manifest=json.loads((root/'manifest.json').read_text(encoding='utf-8'))
main=next(x for x in manifest['files'] if x['path']=='web/main.dart.js')
require(hashlib.sha256((root/main['path']).read_bytes()).hexdigest()==main['sha256'],'Artifact changed.')
url='http://127.0.0.1:'+port
probe=socket.socket();occupied=probe.connect_ex(('127.0.0.1',int(port)))==0;probe.close()
if occupied:
    with urllib.request.urlopen(url+'/main.dart.js',timeout=30) as response:require(hashlib.sha256(response.read()).hexdigest()==main['sha256'],'Existing server differs; do not replace it.')
    print('PASS reuse matching existing loopback artifact server '+url)
else:
    log_path=ROOT/'tools/.local'/('gui-server-'+port+'.log')
    with log_path.open('ab') as log:
        child=subprocess.Popen([sys.executable,'-m','http.server',port,'--bind','127.0.0.1','--directory',str(root/'web')],stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
    for attempt in range(20):
        try:
            with urllib.request.urlopen(url+'/main.dart.js',timeout=5) as response:require(hashlib.sha256(response.read()).hexdigest()==main['sha256'],'Served artifact differs.')
            break
        except OSError:
            if attempt==19:raise
            time.sleep(.5)
    (ROOT/'tools/.local'/('gui-server-'+port+'.json')).write_text(json.dumps({'pid':child.pid,'version':version,'port':int(port),'directory':str(root/'web')},indent=2),encoding='utf-8')
    print('PASS new loopback-only candidate server '+url+'; PID '+str(child.pid))
