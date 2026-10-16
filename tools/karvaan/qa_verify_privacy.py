"""Known-field and office-bypass checks on TEST output payloads, not client hiding."""
import json,sys,uuid
from qa_seed import Backend,unprotect
from qa_preview import FOLDER,require
b=Backend();c=unprotect(FOLDER/'tester-credentials.dpapi');s=json.loads((FOLDER/'seed-state.json').read_text());target=json.loads((FOLDER/'target.json').read_text());business=target['business_id'];tokens={u:b.login(u,v['password'],business) for u,v in c.items()};results=[]
def record(name,ok=True):require(ok,name);results.append({'check':name,'passed':True});print('PASS '+name)
kind='OWNER_STATEMENT'
owner=b.rpc('get_output_catalogue',{'report_kind':kind,'recipient_kind':'OWNER'},tokens['qa_admin']);internal=b.rpc('get_output_catalogue',{'report_kind':kind,'recipient_kind':'INTERNAL'},tokens['qa_admin'])
permitted=[x['field_key'] for x in owner['fields']];private=set(x['field_key'] for x in internal['fields'])-set(permitted)
command={'report_kind':kind,'recipient_kind':'OWNER','recipient_id':s['parties'][0]['id'],'filters':{'from':'2026-10-01','to':'2026-10-31'},'field_order':permitted,'format_options':{'orientation':'AUTO','sheet_name':'Synthetic owner'},'preset_id':None,'event_id':None,'page_offset':0}
payload=b.rpc('prepare_output',command,tokens['qa_admin']);raw=json.dumps(payload)
record('OWNER payload excludes known forbidden internal field keys',not any(('"'+key+'"') in raw for key in private))
require(private,'Expected known forbidden fields absent; do not claim modified-request test')
changed={**command,'field_order':permitted+[sorted(private)[0]]};denied=b.call('/rest/v1/rpc/prepare_output',changed,tokens['qa_admin'],expect=[403]);record('Known forbidden field added to OWNER API request denied',denied['code']=='42501')
changed={**command,'filters':{**command['filters'],'office_id':s['offices'][1]['id']}};denied=b.call('/rest/v1/rpc/prepare_output',changed,tokens['qa_khi'],expect=[403]);record('Staff altered export office filter denied',denied['code']=='42501')
for user in ['qa_khi','qa_isb']:
 denied=b.call('/rest/v1/financial_events',{'id':str(uuid.uuid4()),'kind':'CUSTOMER_RECEIPT'},tokens[user],expect=[403]);record(user+' direct financial insert denied',denied['code']=='42501')
denied=b.call('/auth/v1/signup',{'email':'synthetic-no-signup@example.invalid','password':'SyntheticNonSecretValidationOnly!'},expect=[400,422]);record('Public signup specifically disabled',denied['code']=='signup_disabled')
for token in tokens.values():b.call('/auth/v1/logout?scope=local',{},token)
(FOLDER/'privacy-verification.json').write_text(json.dumps({'checks':results,'permitted_owner_fields':permitted,'forbidden_internal_fields':sorted(private)},indent=2),encoding='utf-8')
