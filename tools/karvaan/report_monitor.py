"""Read-only wait/resource observations; never collect SQL text or credentials."""
import json,subprocess,threading,time
from local_environment import PROJECT

class ReportMonitor:
 def __init__(self,enabled=True):self.enabled=enabled;self.result={'enabled':enabled,'interval_seconds':2,'samples':[],'errors':[]};self.stop=threading.Event()
 def __enter__(self):
  if self.enabled:self.thread=threading.Thread(target=self.collect,daemon=True);self.thread.start()
  return self
 def collect(self):
  statement="select jsonb_build_object('utc',clock_timestamp(),'connections',count(*),'active',count(*) filter(where state='active'),'active_reports',count(*) filter(where state='active' and query like '%get_scoped_report%'),'lock_waits',count(*) filter(where wait_event_type='Lock'),'blocked_connections',count(*) filter(where cardinality(pg_blocking_pids(pid))>0),'waits',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select state,wait_event_type,wait_event,count(*) sessions from pg_stat_activity where datname=current_database() and pid<>pg_backend_pid() group by 1,2,3)x)) from pg_stat_activity where datname=current_database() and pid<>pg_backend_pid();"
  while not self.stop.is_set():
   try:
    r=subprocess.run(['docker','exec','-i','supabase_db_'+PROJECT,'psql','-U','postgres','-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=statement,capture_output=True,text=True,encoding='utf-8',timeout=10,check=True)
    self.result['samples'].append(json.loads(r.stdout))
   except Exception as error:self.result['errors'].append(type(error).__name__)
   self.stop.wait(2)
 def __exit__(self,*args):
  if self.enabled:self.stop.set();self.thread.join(timeout=12)
