"""AT-31 trusted helper integration and real-role backup-status authorization."""
import copy,json,subprocess,uuid
from pathlib import Path
def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];b,at=env['b'],env['at'];ap=env['profile'](at)
    def good(name,r):
        if r[0]!=200:raise AssertionError(name+': '+str(r))
        ok(name,True);return r[1]
    st=good('T16 staff login',env['login']('outside',env['real']))['access_token']
    ok('AT31 staff backup metadata denied',rpc('get_backup_status',{},st)[0]==403)
    ok('AT31 anonymous backup metadata denied',rpc('get_backup_status',{})[0]>=400)
    for token in [st,at,None]:
        args={'business_id':b,'admin_staff_id':ap['id'],'run_id':str(uuid.uuid4()),'outcome':'RUNNING'}
        ok('AT31 ordinary client cannot forge helper success',rpc('record_backup_status',args,token)[0] in (401,403))
        ok('AT31 direct backup table mutation denied',env['request']('/rest/v1/backup_status',{},token)[0] in (401,403))
    before=sql(f"select jsonb_build_object('events',(select count(*) from public.financial_events where business_id='{b}'),'journals',(select count(*) from public.journal_lines where business_id='{b}'),'allocations',(select count(*) from public.allocations where business_id='{b}')); ")
    runtime=Path('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');folder=env['ROOT']/'tools/.local'/('t16-real-'+str(uuid.uuid4()));folder.mkdir()
    context={'root':str(folder),'business_id':b,'url':env['base'],'service':env['secret'],'publishable':env['anon'],'password':env['real'],'office_id':env['office'][0]}
    with (env['ROOT']/'tools/.local/t16-real-helper.log').open('w',encoding='utf-8') as log:r=subprocess.run([str(runtime),str(env['ROOT']/'tools/tests/t16_real_helper.py')],input=json.dumps(context),text=True,stdout=log,stderr=subprocess.STDOUT)
    ok('AT31 actual Windows helper archive incremental encryption interruption and vault integration',r.returncode==0)
    status=good('AT31 administrator sanitized backup status',rpc('get_backup_status',{},at))
    ok('AT31 last verified success truthful after failures',status['last_verified_success_at'] is not None and status['outcome'] in('SUCCESS','FAILED') and status['restoration_verified'] is False and status['off_pc_copy_reminder'])
    ok('AT31 backup traffic included',int(status['backup_traffic_monthly_bytes'])>0 and 'database_bytes' in status['metrics'] and 'storage_bytes' in status['metrics'] and not status['other_traffic_known'])
    ok('AT31 payload excludes secrets paths and source identifiers',all(x not in json.dumps(status) for x in [env['secret'],env['real'],'credential_prefix','backup_root','object_path','admin_staff_id','business_id']))
    after=sql(f"select jsonb_build_object('events',(select count(*) from public.financial_events where business_id='{b}'),'journals',(select count(*) from public.journal_lines where business_id='{b}'),'allocations',(select count(*) from public.allocations where business_id='{b}')); ")
    ok('AT31 backups do not change financial events',before==after)
    # Explicit isolated usage/date fixtures exercise display thresholds without inventing provider measurements.
    sql(f"update public.backup_status set metrics=metrics||'{{\"database_bytes\":375000000}}'::jsonb,version=version+1 where business_id='{b}';")
    ok('AT31 75 percent warning',rpc('get_backup_status',{},at)[1]['quota_level']=='75_PERCENT')
    sql(f"update public.backup_status set metrics=metrics||'{{\"storage_bytes\":900000000}}'::jsonb,last_verified_success_at=now()-interval '48 hours',version=version+1 where business_id='{b}';")
    status=good('AT31 simulated offline stale status',rpc('get_backup_status',{},at));ok('AT31 90 percent warning and missed backup visible',status['quota_level']=='90_PERCENT' and status['stale'])
    rid=str(uuid.uuid4());args={'business_id':b,'admin_staff_id':ap['id'],'run_id':rid,'outcome':'RUNNING'}
    good('AT31 trusted service registers attempt',rpc('record_backup_status',args,priv=True));args=dict(args,outcome='FAILED',safe_error_code='DATABASE_EXPORT_FAILED',metrics={'dump_bytes':20})
    first=good('AT31 trusted service reports failure',rpc('record_backup_status',args,priv=True));ok('AT31 failure report retries once',rpc('record_backup_status',args,priv=True)==(200,first))
    ok('AT31 modified report retry denied',rpc('record_backup_status',dict(args,metrics={'dump_bytes':21}),priv=True)[0]==409)
    ok('AT31 cannot report success without verified digest',rpc('record_backup_status',dict(args,run_id=str(uuid.uuid4()),outcome='SUCCESS'),priv=True)[0]>=400)
    args=dict(args,run_id=str(uuid.uuid4()),metrics={'credential':'forbidden'});ok('AT31 unsafe report metadata rejected',rpc('record_backup_status',args,priv=True)[0]==400)
    print('T16 AT31 helper/status checks PASS',flush=True)
