const fs=require('fs'),path=require('path'),crypto=require('crypto');
const version=process.argv[2];if(!/^0\.2\.0\+\d+$/.test(version||''))throw Error('Explicit local candidate version required');
const {chromium}=require('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
(async()=>{
 const root=process.cwd(),auth=JSON.parse(fs.readFileSync('tools/.local/karvaan-review-auth.json','utf8'));
 const artifact=path.join(root,'tools/.local/candidates',version),out=path.join(artifact,'review-pack');fs.mkdirSync(out,{recursive:true});
 const manifest=JSON.parse(fs.readFileSync(path.join(artifact,'manifest.json')));const main=manifest.files.find(x=>x.path==='web/main.dart.js');if(!main||crypto.createHash('sha256').update(fs.readFileSync(path.join(artifact,main.path))).digest('hex')!==main.sha256)throw Error('Candidate source manifest mismatch');
 const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,chromiumSandbox:true});
 const results=[],errors=[],blocked=[];let intentionalFault=false;
 try {
 for(const username of ['review_admin','review_khi','review_isb']){
  const context=await browser.newContext({viewport:{width:1280,height:900},acceptDownloads:true});
  await context.route('**/*',async route=>{
   const u=new URL(route.request().url());
   if(['data:','blob:'].includes(u.protocol)||(['127.0.0.1','localhost'].includes(u.hostname)&&['8767','60321'].includes(u.port)))await route.continue();
   else {blocked.push(u.hostname);await route.abort();}
  });
  const page=await context.newPage(); const requests=[]; page.on('request',request=>{if(request.url().includes('/auth/v1/token')){let body=request.postDataJSON();requests.push({stage:'login_request',password_matches:body.password===auth.usernames[username],email_is_synthetic:body.email.startsWith(username+'.')&&body.email.endsWith('@staff.invalid')});}}); page.on('response',response=>{if(response.url().includes(':60321/'))requests.push({path:new URL(response.url()).pathname,status:response.status()});});
  page.on('pageerror',e=>errors.push(e.name));
  page.on('console',m=>{if(m.type()==='error'&&!intentionalFault)errors.push(m.text().replace(/eyJ[A-Za-z0-9_.-]+/g,'[withheld]'));});
  await page.goto('http://127.0.0.1:8767',{waitUntil:'networkidle'});
  await page.locator('flt-semantics-placeholder').waitFor({timeout:60000});
  await page.locator('flt-semantics-placeholder').evaluate(el=>el.click());
  await page.getByRole('textbox').first().waitFor();
  await page.getByRole('textbox').nth(0).click(); await page.keyboard.type(username);
  await page.getByRole('textbox').nth(1).click(); await page.keyboard.type(auth.usernames[username]);
  await page.getByRole('button',{name:/^Sign in/}).click();
  try { await page.getByRole('button',{name:username==='review_admin'? /Company and master records/ : /^Trips/}).waitFor({timeout:30000}); } catch(error){const labels=await page.locator('[aria-label]').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')));await page.screenshot({path:path.join(out,'web-login-diagnostic.png'),fullPage:true});console.log(JSON.stringify({account:username,requests,labels}));throw error;}
  const text=await page.evaluate(()=>document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')).join(' '));
  if(!text.includes('ÃšÂ©Ã˜Â§Ã˜Â±Ã™Ë†Ã˜Â§ÃšÂº'))throw Error('Urdu brand absent');
  const admin=await page.getByRole('button',{name:/Company and master records/}).count();
  if(Boolean(admin)!==(username==='review_admin'))throw Error('Administrator navigation scope failed');
  if(username==='review_khi'&&(!text.includes('Karachi')||text.includes('Islamabad')))throw Error('Karachi scope failed');
  if(username==='review_isb'&&(!text.includes('Islamabad')||text.includes('Karachi')))throw Error('Islamabad scope failed');
  await page.screenshot({path:path.join(out,username+'-dashboard.png'),fullPage:true});
  await page.setViewportSize({width:320,height:800});await page.screenshot({path:path.join(out,username+'-narrow.png'),fullPage:true});
  results.push({account:username,login:true,role_scope:true,bilingual_brand:true,narrow_capture:true,buttons:await page.getByRole('button').evaluateAll(elements=>elements.map(el=>el.getAttribute('aria-label')||el.innerText))});
  if(username==='review_khi'){
   await page.setViewportSize({width:1280,height:900});
   await page.getByRole('button',{name:/^Reports\./}).click();
   await page.getByRole('button',{name:/^Run report/}).waitFor();
   for(const [label,value] of [[/^From /,'2026-12-01'],[/^To /,'2026-12-31'],[/^Trip \/ vehicle search/,'BENCH']]){
    const field=page.getByRole('textbox',{name:label});await field.click();await page.keyboard.press('Control+A');await page.keyboard.type(value);
   }
   const rendering=[];
   for(let i=0;i<5;i++){
    const responsePromise=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/get_scoped_report'&&r.request().postDataJSON().filters.search==='BENCH');
    const started=performance.now();await page.getByRole('button',{name:/^Run report/}).click();const response=await responsePromise;const headerAt=performance.now();const raw=await response.body();const bodyAt=performance.now();const accepted=JSON.parse(raw.toString('utf8'));if(response.status()!==200)throw Error('Candidate report request failed');
    await page.waitForFunction(stamp=>{const labels=Array.from(document.querySelectorAll('[aria-label]')).map(el=>el.getAttribute('aria-label')||'');return labels.some(x=>x.includes('95000000.00'))&&labels.some(x=>x.includes(stamp));},accepted.generated_at,{timeout:30000});
    await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));const ready=performance.now();
    rendering.push({request_to_headers_ms:headerAt-started,headers_to_body_available_ms:bodyAt-headerAt,body_available_to_semantics_and_two_frames_ms:ready-bodyAt,total_readiness_ms:ready-started});
   }
   await page.screenshot({path:path.join(out,'review_khi-december-report.png'),fullPage:true});
   intentionalFault=true;let aborted=0;
   await page.route('**/rest/v1/rpc/get_scoped_report',async route=>{aborted++;await route.abort('connectionfailed');});
   await page.getByRole('button',{name:/^Run report/}).click();await page.waitForFunction(()=>Array.from(document.querySelectorAll('[aria-label]')).some(el=>(el.getAttribute('aria-label')||'').includes('Report unavailable')),{timeout:30000});
   await page.screenshot({path:path.join(out,'report-connection-failure.png'),fullPage:true});await page.unroute('**/rest/v1/rpc/get_scoped_report');
   const recovered=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/get_scoped_report');await page.getByRole('button',{name:/^Run report/}).click();if((await recovered).status()!==200)throw Error('Report did not recover');
   await page.waitForFunction(()=>Array.from(document.querySelectorAll('[aria-label]')).some(el=>(el.getAttribute('aria-label')||'').includes('95000000.00')),{timeout:30000});intentionalFault=false;
   results.push({account:username,report_exact_earnings:true,rendering_samples:rendering,rendering_limit:'Five single-user real release-browser readiness samples, includes driver polling and two animation frames; not five-user GPU/frame benchmark or isolated Flutter JSON parsing',read_failure_and_recovery:aborted>0,write_failure:'Not verified by this read-only report check'});
  }
  await context.close();
 }
 }finally{await browser.close();}
 const report={version,source_commit:manifest.source_commit,results,console_errors:errors,blocked_nonlocal_requests:blocked};
 fs.writeFileSync(path.join(out,'web-smoke.json'),JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
 if(errors.length||blocked.length)process.exitCode=1;
})().catch(e=>{let message=e.name+': '+e.message; const secrets=Object.values(JSON.parse(fs.readFileSync('tools/.local/karvaan-review-auth.json','utf8')).usernames); secrets.push(JSON.parse(fs.readFileSync('tools/.local/karvaan-test-defines.json','utf8')).SUPABASE_PUBLISHABLE_KEY); for(const value of secrets)message=message.split(value).join('[withheld]'); console.error(message);process.exitCode=1;});
