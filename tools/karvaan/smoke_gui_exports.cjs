const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=process.cwd(),auth=JSON.parse(fs.readFileSync('tools/.local/karvaan-review-auth.json','utf8'));
const version=process.argv[2],port=process.argv[3],suffix=process.argv[4];if(!/^0\.2\.0\+\d+$/.test(version||'')||!['8767','8768','8769','8771'].includes(port)||!/^gui[0-9]+-[a-z0-9-]+$/.test(suffix||''))throw Error('Explicit candidate, pinned local port and new diagnostic folder required');
const output=path.join(root,'tools/.local',suffix);fs.mkdirSync(output,{recursive:false});
const base='http://127.0.0.1:'+port;
const manifest=JSON.parse(fs.readFileSync('tools/.local/candidates/'+version+'/manifest.json','utf8'));
const errors=[],blocked=[],writes=[];let browser;
const escaped=value=>value.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
(async()=>{
 const main=manifest.files.find(f=>f.path==='web/main.dart.js');
 if(crypto.createHash('sha256').update(Buffer.from(await(await fetch(base+'/main.dart.js')).arrayBuffer())).digest('hex')!==main.sha256)throw Error('Artifact hash mismatch');
 browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,chromiumSandbox:true});
 const context=await browser.newContext({viewport:{width:1280,height:1000},acceptDownloads:true});
 await context.route('**/*',async route=>{const u=new URL(route.request().url());if(['blob:','data:'].includes(u.protocol)||(['localhost','127.0.0.1'].includes(u.hostname)&&[port,'60321'].includes(u.port)))await route.continue();else{blocked.push(u.hostname);await route.abort();}});
 const page=await context.newPage();page.on('pageerror',e=>errors.push(e.name));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 page.on('request',request=>{const name=new URL(request.url()).pathname.split('/').pop();if(['save_trip','dispatch_trip','arrive_trip','correct_trip_operation','post_financial_event'].includes(name))writes.push(name);});
 const snapshot=async name=>{await page.screenshot({path:path.join(output,name+'.png'),fullPage:true});};
 const text=()=>page.evaluate(()=>document.body.textContent+' '+Array.from(document.querySelectorAll('[aria-label]')).map(e=>e.getAttribute('aria-label')||'').join(' '));
 async function fill(locator,value){await locator.click();await page.keyboard.press('Control+A');await page.keyboard.type(value);}
 async function expose(locator){for(let i=0;i<20;i++){if(await locator.count()){try{await locator.scrollIntoViewIfNeeded({timeout:1500});if(await locator.isVisible())return;}catch{}}await page.mouse.move(950,650);await page.mouse.wheel(0,350);await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}throw Error('Control not reachable: '+locator);}
 await page.goto(base,{waitUntil:'networkidle'});
 await page.waitForFunction(()=>document.querySelector('flt-semantics-placeholder')||document.querySelector('[role=textbox]'),null,{timeout:120000});
 if(await page.locator('flt-semantics-placeholder').count())await page.locator('flt-semantics-placeholder').evaluate(e=>e.click());
 await page.getByRole('textbox').first().waitFor({timeout:120000});
 await page.getByRole('textbox').nth(0).click();await page.keyboard.type('review_admin');
 await page.getByRole('textbox').nth(1).click();await page.keyboard.type(auth.usernames.review_admin);
 await page.getByRole('button',{name:/^Sign in/}).click();
 await page.getByRole('button',{name:/^Trips\./}).waitFor({timeout:60000});
 if(!await page.getByRole('button',{name:/Company and master records/}).count())throw Error('Administrator navigation absent');

 await page.getByRole('button',{name:/^Documents\./}).click();await page.getByRole('button',{name:/^Outputs and presets/}).click();
 for(const [label,value] of [[/^From /,'2026-12-01'],[/^To /,'2026-12-31'],[/^Trip \/ vehicle search/,'BENCH']])await fill(page.getByRole('textbox',{name:label}),value);
 async function leftExpose(locator){for(let i=0;i<20;i++){if(await locator.count()){const box=await locator.boundingBox();if(box&&box.y>=100&&box.y+box.height<950)return;}await page.mouse.move(550,750);await page.mouse.wheel(0,350);await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));}throw Error('Output control not visible');}
 const preview=page.getByRole('button',{name:/^Preview\./}).first();await leftExpose(preview);
 const [response]=await Promise.all([page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/prepare_output'),preview.click()]);if(response.status()!==200)throw Error('Output preview HTTP '+response.status());
 const pdf=page.getByRole('button',{name:/^Save \/ share PDF/});await pdf.waitFor({timeout:60000});await snapshot('authorized-preview');
 const files=[];
 for(const [format,button] of [['pdf',pdf],['xlsx',page.getByRole('button',{name:/^Save \/ share Excel/})]]){
  await expose(button);const [download]=await Promise.all([page.waitForEvent('download',{timeout:90000}),button.click()]);if(await download.failure())throw Error('Export download failed');const target=path.join(output,'candidate'+version.split('+')[1]+'-internal.'+format);await download.saveAs(target);const bytes=fs.readFileSync(target);if(bytes.length<100)throw Error('Empty export');files.push({file:path.basename(target),bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});
 }
 await snapshot('exports-saved');const result={version,source_commit:manifest.source_commit,method:'Actual local release-browser unissued INTERNAL monthly preview and download; December BENCH synthetic only',files,errors,blocked,writes};fs.writeFileSync(path.join(output,'result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));if(errors.length||blocked.length||writes.length)throw Error('Export smoke failures');
})().catch(async e=>{try{const page=browser?.contexts()[0]?.pages()[0];if(page)await page.screenshot({path:path.join(output,'failure.png'),fullPage:true});}catch{}let message=e.name+': '+e.message;for(const secret of Object.values(auth.usernames))message=message.split(secret).join('[withheld]');fs.writeFileSync(path.join(output,'failure.json'),JSON.stringify({version,message,errors,blocked,writes},null,2));console.error(message);process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();});
