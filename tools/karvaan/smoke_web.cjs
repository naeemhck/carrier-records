const fs=require('fs'),path=require('path'),crypto=require('crypto');
const version=process.argv[2],performanceMode=process.argv.includes('--performance'),writeMode=process.argv.includes('--write-smoke'),traceMode=process.argv.includes('--trace-rendering');if(!/^0\.2\.0\+\d+$/.test(version||''))throw Error('Explicit local candidate version required');
const portIndex=process.argv.indexOf('--port'),port=portIndex<0?'8767':process.argv[portIndex+1];if(!['8767','8768','8769','8771'].includes(port))throw Error('Pinned local artifact port required');const base='http://127.0.0.1:'+port;
const accountIndex=process.argv.indexOf('--account'),selectedAccount=accountIndex<0?null:process.argv[accountIndex+1];if(selectedAccount&&(!['review_admin','review_khi','review_isb'].includes(selectedAccount)||performanceMode))throw Error('Only independent synthetic role checks may select an account; five-user workload unchanged');
const {chromium}=require('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const root=process.cwd(),auth=JSON.parse(fs.readFileSync('tools/.local/karvaan-review-auth.json','utf8'));
 const artifact=path.join(root,'tools/.local/candidates',version),outputIndex=process.argv.indexOf('--output');if(traceMode&&outputIndex<0)throw Error('Diagnostic output must be outside preserved candidate');const out=outputIndex>=0?path.resolve(root,process.argv[outputIndex+1]):path.join(artifact,'review-pack');if(!out.startsWith(path.join(root,'tools/.local')+path.sep)||(outputIndex>=0&&out.startsWith(path.join(root,'tools/.local/candidates')+path.sep)))throw Error('Only separate ignored diagnostic output allowed');fs.mkdirSync(out,{recursive:true});
 const manifest=JSON.parse(fs.readFileSync(path.join(artifact,'manifest.json')));const main=manifest.files.find(x=>x.path==='web/main.dart.js');if(!main||crypto.createHash('sha256').update(fs.readFileSync(path.join(artifact,main.path))).digest('hex')!==main.sha256)throw Error('Candidate source manifest mismatch');
 const served=Buffer.from(await(await fetch(base+'/main.dart.js')).arrayBuffer());if(crypto.createHash('sha256').update(served).digest('hex')!==main.sha256)throw Error('Served artifact differs from candidate manifest');
 if(performanceMode)auth.usernames=JSON.parse(fs.readFileSync('tools/.local/karvaan-performance-auth.json','utf8'));
 const accounts=performanceMode?Object.keys(auth.usernames):(selectedAccount?[selectedAccount]:writeMode?['review_admin']:(traceMode?['review_khi']:['review_admin','review_khi','review_isb']));if(performanceMode&&accounts.length!==5)throw Error('Five users required');
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,chromiumSandbox:true});
 const results=[],errors=[],blocked=[];let intentionalFault=false,warmed=0,releaseWarm;const warmBarrier=new Promise(resolve=>releaseWarm=resolve);let startup=Promise.resolve();
 try {
 async function verifyAccount(username){
  let releaseStartup;const prior=startup;if(performanceMode){startup=new Promise(resolve=>releaseStartup=resolve);await prior;}
  const context=await browser.newContext({viewport:{width:1280,height:900},acceptDownloads:true});
  await context.route('**/*',async route=>{
   const u=new URL(route.request().url());
   if(['data:','blob:'].includes(u.protocol)||(['127.0.0.1','localhost'].includes(u.hostname)&&[port,'60321'].includes(u.port)))await route.continue();
   else {blocked.push(u.hostname);await route.abort();}
  });
  const page=await context.newPage();
  await page.addInitScript(()=>{const parse=JSON.parse;window.__karvaanQaParse=[];JSON.parse=function(...args){const start=performance.now(),result=parse.apply(this,args),end=performance.now();if(result&&result.kind==='MONTHLY_VEHICLE'&&result.generated_at)window.__karvaanQaParse.push({stamp:result.generated_at,duration_ms:end-start,finished_ms:end});return result;};});
  const cdp=await context.newCDPSession(page);await cdp.send('Network.enable');await cdp.send('Performance.enable');const transferMap=new Map();let latestTransfer=null;
  cdp.on('Network.responseReceived',e=>{if(new URL(e.response.url).pathname==='/rest/v1/rpc/get_scoped_report'&&e.response.timing)transferMap.set(e.requestId,{request_time:e.response.timing.requestTime,headers_end_ms:e.response.timing.receiveHeadersEnd,send_end_ms:e.response.timing.sendEnd});});
  cdp.on('Network.loadingFinished',e=>{if(transferMap.has(e.requestId)){const t=transferMap.get(e.requestId);latestTransfer={...t,body_end_time:e.timestamp,body_transfer_ms:(e.timestamp-t.request_time)*1000-t.headers_end_ms};}});
  const requests=[];page.on('requestfailed',request=>{if(request.url().includes(':60321/'))requests.push({stage:'request_failed',path:new URL(request.url()).pathname,error:request.failure()?.errorText});}); page.on('request',request=>{if(new URL(request.url()).pathname==='/rest/v1/rpc/get_scoped_report')requests.push({stage:'report_request',filters:request.postDataJSON().filters,at_ms:performance.now()});if(request.url().includes('/auth/v1/token')){let body=request.postDataJSON();requests.push({stage:'login_request',password_matches:body.password===auth.usernames[username],email_is_synthetic:body.email.startsWith(username+'.')&&body.email.endsWith('@staff.invalid')});}}); page.on('response',response=>{if(response.url().includes(':60321/'))requests.push({path:new URL(response.url()).pathname,status:response.status()});});
  page.on('pageerror',e=>errors.push(e.name));
  page.on('console',m=>{if(m.type()==='error'&&!intentionalFault)errors.push(m.text().replace(/eyJ[A-Za-z0-9_.-]+/g,'[withheld]'));});
  await page.goto(base,{waitUntil:'networkidle'});
  await page.waitForFunction(()=>document.querySelector('flt-semantics-placeholder')||document.querySelector('input')||document.querySelector('[role=textbox]'),null,{timeout:120000});
  if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
  await page.getByRole('textbox').first().waitFor({timeout:120000});
  await page.getByRole('textbox').nth(0).click(); await page.keyboard.type(username);
  await page.getByRole('textbox').nth(1).click(); await page.keyboard.type(auth.usernames[username]);
  await page.getByRole('button',{name:/^Sign in/}).click();
  try { await page.getByRole('button',{name:username==='review_admin'? /Company and master records/ : /^Trips/}).waitFor({timeout:30000}); } catch(error){const labels=await page.locator('[aria-label]').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')));await page.screenshot({path:path.join(out,'web-login-diagnostic.png'),fullPage:true});console.log(JSON.stringify({account:username,requests,labels}));throw error;}
  const text=await page.evaluate(()=>document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')).join(' '));
  if(!text.includes('\u06a9\u0627\u0631\u0648\u0627\u06ba'))throw Error('Urdu brand absent');
  const admin=await page.getByRole('button',{name:/Company and master records/}).count();
  if(Boolean(admin)!==(username==='review_admin'))throw Error('Administrator navigation scope failed');
  if(username==='review_khi'&&(!text.includes('Karachi')||text.includes('Islamabad')))throw Error('Karachi scope failed');
  if(username==='review_isb'&&(!text.includes('Islamabad')||text.includes('Karachi')))throw Error('Islamabad scope failed');
  await page.screenshot({path:path.join(out,username+'-dashboard.png'),fullPage:true});
  await page.setViewportSize({width:320,height:800});await page.screenshot({path:path.join(out,username+'-narrow.png'),fullPage:true});
  results.push({account:username,login:true,role_scope:true,bilingual_brand:true,narrow_capture:true,buttons:await page.getByRole('button').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')||el.innerText))});
  if(writeMode){
   await page.setViewportSize({width:1280,height:900});await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
   await page.getByRole('button',{name:/Company and master records/}).click();
   await page.waitForFunction(()=>document.body.textContent.includes('Company and master records'));await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
   console.log(JSON.stringify({stage:'master_controls',controls:await page.locator('[role]').evaluateAll(els=>els.map(el=>({role:el.getAttribute('role'),label:el.getAttribute('aria-label'),text:el.innerText})).filter(x=>x.role==='button'||x.role==='checkbox'||x.role==='radio'))}));
   await page.screenshot({path:path.join(out,'admin-master-controls.png')});
   await page.getByRole('checkbox',{name:/^Expense categories/}).click();await page.getByRole('button',{name:/^New record/}).click();
   const name='SYNTHETIC QA '+version+' retry '+Date.now();const field=page.getByRole('textbox',{name:/^Name/});await field.click();await page.keyboard.type(name);
   let failedBody;intentionalFault=true;await page.route('**/rest/v1/rpc/save_master_record',async route=>{failedBody=route.request().postDataJSON();await route.abort('connectionfailed');});
   await page.getByRole('button',{name:/^Save\./}).click();await page.waitForFunction(()=>document.body.textContent.includes('Save failed. Your entries are retained'));
   if(await field.inputValue()!==name)throw Error('Failed save lost input');if((await page.evaluate(()=>document.body.textContent)).includes('Saved by the server'))throw Error('False save confirmation');
   await page.screenshot({path:path.join(out,'master-save-connection-failure.png')});await page.unroute('**/rest/v1/rpc/save_master_record');
   const committedPromise=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/save_master_record');await page.getByRole('button',{name:/^Save\./}).click();const committed=await committedPromise;if(committed.status()!==200)throw Error('Save recovery rejected');const committedBody=committed.request().postDataJSON(),record=await committed.json();if(!failedBody||committedBody.request_id!==failedBody.request_id||committedBody.target_id!==failedBody.target_id)throw Error('Retry identity changed');
   await page.waitForFunction(()=>document.body.textContent.includes('Saved by the server'));intentionalFault=false;await page.screenshot({path:path.join(out,'master-save-recovered.png')});
   const safe=await page.evaluate(async ({name,record,authorization,apiKey})=>{
    const rpc=async(kind,body)=>{const response=await fetch('http://127.0.0.1:60321/rest/v1/rpc/'+kind,{method:'POST',headers:{'Content-Type':'application/json',Authorization:authorization,apikey:apiKey},body:JSON.stringify(body)});if(!response.ok)throw Error('Synthetic verification RPC rejected');return await response.json();};
    const list=await rpc('list_master_records',{kind:'CATEGORY',search_text:name,page_offset:0,include_archived:true});if(list.filter(x=>x.name===name).length!==1)throw Error('Duplicate synthetic category');
    const archived=await rpc('save_master_record',{kind:'CATEGORY',target_id:record.id,request_id:crypto.randomUUID(),expected_version:record.version,payload:{name,archived:true}});if(!archived.archived_at)throw Error('Audited archive not confirmed');return {exactly_one_record:true,archived_with_normal_versioned_command:true};
   },{name,record,authorization:committed.request().headers().authorization,apiKey:committed.request().headers().apikey});
   results.push({account:username,write_fault:'request aborted before backend commit',failure_visible:true,entries_retained:true,no_false_confirmation:true,same_retry_identity:true,confirmed_commit:true,...safe});

  }
  if(username==='review_khi'||performanceMode){
   await page.setViewportSize({width:1280,height:900});await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
   console.log(JSON.stringify({account:username,stage:'open_reports'}));
   const firstReport=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/get_scoped_report');await page.getByRole('button',{name:/^Reports\./}).click();let initial;try{initial=await firstReport;}catch(error){console.log(JSON.stringify({account:username,stage:'initial_report_timeout',requests,labels:await page.locator('[aria-label]').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')))}));await page.screenshot({path:path.join(out,username+'-initial-report-timeout.png')});throw error;}if(initial.status()!==200){let failure;try{failure=await initial.json();}catch{}const evidence={version,source_commit:manifest.source_commit,account:username,stage:'initial_report',status:initial.status(),error_code:failure?.code||null,completed_results:results,requests,console_errors:errors,blocked_nonlocal_requests:blocked};fs.writeFileSync(path.join(out,'failure.json'),JSON.stringify(evidence,null,2));throw Error('Initial report failed HTTP '+initial.status()+' code '+(failure?.code||'unavailable'));}await initial.body();
   await page.getByRole('button',{name:/^Run report/}).waitFor();
   for(const [label,value] of [[/^From /,'2026-12-01'],[/^To /,'2026-12-31'],[/^Trip \/ vehicle search/,'BENCH']]){
    const field=page.getByRole('textbox',{name:label});await field.click();await page.keyboard.press('Control+A');await page.keyboard.type(value);
   }
   if(performanceMode){
    console.log(JSON.stringify({account:username,stage:'warmup'}));
    const warmResponse=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/get_scoped_report'&&r.request().postDataJSON().filters.search==='BENCH');await page.getByRole('button',{name:/^Run report/}).click();const warm=await warmResponse;if(warm.status()!==200)throw Error('Warm-up failed');const value=await warm.json();if(value.totals.owner_earnings!=='95000000.00'||value.row_count!==20)throw Error('Warm-up exact totals failed');await page.waitForFunction(stamp=>(document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')||'').join(' ')).includes(stamp),value.generated_at);await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));console.log(JSON.stringify({account:username,stage:'warmup_ready'}));releaseStartup();warmed++;if(warmed===accounts.length)releaseWarm();await warmBarrier;
   }
   const rendering=[];
   for(let i=0;i<(performanceMode?10:5);i++){
    const responsePromise=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/get_scoped_report'&&r.request().postDataJSON().filters.search==='BENCH');
    if(traceMode)await cdp.send('Tracing.start',{categories:'devtools.timeline,disabled-by-default-devtools.timeline.frame',transferMode:'ReturnAsStream'});const started=performance.now();console.log(JSON.stringify({account:username,stage:'measured_click',sample:i}));await page.getByRole('button',{name:/^Run report/}).click();let response;try{response=await responsePromise;}catch(error){console.log(JSON.stringify({account:username,stage:'measured_response_timeout',sample:i,requests,labels:await page.locator('[aria-label]').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')))}));await page.screenshot({path:path.join(out,username+'-measured-timeout.png')});fs.writeFileSync(path.join(out,username+'-partial-performance.json'),JSON.stringify({account:username,samples:rendering,failed_sample:i},null,2));throw error;}const headerAt=performance.now();const raw=await response.body();const bodyAt=performance.now();const accepted=JSON.parse(raw.toString('utf8'));if(response.status()!==200)throw Error('Candidate report request failed');
    if(accepted.totals.owner_earnings!=='95000000.00'||accepted.row_count!==20)throw Error('Server benchmark payload mismatch');
    try {await page.waitForFunction(stamp=>{const text=document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')||'').join(' ');return text.includes('95000000.00')&&text.includes(stamp);},accepted.generated_at,{timeout:30000});}
    catch(error){const labels=await page.locator('[aria-label]').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')));const text=await page.evaluate(()=>document.body.textContent);fs.writeFileSync(path.join(out,'report-readiness-diagnostic.json'),JSON.stringify({period:accepted.period,expected_earnings:accepted.totals.owner_earnings,stamp:accepted.generated_at,labels,text},null,2));await page.screenshot({path:path.join(out,'report-readiness-diagnostic.png'),fullPage:true});throw error;}

    await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));const ready=performance.now();
    const client=await page.evaluate(stamp=>({parse:window.__karvaanQaParse.find(x=>x.stamp===stamp)||null,ready_ms:performance.now()}),accepted.generated_at);const metrics=await cdp.send('Performance.getMetrics');const navigationStart=metrics.metrics.find(m=>m.name==='NavigationStart')?.value;const network=latestTransfer?{headers_wait_ms:latestTransfer.headers_end_ms-latestTransfer.send_end_ms,body_transfer_ms:latestTransfer.body_transfer_ms,network_total_ms:(latestTransfer.body_end_time-latestTransfer.request_time)*1000}:null;const processingAndRendering=navigationStart&&latestTransfer?client.ready_ms-(latestTransfer.body_end_time-navigationStart)*1000:null;
    let traceSummary=null;if(traceMode){const complete=new Promise(resolve=>cdp.once('Tracing.tracingComplete',resolve));await cdp.send('Tracing.end');const completed=await complete;let chunks='',eof=false;while(!eof){const chunk=await cdp.send('IO.read',{handle:completed.stream});chunks+=chunk.base64Encoded?Buffer.from(chunk.data,'base64').toString('utf8'):chunk.data;eof=chunk.eof;}await cdp.send('IO.close',{handle:completed.stream});const trace=JSON.parse(chunks),endTime=metrics.metrics.find(m=>m.name==='Timestamp')?.value;const startUs=latestTransfer?.body_end_time*1e6,endUs=endTime*1e6;const names=new Set(['FunctionCall','EvaluateScript','RunMicrotasks','Layout','UpdateLayoutTree','PrePaint','Paint','Layerize','Commit','RasterTask','CompositeLayers','DrawFrame']);const totals={};for(const event of trace.traceEvents){if(event.ph==='X'&&event.ts>=startUs&&event.ts<=endUs&&names.has(event.name)){const row=totals[event.name]??={count:0,total_ms:0,max_ms:0};row.count++;row.total_ms+=event.dur/1000;row.max_ms=Math.max(row.max_ms,event.dur/1000);}}traceSummary={post_body_interval_ms:(endUs-startUs)/1000,events:totals,limit:'Per-event script and browser layout/paint durations may nest or overlap; do not add them or equate the interval to pure GPU rendering. No raw trace arguments retained.'};}
    console.log(JSON.stringify({account:username,stage:'measured_ready',sample:i,total_readiness_ms:ready-started}));rendering.push({trace:traceSummary,browser_network:network,browser_json_parse_ms:client.parse?.duration_ms??null,body_received_to_ui_ready_ms:processingAndRendering,post_parse_to_ui_ready_ms:client.parse?client.ready_ms-client.parse.finished_ms:null,request_to_headers_ms:headerAt-started,headers_to_body_available_ms:bodyAt-headerAt,body_available_to_semantics_and_two_frames_ms:ready-bodyAt,total_readiness_ms:ready-started});
   }
   await page.screenshot({path:path.join(out,username+'-december-report.png'),fullPage:true});
   let aborted=0;if(!performanceMode){intentionalFault=true;
   await page.route('**/rest/v1/rpc/get_scoped_report',async route=>{aborted++;await route.abort('connectionfailed');});
   await page.getByRole('button',{name:/^Run report/}).click();await page.waitForFunction(()=>(document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')||'').join(' ')).includes('Report unavailable'),{timeout:30000});
   await page.screenshot({path:path.join(out,'report-connection-failure.png'),fullPage:true});await page.unroute('**/rest/v1/rpc/get_scoped_report');
   const recovered=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/get_scoped_report');await page.getByRole('button',{name:/^Run report/}).click();if((await recovered).status()!==200)throw Error('Report did not recover');
   await page.waitForFunction(()=>(document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')||'').join(' ')).includes('95000000.00'),{timeout:30000});intentionalFault=false;}
   results.push({account:username,report_exact_earnings:true,rendering_samples:rendering,rendering_limit:'Real release-browser readiness samples; includes driver polling and two animation frames; body-to-readiness includes Flutter processing/semantics/rendering and is not isolated GPU or SDK JSON parsing',read_failure_and_recovery:performanceMode?'not run in performance mode':aborted>0,write_failure:'Not verified by this read-only report check'});
  }
  await context.close();
 }
 if(performanceMode)await Promise.all(accounts.map(verifyAccount));else for(const username of accounts)await verifyAccount(username);
 }finally{await browser.close();}
 const report={version,concurrent_users:performanceMode?5:1,cache_conditions:performanceMode?'Fresh isolated browser contexts initialized sequentially before concurrent measured work (simultaneous font/WASM bootstrap attempt timed out); initial report completion and one December warm-up per user before a five-user barrier; 10 measured requests per user; no build/audit runs concurrently':'Fresh browser contexts; basic smoke, not a controlled performance benchmark',source_commit:manifest.source_commit,results,console_errors:errors,blocked_nonlocal_requests:blocked};
 fs.writeFileSync(path.join(out,performanceMode?'web-performance.json':(writeMode?'web-write-smoke.json':'web-smoke.json')),JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
 if(errors.length||blocked.length)process.exitCode=1;
})().catch(e=>{let message=e.name+': '+e.message; const secrets=Object.values(JSON.parse(fs.readFileSync('tools/.local/karvaan-review-auth.json','utf8')).usernames);if(fs.existsSync('tools/.local/karvaan-performance-auth.json'))secrets.push(...Object.values(JSON.parse(fs.readFileSync('tools/.local/karvaan-performance-auth.json','utf8')))); secrets.push(JSON.parse(fs.readFileSync('tools/.local/karvaan-test-defines.json','utf8')).SUPABASE_PUBLISHABLE_KEY); for(const value of secrets)message=message.split(value).join('[withheld]'); console.error(message);process.exitCode=1;});
