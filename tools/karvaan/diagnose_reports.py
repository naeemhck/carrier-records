"""Read-only diagnosis pinned to the isolated synthetic report backend."""
import collections,json,re,subprocess,time
from pathlib import Path
from local_environment import ROOT,PROJECT,boundary,validate_defines,sql

def command(args):
 result=subprocess.run(args,capture_output=True,text=True,encoding='utf-8')
 return result.returncode,result.stdout,result.stderr

def snapshot():
 boundary();validate_defines(json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text(encoding='utf-8')))
 report={'identity':PROJECT,'captured_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}
 def query(name,text):report[name]=json.loads(sql(text))
 query('settings',"select jsonb_object_agg(name,setting) from pg_settings where name in ('max_connections','shared_buffers','work_mem','statement_timeout','track_io_timing','jit');")
 query('role_timeouts',"select coalesce(jsonb_agg(jsonb_build_object('role',rolname,'setting',v)),'[]') from pg_roles cross join lateral unnest(rolconfig) v where v like 'statement_timeout=%' or v like 'work_mem=%';")
 query('database',"select to_jsonb(x) from(select numbackends,xact_commit,xact_rollback,blks_read,blks_hit,temp_files,temp_bytes,deadlocks from pg_stat_database where datname=current_database())x;")
 query('activity',"select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select usename,state,wait_event_type,wait_event,count(*) sessions from pg_stat_activity where datname=current_database() and pid<>pg_backend_pid() group by 1,2,3,4)x;")
 for short in ['db','rest','kong']:
  _,raw,_=command(['docker','inspect','supabase_'+short+'_'+PROJECT]);container=json.loads(raw)[0]
  report[short+'_container']={'running':container['State']['Running'],'health':container['State'].get('Health',{}).get('Status'),'oom_killed':container['State']['OOMKilled'],'restarts':container['RestartCount'],'resources':{k:container['HostConfig'].get(k) for k in ['NanoCpus','CpuPeriod','CpuQuota','CpusetCpus','Memory','MemorySwap']}}
  if short=='rest':report['rest_pool']={k:v for k,v in (entry.split('=',1) for entry in container['Config']['Env'] if '=' in entry) if k in ['PGRST_DB_POOL','PGRST_DB_POOL_ACQUISITION_TIMEOUT','PGRST_DB_MAX_ROWS']}
 _,host,_=command(['powershell','-NoProfile','-Command',"$c=Get-CimInstance Win32_Processor | Select-Object CurrentClockSpeed,MaxClockSpeed,LoadPercentage; $m=Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize,FreePhysicalMemory; @{cpu=$c;memory=$m}|ConvertTo-Json -Compress"])
 report['host']=json.loads(host)
 for name,file in [('cpu_pressure','/proc/pressure/cpu'),('memory_pressure','/proc/pressure/memory'),('io_pressure','/proc/pressure/io'),('cpu_cgroup','/sys/fs/cgroup/cpu.stat')]:
  code,out,_=command(['docker','exec','supabase_db_'+PROJECT,'cat',file]);report[name]=out.strip() if code==0 else 'unavailable'
 code,out,_=command(['docker','exec','supabase_db_'+PROJECT,'df','-Pk','/var/lib/postgresql/data']);report['disk']=out.strip() if code==0 else 'unavailable'
 code,out,err=command(['docker','logs','--since','2026-10-14T22:30:00Z','--until','2026-10-14T22:33:00Z','supabase_rest_'+PROJECT]);logs=out+'\n'+err
 report['original_failure_window']={'log_read_exit':code,'sql_error_codes':dict(collections.Counter(re.findall(r'"code":"([A-Z0-9]+)"',logs))),'http_500_summary_lines':sum('POST /rpc/get_scoped_report HTTP/1.1" 500' in line for line in logs.splitlines()),'auth_or_permission_error_lines':sum(any(x in line for x in ['bad_jwt','42501','PGRST301']) for line in logs.splitlines())}
 path=ROOT/'tools/.local'/('karvaan-health-'+time.strftime('%Y%m%d-%H%M%S')+'.json');path.write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps({'evidence':str(path),**report}))
if __name__=='__main__':snapshot()
