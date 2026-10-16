"""After live verification, issue fresh temporary TEST passwords requiring change."""
import json,secrets,sys
from qa_seed import Backend,protect,unprotect
from qa_preview import FOLDER,require,query

def main():
 b=Backend();path=FOLDER/'tester-credentials.dpapi';creds=unprotect(path);target=json.loads((FOLDER/'target.json').read_text());business=target['business_id'];state=json.loads((FOLDER/'seed-state.json').read_text())
 require(not (FOLDER/'handoff-status.json').exists(),'Handoff reset already attempted; inspect state instead of repeating')
 token=b.login('qa_admin',creds['qa_admin']['password'],business)
 staff=b.rpc('list_staff_accounts',token=token)
 # Existing contracts may return rows directly or a page; no user recreation.
 if isinstance(staff,dict):staff=staff['rows']
 ids={row['username']:row for row in staff}
 report=[]
 (FOLDER/'handoff-status.json').write_text(json.dumps({'stage':'started','completed':report}),encoding='utf-8')
 for name in ['qa_khi','qa_isb','qa_admin']:
  require(name in ids,'Expected existing TEST user missing')
  value='Qa!'+secrets.token_urlsafe(24)
  creds[name]['handoff_temporary']=value;protect(creds,path)
  row=ids[name]
  b.call('/functions/v1/staff-accounts',{'action':'reset','target_id':row['id'],'expected_version':row['version'],'password':value},token)
  fresh=b.login(name,value,business);profile=b.rpc('get_session_profile',token=fresh);require(profile['must_change_password'] is True,'Reset did not require password change')
  b.call('/rest/v1/rpc/list_trips',{},fresh,expect=[403]);b.call('/auth/v1/logout?scope=local',{},fresh)
  creds[name]={'handoff_temporary':value};protect(creds,path)
  report.append({'username':name,'role':profile['role'],'office_count':len(profile['offices']),'must_change_password':True,'operations_gated_until_change':True})
  (FOLDER/'handoff-status.json').write_text(json.dumps({'stage':'in-progress','completed':report},indent=2),encoding='utf-8');print('PASS fresh temporary password and change-required gate: '+name,flush=True)
 (FOLDER/'handoff-status.json').write_text(json.dumps({'stage':'complete','completed':report},indent=2),encoding='utf-8')
 print('PASS tester handoff; only DPAPI-protected temporary passwords retained; former sessions revoked by normal reset.')
if __name__=='__main__':
 try:main()
 except Exception as e:print(str(e),file=sys.stderr);sys.exit(1)
