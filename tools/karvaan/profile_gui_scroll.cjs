const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {chromium}=require('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const root=process.cwd(),auth=JSON.parse(fs.readFileSync('tools/.local/karvaan-review-auth.json','utf8'));
const version=process.argv[2],port=process.argv[3],suffix=process.argv[4];if(!/^0\.2\.0\+\d+$/.test(version||'')||!['8767','8768','8769'].includes(port)||!/^gui[0-9]+-[a-z0-9-]+$/.test(suffix||''))throw Error('Explicit candidate, pinned local port and new diagnostic folder required');
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
 const listPromise=page.waitForResponse(r=>new URL(r.url()).pathname==='/rest/v1/rpc/list_trips');
 await page.getByRole('button',{name:/^Trips\./}).click();const listResponse=await listPromise;if(listResponse.status()!==200)throw Error('Scoped trip list rejected');const listPayload=await listResponse.json();if(!Array.isArray(listPayload.rows)||listPayload.rows.length!==50)throw Error('Expected full50-row page');

 await page.evaluate(()=>{window.guiFrames=[];window.guiLast=null;window.guiSampling=true;const sample=t=>{if(!window.guiSampling)return;if(window.guiLast!==null)window.guiFrames.push(t-window.guiLast);window.guiLast=t;requestAnimationFrame(sample);};requestAnimationFrame(sample);});
 await page.mouse.move(1000,700);for(let i=0;i<20;i++){await page.mouse.wheel(0,i<10?280:-280);await page.waitForTimeout(50);}
 const frames=await page.evaluate(()=>{window.guiSampling=false;return window.guiFrames;});
 const sorted=[...frames].sort((a,b)=>a-b),pct=q=>sorted[Math.max(0,Math.ceil(sorted.length*q)-1)];
 await snapshot('trips-scroll');
 const result={version,source_commit:manifest.source_commit,page_rows:listPayload.rows.length,method:'Desktop Chromium requestAnimationFrame intervals during20 wheel events; one user; fresh context; retained OS/backend caches; not five-user gate',frames:frames.length,interval_ms:{p50:pct(.5),p95:pct(.95),max:sorted.at(-1)},over_50ms:frames.filter(x=>x>50).length,errors,blocked,writes};
 fs.writeFileSync(path.join(output,'result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));if(errors.length||blocked.length||writes.length||frames.length<20)throw Error('Scroll diagnostic incomplete');
})().catch(e=>{let message=e.name+': '+e.message;for(const secret of Object.values(auth.usernames))message=message.split(secret).join('[withheld]');console.error(message);process.exitCode=1;}).finally(async()=>{if(browser)await browser.close();});
