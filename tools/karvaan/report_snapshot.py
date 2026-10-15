"""Compare complete authorized synthetic report payloads and immutable history."""
import json,sys
from pathlib import Path
from local_environment import ROOT,boundary,status,validate_defines,sql,require
from profile_reports import http_request
boundary();cfg=status();validate_defines(json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text(encoding='utf-8')))
a=json.loads((ROOT/'tools/.local/karvaan-review-auth.json').read_text(encoding='utf-8'));d=json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text(encoding='utf-8'));b=d['APP_BUSINESS_ID']
token=http_request('/auth/v1/token?grant_type=password',{'email':f'review_admin.{b}@staff.invalid','password':a['usernames']['review_admin']},cfg['ANON_KEY'])[0]['access_token']
values={}
for month,end in [('01','31'),('06','30'),('12','31')]:
 for kind in ['MONTHLY_VEHICLE','MONTHLY_OWNER','CLAIMS']:
  payload,meta=http_request('/rest/v1/rpc/get_scoped_report',{'report_kind':kind,'filters':{'from':f'2026-{month}-01','to':f'2026-{month}-{end}'},'page_offset':0},cfg['ANON_KEY'],token)
  require(meta['http_status']==200,'Snapshot '+kind+month+' failed '+json.dumps(meta));payload.pop('generated_at',None);values[kind+month]=payload
history={}
for table in ['trips','consignments','expenses','financial_events','journal_lines','allocations','issued_documents']:
 history[table]=json.loads(sql(f"select jsonb_build_object('count',count(*),'digest',md5(coalesce(string_agg(to_jsonb(t)::text,'|' order by id),''))) from public.{table} t;"))
values['immutable_history']=history
path=ROOT/'tools/.local/karvaan-period-before.json'
if sys.argv[1]=='before':path.write_text(json.dumps(values,sort_keys=True),encoding='utf-8');print('PASS nine complete baseline reports and immutable history fingerprints recorded.')
else:
 previous=json.loads(path.read_text(encoding='utf-8'));require(previous==values,'Report or historical-record comparison failed.');print('PASS nine complete report payloads identical; original financial/trip/document rows unchanged.')
