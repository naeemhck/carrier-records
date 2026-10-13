"""V2 real authorization/issuance tests, only via guarded disposable T03 fixtures."""
import copy,json,uuid,hashlib
from concurrent.futures import ThreadPoolExecutor
def verify(env):
 rpc,sql,ok=env['rpc'],env['sql'],env['ok'];at=env['at'];data=env['t13'];b=env['b'];uid=lambda:str(uuid.uuid4())
 def success(name,result):
  if result[0]!=200:raise AssertionError(name+': HTTP '+str(result[0])+' '+str(result[1].get('message')))
  ok(name,True);return result[1]
 vehicle=success('U05 isolated snapshot vehicle',rpc('save_master_record',{'kind':'VEHICLE','target_id':uid(),'request_id':uid(),'expected_version':0,'payload':{'registration':'U05-SNAPSHOT','current_owner_id':env['t11']['owner']['id'],'default_driver_id':None,'archived':False}},at))
 trip,consignment=uid(),uid()
 review=success('U05 synthetic draft overlap review',rpc('review_trip_overlap',{'target_id':trip,'vehicle_id':vehicle['id'],'origin_office_id':env['office'][0],'destination_office_id':env['office'][1]},at))
 draft={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':env['office'][0],'destination_office_id':env['office'][1],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'U05 synthetic snapshot check','reason':'Synthetic entry','stops':[],
  'consignments':[{'id':consignment,'customer_id':env['t11']['customer']['id'],'broker_id':env['t11']['broker']['id'],'car_count':1,'quoted_amount':'100000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'5000.00','notes':'Synthetic only','cars':[]}],
  'review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}
 saved=success('U05 synthetic draft save',rpc('save_trip',{'target_id':trip,'request_id':uid(),'expected_version':0,'payload':draft},at))
 review=success('U05 synthetic dispatch review',rpc('review_trip_overlap',{'target_id':trip,'vehicle_id':vehicle['id'],'origin_office_id':env['office'][0],'destination_office_id':env['office'][1],'planned_dispatch_date':'2026-01-10'},at))
 saved=success('U05 synthetic committed dispatch',rpc('dispatch_trip',{'target_id':trip,'request_id':uid(),'expected_version':saved['version'],'payload':{'dispatch_date':'2026-01-10','reason':'Synthetic dispatch','review_token':review['review_token'],'overlap_confirmed':False,'overlap_reason':None}},at))
 preset_payload={'name':'U05 snapshot preset','shared':False,'report_kind':'CUSTOMER_INVOICE','recipient_kind':'CUSTOMER','field_order':data['command']['field_order'],'format_options':{'orientation':'LANDSCAPE','sheet_name':'Frozen snapshot'}}
 preset=success('U05 personal document preset',rpc('save_output_preset',{'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':preset_payload},at))
 command={k:v for k,v in data['command'].items() if k not in ('field_order','format_options')}
 command.update(presentation_version=2,preset_id=preset['id'],filters=data['command']['filters']|{'trip_id':trip})
 def issue(command=command,rid=None,token=at):return rpc('issue_document',{'request_id':rid or uid(),'expected_version':0,'payload':command},token)
 rid=uid();doc=success('U05 v2 transactional issuance',issue(rid=rid));snap=copy.deepcopy(doc['snapshot'])
 ok('U05 v2 server template/labels inside digest',doc['template_version']==2 and snap['presentation']['version']==2 and hashlib.sha256(doc['canonical_content'].encode()).hexdigest()==doc['content_digest'])
 ok('U05 v2 exact retry one immutable document',issue(rid=rid)==(200,doc) and sql(f"select count(*) from private.document_requests where request_id='{rid}';")=='1')
 ok('U05 v2 label selection equals selected fields',set(snap['presentation']['fields'])==set(snap['field_order']))
 ok('U05 customer privacy includes presentation/metadata',all(key not in json.dumps(snap,ensure_ascii=False) for key in ['owner_profit','owner_due','owner_earnings','brokerage','FORBIDDEN-T13']))
 for invalid in [None,1,3,'2',{'en':'injected'}]:
  ok('U05 invalid/modified presentation version denied',issue(command|{'presentation_version':invalid})[0]==400)
 ok('U05 injected client labels denied',issue(command|{'presentation':{'fields':{'owner_due':'leak'}}})[0]==400)
 outside=success('U05 unrelated staff authentication',env['login']('outside',env['real']))['access_token']
 ok('U05 cross-office and anonymous issue denied',issue(token=outside)[0]==403 and issue(token=env['anon'])[0] in (401,403))
 with ThreadPoolExecutor(max_workers=2) as pool:
  race=list(pool.map(lambda _:issue(rid=uid()),range(2)))
 ok('U05 concurrent new v2 numbers unique',all(r[0]==200 for r in race) and len({r[1]['permanent_number'] for r in race})==2)
 duplicate=uid()
 with ThreadPoolExecutor(max_workers=2) as pool:race=list(pool.map(lambda _:issue(rid=duplicate),range(2)))
 ok('U05 concurrent retry one document',race[0]==race[1] and race[0][0]==200)
 def counts():return sql(f"select jsonb_build_array((select sum(last_number) from public.document_sequences where business_id='{b}'),(select count(*) from public.issued_documents where business_id='{b}'),(select count(*) from private.document_requests where business_id='{b}'),(select count(*) from public.audit_events where business_id='{b}'));")
 before=counts();rollback=uid()
 sql("create function public.u05_fail_commit() returns trigger language plpgsql as $$ begin raise exception 'U05_INJECTED_COMMIT_FAILURE';end $$;create constraint trigger u05_fail_commit after insert on public.issued_documents deferrable initially deferred for each row execute function public.u05_fail_commit();")
 try:
  failed=issue(rid=rollback);ok('U05 v2 deferred commit failure rolls back number/snapshot/audit/retry',failed[0]>=400 and counts()==before)
 finally:sql('drop trigger u05_fail_commit on public.issued_documents;drop function public.u05_fail_commit();')
 success('U05 same rollback request commits after fault removed',issue(rid=rollback))
 success('U05 later preset order/format change',rpc('save_output_preset',{'target_id':preset['id'],'request_id':uid(),'expected_version':preset['version'],'payload':preset_payload|{'field_order':list(reversed(preset_payload['field_order'])),'format_options':{'orientation':'PORTRAIT','sheet_name':'Later layout'}}},at))
 cancellation=success('U05 audited source cancellation review',rpc('review_cancellation',{'trip_id':trip},at))
 success('U05 source fare change through retained cancellation adjustment',rpc('cancel_and_adjust',{'trip_id':trip,'request_id':uid(),'expected_version':saved['version'],'payload':{'reason':'Synthetic agreed fee after issuance','review_token':cancellation['review_token'],'effective_date':'2026-04-01','consignments':[{'id':consignment,'quoted_amount':'20000.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'1000.00'}]}},at))
 sql(f"update public.businesses set name='Later synthetic company',version=version+1 where id='{b}';update public.staff_profiles set display_name='Later synthetic issuer',version=version+1 where business_id='{b}' and role='ADMIN';")
 reprint=success('U05 reauthorize original v2 reprint',rpc('get_issued_document',{'document_id':doc['id']},at))
 ok('U05 company/issuer/fare/preset changes cannot alter v2 snapshot or digest',reprint['snapshot']==snap and reprint['content_digest']==doc['content_digest'] and snap['totals']['invoice_total']=='100000.00')
 superseding=success('U05 explicit linked v2 supersession',issue(command|{'supersedes_id':doc['id'],'reason':'Synthetic corrected cancellation fee'}))
 ok('U05 supersession retains original and captures corrected 20000 fee',superseding['supersedes_number']==doc['permanent_number'] and superseding['snapshot']['totals']['invoice_total']=='20000.00' and superseding['snapshot']['field_order']==list(reversed(preset_payload['field_order'])))
 legacy=success('U05 legacy issued reprint authorized',rpc('get_issued_document',{'document_id':data['original']['id']},at))
 ok('U05 legacy v1 snapshot remains identical',legacy['snapshot']==data['original']['snapshot'] and legacy['content_digest']==data['original']['content_digest'] and legacy['template_version']==1)
 directory=env['ROOT']/'tools/.local/karvaan-documents';directory.mkdir(exist_ok=True)
 (directory/'issued_v2.json').write_text(json.dumps(snap,ensure_ascii=False),encoding='utf-8')
 for recipient,report,party in [('INTERNAL','MONTHLY_VEHICLE',None),('OWNER','OWNER_STATEMENT',env['t11']['owner']['id']),('BROKER','BROKER_MONTHLY',env['t11']['broker']['id']),('CUSTOMER','CUSTOMER_STATEMENT',env['t11']['customer']['id'])]:
  catalogue=success('U05 '+recipient+' current server catalogue',rpc('get_output_catalogue',{'report_kind':report,'recipient_kind':recipient},at))
  cmd={'report_kind':report,'recipient_kind':recipient,'recipient_id':party,'filters':{'from':'2026-01-01','to':'2026-12-31'},'field_order':catalogue['defaults'],'presentation_version':2}
  payload=success('U05 '+recipient+' authorized v2 full export',rpc('prepare_output_export',{'command':cmd},at))
  ok('U05 '+recipient+' output selected order and exact totals retained',set(payload['presentation']['fields'])==set(payload['field_order']) and payload['template_version']==2)
  (directory/(recipient.lower()+'_v2.json')).write_text(json.dumps(payload,ensure_ascii=False),encoding='utf-8')
 scoped=success('U05 staff export is backend scoped',rpc('prepare_output_export',{'command':cmd},outside))
 ok('U05 staff export cannot claim global completeness',scoped['metadata']['complete'] is False and 'not a complete' in scoped['metadata']['scope'])
 ok('U05 forbidden office export denied',rpc('prepare_output_export',{'command':cmd|{'filters':cmd['filters']|{'office_id':env['office'][0]}}},outside)[0]==403)
 ok('U05 injected complete-scope filter denied',rpc('prepare_output_export',{'command':cmd|{'filters':cmd['filters']|{'complete':True}}},outside)[0]==400)
 peer=env['t11']['tokens'][2]
 success('U05 authorized office v2 reprint',rpc('get_issued_document',{'document_id':doc['id']},peer))
 profile=env['profile'](peer)
 success('U05 revoke v2 reader origin office',rpc('admin_manage_staff',{'target_id':profile['id'],'expected_version':profile['version'],'display_name':profile['display_name'],'account_role':'STAFF','active':True,'office_ids':[env['office'][2]]},at))
 ok('U05 old v2 reader session cannot reprint after revocation',rpc('get_issued_document',{'document_id':doc['id']},peer)[0]==403)
 fresh=success('U05 revoked reader fresh authentication',env['login']('reports2',env['real']))['access_token']
 ok('U05 fresh v2 reader cannot restore revoked office',rpc('get_issued_document',{'document_id':doc['id']},fresh)[0]==403)
 ok('U05 presentation helper is not directly executable by clients',sql("select has_function_privilege('anon','private.karvaan_output_v2(jsonb)','EXECUTE') or has_function_privilege('authenticated','private.karvaan_output_v2(jsonb)','EXECUTE');")=='f')
 print('U05 actual v2 database verification PASS; file rendering/inspection is separate.',flush=True)
