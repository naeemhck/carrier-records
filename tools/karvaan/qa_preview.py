"""Explicit hosted synthetic QA boundary. Never links or targets the pilot project."""
import hashlib,json,re,subprocess,sys,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CLI=ROOT/'tools/.local/supabase/supabase.exe'
FOLDER=ROOT/'tools/.local/qa-preview'
REF='nxyjjjxvgibehovlyycx'
ORG='ninsjeitbhvymnaoqtcx'
API='https://'+REF+'.supabase.co'

def require(ok,message):
 if not ok: raise RuntimeError(message)

def cli(*args):
 r=subprocess.run([str(CLI),*args],cwd=ROOT,capture_output=True,text=True,encoding='utf-8')
 if r.returncode: raise RuntimeError('QA CLI failed: '+r.stderr[-1800:])
 return r.stdout

def query(sql):
 path=FOLDER/'query.sql';path.write_text(sql,encoding='utf-8')
 try:return json.loads(cli('db','query','--linked','--project-ref',REF,'--file',str(path),'-o','json'))['rows']
 finally:path.unlink(missing_ok=True)

def guard():
 require(subprocess.run(['git','branch','--show-current'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()=='update/karvaan-bilingual','Wrong branch')
 projects=json.loads(cli('projects','list','-o','json'))
 rows=[p for p in projects if p['id']==REF]
 require(len(rows)==1 and rows[0]['name']=='karvaan-test' and rows[0]['organization_id']==ORG and rows[0]['status']=='ACTIVE_HEALTHY','TEST project verification failed')
 # Never reuse a nonempty project unless our separate deployment marker exists.
 require(REF!='tuasxnfwrepbcelnrlgb' and REF!='zuoaxtjfylfuwsxfbgzl','Existing project forbidden')

def migrate():
 guard()
 marker=query("select to_regclass('qa_preview.applied_migrations') is not null ready;")[0]['ready']
 if not marker:
  empty=query("select (select count(*) from auth.users)+(select count(*) from information_schema.tables where table_schema='public') n;")[0]['n']
  require(empty==0,'New TEST database must be empty before initial setup')
  query("create schema qa_preview; revoke all on schema qa_preview from public,anon,authenticated; create table qa_preview.applied_migrations(version text primary key,sha256 text not null); create schema if not exists supabase_migrations; create table if not exists supabase_migrations.schema_migrations(version text primary key, statements text[], name text);")
 applied={r['version']:r['sha256'] for r in query('select * from qa_preview.applied_migrations;')}
 for file in sorted((ROOT/'supabase/migrations').glob('*.sql')):
  version,name=file.stem.split('_',1);text=file.read_text(encoding='utf-8');digest=hashlib.sha256(file.read_bytes()).hexdigest()
  if version in applied:
   require(applied[version]==digest,'Applied migration source changed');continue
  # Existing transaction delimiters become one atomic migration + history commit.
  body=re.sub(r'(?im)^\s*(?:begin|commit);[ \t]*$', '',text)
  script="begin;\n"+body+"\ninsert into qa_preview.applied_migrations values ('"+version+"','"+digest+"'); insert into supabase_migrations.schema_migrations(version,name) values ('"+version+"','"+name+"'); commit; select '"+version+"' applied;"
  query(script);print('PASS TEST migration '+file.name,flush=True)
 print('PASS all tracked migrations applied only to '+REF,flush=True)

if __name__=='__main__':
 try:
  FOLDER.mkdir(parents=True,exist_ok=True)
  if sys.argv[1]=='migrate':migrate()
  elif sys.argv[1]=='check':guard();print(json.dumps(query("select (select count(*) from qa_preview.applied_migrations) migrations,(select count(*) from information_schema.tables where table_schema='public') tables,(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r' and not c.relrowsecurity) unprotected_tables;")))
 except Exception as e:print(str(e),file=sys.stderr);sys.exit(1)
