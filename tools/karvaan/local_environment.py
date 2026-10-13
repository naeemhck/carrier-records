"""Strict local candidate boundary. No link/push/reset commands or hosted APIs."""
import argparse,json,socket,subprocess,tomllib,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PROJECT='karvaan_bilingual_u20261013'
API='http://127.0.0.1:60321'
CLI=ROOT/'tools/.local/supabase/supabase.exe'
IDENTITY={'project_id':PROJECT,'api_port':60321,'purpose':'synthetic-only'}

def require(condition,message):
    if not condition:raise RuntimeError(message)

def boundary():
    branch=subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
    require(branch=='update/karvaan-bilingual','Wrong worktree branch.')
    cfg=tomllib.loads((ROOT/'supabase/config.toml').read_text(encoding='utf-8'))
    require(cfg['project_id']==PROJECT and cfg['api']['port']==60321 and cfg['db']['port']==60322,'Local project/API/database mismatch.')
    require(cfg['db']['shadow_port']==60320 and cfg['edge_runtime']['inspector_port']==18083,'Local shadow/inspector port mismatch.')
    require(CLI.is_file(),'Verified official CLI absent.')

def sql(query):
    r=subprocess.run(['docker','exec','-i','supabase_db_'+PROJECT,'psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=query,capture_output=True,text=True,check=True)
    return r.stdout.strip()

def status():
    r=subprocess.run([str(CLI),'status','-o','json'],cwd=ROOT,capture_output=True,text=True,check=True)
    cfg=json.loads(r.stdout)
    require(cfg['API_URL']==API,'Unexpected CLI endpoint.')
    names=subprocess.run(['docker','ps','--format','{{.Names}}'],capture_output=True,text=True,check=True).stdout.splitlines()
    require('supabase_db_'+PROJECT in names and 'supabase_kong_'+PROJECT in names,'Intended containers absent.')
    return cfg

def validate_defines(defines):
    require(isinstance(defines,dict) and set(defines)=={'APP_ENV','SUPABASE_URL','SUPABASE_PUBLISHABLE_KEY','APP_BUSINESS_ID'},'Invalid local defines fields.')
    require(defines['APP_ENV']=='test' and defines['SUPABASE_URL']==API,'Pinned local endpoint required.')
    cfg=status()
    require(defines['SUPABASE_PUBLISHABLE_KEY']==cfg['ANON_KEY'],'Isolated public key mismatch.')
    req=urllib.request.Request(API+'/rest/v1/rpc/karvaan_local_identity',data=b'{}',headers={'apikey':cfg['ANON_KEY'],'Content-Type':'application/json'})
    with urllib.request.urlopen(req,timeout=15) as response:require(json.load(response)==IDENTITY,'Backend identity mismatch.')
    require(sql('select id from public.businesses order by id;')==defines['APP_BUSINESS_ID'],'Synthetic business mismatch.')

def start():
    existing=subprocess.run(['docker','ps','-a','--format','{{.Names}}'],capture_output=True,text=True,check=True).stdout.splitlines()
    if 'supabase_db_'+PROJECT not in existing:
        sockets=[]
        try:
            for port in [*range(60320,60330),18083]:
                probe=socket.socket();sockets.append(probe);probe.bind(('0.0.0.0',port))
        finally:
            for probe in sockets:probe.close()
    log=ROOT/'tools/.local/karvaan-start.log';log.parent.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([str(CLI),'start'],cwd=ROOT,capture_output=True,text=True)
    # CLI completion emits credentials as JSON. Keep progress, never that JSON.
    safe=[]
    for line in (result.stdout+'\n'+result.stderr).splitlines():
        if line.lstrip().startswith('{'):continue
        if any(key in line.upper() for key in ('SECRET','SERVICE_ROLE','JWT','S3_PROTOCOL','DB_URL','ANON_KEY','PUBLISHABLE_KEY')):continue
        safe.append(line)
    log.write_text('\n'.join(safe)+'\n',encoding='utf-8')
    result.check_returncode()
    status()
    # Test-only invoker identity probe; no protected data or privilege bypass.
    sql("""create or replace function public.karvaan_local_identity() returns jsonb language sql stable security invoker set search_path='' as $$ select '{"project_id":"karvaan_bilingual_u20261013","api_port":60321,"purpose":"synthetic-only"}'::jsonb $$; revoke all on function public.karvaan_local_identity() from public; grant execute on function public.karvaan_local_identity() to anon,authenticated; notify pgrst,'reload schema';""")
    print('PASS isolated local containers, preflight ports and synthetic-only identity; no reset.')

def main():
    parser=argparse.ArgumentParser();parser.add_argument('action',choices=['start','check']);parser.add_argument('--defines',type=Path)
    args=parser.parse_args();boundary()
    if args.action=='start':start()
    else:
        require(args.defines is not None,'Local defines required.')
        path=args.defines.resolve();require(path.is_relative_to((ROOT/'tools/.local').resolve()),'Only ignored local defines permitted.')
        validate_defines(json.loads(path.read_text(encoding='utf-8')))
        print('PASS pinned local endpoint/container/project/business/public key verification.')
if __name__=='__main__':main()
