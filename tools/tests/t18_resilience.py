"""AT-33 real restricted RPCs through a loopback connection-fault proxy."""
import base64,copy,json,socket,threading,urllib.request,urllib.error,uuid
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from concurrent.futures import ThreadPoolExecutor

def verify(env):
    rpc,sql,ok=env['rpc'],env['sql'],env['ok'];uid=lambda:str(uuid.uuid4())
    at=env['login']('admin',env['real'])[1]['access_token'];office=env['office'];b=env['b']
    def good(name,result):
        ok(name,result[0]==200);return result[1]
    account=good('AT33 managed restricted fault-test staff',env['edge']({'action':'create','username':'resilience','display_name':'Synthetic network tests','role':'STAFF','office_ids':[office[0]],'password':env['password']},at))
    env['users'].append(sql(f"select auth_user_id from public.staff_profiles where id='{account['id']}';"))
    temp=good('AT33 temporary login',env['login']('resilience'));env['change'](temp['access_token'])
    token=good('AT33 fresh restricted login',env['login']('resilience',env['real']))['access_token']
    def master(kind,p):return good('AT33 synthetic '+kind,rpc('save_master_record',{'kind':kind,'target_id':uid(),'request_id':uid(),'expected_version':0,'payload':p},at))
    parties=[master('PARTY',{'code':'T18-'+n,'display_name':'Synthetic '+n,'roles':[r],'contact_details':{},'archived':False}) for n,r in [('owner','OWNER'),('customer','CUSTOMER'),('broker','BROKER')]]
    owner,customer,broker=parties
    vehicle=master('VEHICLE',{'registration':'T18-FAULT','current_owner_id':owner['id'],'default_driver_id':None,'archived':False})
    tid=uid();review=good('AT33 overlap review',rpc('review_trip_overlap',{'target_id':tid,'vehicle_id':vehicle['id'],'origin_office_id':office[0],'destination_office_id':office[1]},token))
    payload={'vehicle_id':vehicle['id'],'driver_id':None,'origin_office_id':office[0],'destination_office_id':office[1],'route_id':None,'load_kind':'LOADED','return_of_trip_id':None,'planned_dispatch_date':None,'notes':'Synthetic network faults','reason':'Synthetic entry','stops':[],
             'consignments':[{'id':uid(),'customer_id':customer['id'],'broker_id':broker['id'],'car_count':1,'quoted_amount':'100.00','quote_mode':'DEDUCTED','commission_method':'FIXED','commission_value':'5.00','notes':'','cars':[]}],
             'review_token':review['review_token'],'overlap_confirmed':review['requires_confirmation'],'overlap_reason':'Synthetic review' if review['requires_confirmation'] else None}
    good('AT33 operational draft',rpc('save_trip',{'target_id':tid,'request_id':uid(),'expected_version':0,'payload':payload},token))
    def command():return {'event_kind':'ADVANCE','request_id':uid(),'expected_version':0,'payload':{'payer_id':customer['id'],'payee_id':broker['id'],'office_id':office[0],'effective_date':'2026-03-05','amount':'1.00','reason':'Synthetic network fault','allocations':[{'trip_id':tid,'amount':'1.00'}]}}
    def count(args):return sql(f"select count(*) from public.financial_events where request_id='{args['request_id']}';")
    class FaultHandler(BaseHTTPRequestHandler):
        def log_message(self,*args):pass
        def do_POST(self):
            raw=self.rfile.read(int(self.headers['Content-Length']))
            with self.server.lock:
                mode=self.server.mode;self.server.mode='forward'
            if mode=='before':
                self.connection.shutdown(socket.SHUT_RDWR);self.connection.close();return
            req=urllib.request.Request(env['base']+'/rest/v1/rpc/post_financial_event',data=raw,headers={'apikey':env['anon'],'Authorization':self.headers['Authorization'],'Content-Type':'application/json'})
            try:
                with urllib.request.urlopen(req,timeout=30) as r:status=r.status;body=r.read()
            except urllib.error.HTTPError as e:status=e.code;body=e.read()
            if mode=='after':
                self.server.committed_status=status
                self.connection.shutdown(socket.SHUT_RDWR);self.connection.close();return
            self.send_response(status);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
    server=ThreadingHTTPServer(('127.0.0.1',0),FaultHandler);server.lock=threading.Lock();server.mode='forward'
    worker=threading.Thread(target=server.serve_forever,daemon=True);worker.start()
    def through(args,auth=None):
        auth=auth or token
        req=urllib.request.Request('http://127.0.0.1:'+str(server.server_port)+'/',data=json.dumps(args).encode(),headers={'Authorization':'Bearer '+auth,'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(req,timeout=35) as r:return r.status,json.loads(r.read())
        except urllib.error.HTTPError as e:return e.code,json.loads(e.read())
    try:
        for mode in ['before','after']:
            args=command();server.mode=mode
            try:through(args);ok('AT33 dropped connection has no success acknowledgement',False)
            except (OSError,ConnectionError,urllib.error.URLError):ok('AT33 dropped connection has no success acknowledgement',True)
            ok('AT33 '+mode+' fault has exact commit state',count(args)==('0' if mode=='before' else '1'))
            if mode=='after':ok('AT33 lost response followed real backend commit',server.committed_status==200)
            result=good('AT33 same-request retry succeeds',through(args))
            ok('AT33 duplicate retry returns same result exactly once',through(args)==(200,result) and count(args)=='1')
            bad=copy.deepcopy(args);bad['payload']['reason']='Changed after ambiguous response'
            ok('AT33 altered retry rejected',through(bad)[0]>=400 and count(args)=='1')
        args=command();results=list(ThreadPoolExecutor(max_workers=5).map(lambda _:rpc('post_financial_event',args,token),range(5)))
        ok('AT33 five concurrent identical retries commit once',all(r[0]==200 and r[1]==results[0][1] for r in results) and count(args)=='1')
        args=command();ok('AT33 malformed JWT cannot post through direct proxy',through(args,'invalid')[0]>=400 and count(args)=='0')
        claims=json.loads(base64.urlsafe_b64decode(token.split('.')[1]+'==='));sid=str(uuid.UUID(claims['session_id']))
        # Trusted fixture expires only this synthetic session, without changing
        # provider expiry settings or issuing forged authentication tokens.
        sql(f"update auth.sessions set not_after=now()-interval '1 second' where id='{sid}';")
        ok('AT33 actual expired session cannot acknowledge or post',through(args)[0]==403 and count(args)=='0')
        token=good('AT33 fresh authentication after session expiry',env['login']('resilience',env['real']))['access_token']
        live=env['profile'](token)
        good('AT33 revoke live staff assignment',rpc('admin_manage_staff',{'target_id':live['id'],'expected_version':live['version'],'display_name':live['display_name'],'account_role':'STAFF','active':True,'office_ids':[office[2]]},at))
        ok('AT33 obsolete office token cannot post',through(args)[0]==403 and count(args)=='0')
        ok('AT33 financial histories remain balanced',sql(f"select count(*) from (select e.id from public.financial_events e join public.journal_lines l on l.event_id=e.id where e.business_id='{b}' group by e.id having sum(l.signed_amount)<>0)x;")=='0')
    finally:
        server.shutdown();server.server_close();worker.join(timeout=5)
