// Only this trusted boundary has Storage write credentials. Downloads use live RLS.
const url=Deno.env.get('SUPABASE_URL')!;
const anon=Deno.env.get('SUPABASE_ANON_KEY')!;
const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
const uuid=(s:unknown)=>typeof s==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(s);
async function api(path:string,key:string,token:string,body?:unknown,method='POST'){
 const r=await fetch(url+path,{method,headers:{apikey:key,Authorization:'Bearer '+token,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
 const data=await r.json().catch(()=>null);if(!r.ok)throw {status:r.status,message:'Receipt request denied or unavailable.'};return data;
}
Deno.serve(async req=>{
 const respond=(status:number,data:unknown)=>new Response(JSON.stringify(data),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});
 try{
 if(req.method!=='POST')return respond(405,{error:'POST required.'});
 const token=(req.headers.get('Authorization')??'').replace(/^Bearer /,'');
 const user=await api('/auth/v1/user',anon,token,undefined,'GET');
 const profile=await api('/rest/v1/rpc/get_session_profile',anon,token,{});
 if(profile.must_change_password)throw {status:403,message:'Ready staff access required.'};
 // Bound body size before parsing, including chunked requests. No logs of evidence.
 const reader=req.body?.getReader();if(!reader)throw {status:400,message:'Evidence required.'};
 let size=0;const chunks:Uint8Array[]=[];
 while(true){const v=await reader.read();if(v.done)break;size+=v.value.length;if(size>7100000){await reader.cancel();throw {status:413,message:'Receipt exceeds 5 MB.'};}chunks.push(v.value);}
 const input=new Uint8Array(size);let pos=0;for(const c of chunks){input.set(c,pos);pos+=c.length;}
 const body=JSON.parse(new TextDecoder().decode(input));
 const claims=JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0))));
 if(claims.sub!==user.id)throw {status:403,message:'Verified staff session required.'};
 if(body.action==='cleanup'){
  if(Object.keys(body).some(k=>k!=='action')||profile.role!=='ADMIN')throw {status:403,message:'Administrator access required.'};
  const paths=await api('/rest/v1/rpc/reserve_abandoned_receipts',service,service,{actor_claims:claims});
  if(paths.length)await api('/storage/v1/object/receipts',service,service,{prefixes:paths},'DELETE');
  return respond(200,{removed_abandoned:paths.length});
 }

 if(Object.keys(body).some(k=>!['expense_id','request_id','expected_version','mime_type','base64'].includes(k))||!uuid(body.expense_id)||!uuid(body.request_id)||!Number.isInteger(body.expected_version)||typeof body.base64!=='string')throw {status:400,message:'Invalid evidence request.'};
 const expenses=await api('/rest/v1/expenses?id=eq.'+body.expense_id+'&select=id,business_id,version,state',anon,token,undefined,'GET');
 if(expenses.length!==1||expenses[0].state!=='CONFIRMED')throw {status:403,message:'Expense access required.'};
 const bytes=Uint8Array.from(atob(body.base64),c=>c.charCodeAt(0));
 if(bytes.length<1||bytes.length>5242880)throw {status:413,message:'Receipt exceeds 5 MB.'};
 // Content signatures must agree with the declared supported MIME; extensions are ignored.
 const png=[137,80,78,71,13,10,26,10].every((v,i)=>bytes[i]===v);
 const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
 const pdf=new TextDecoder().decode(bytes.slice(0,5))==='%PDF-';
 if(!(body.mime_type==='image/png'&&png||body.mime_type==='image/jpeg'&&jpeg||body.mime_type==='application/pdf'&&pdf))throw {status:415,message:'Use PNG, JPEG or PDF evidence with matching content.'};
 const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))).map(v=>v.toString(16).padStart(2,'0')).join('');
 const path=expenses[0].business_id+'/'+body.expense_id+'/'+body.request_id;
 const headers={apikey:service,Authorization:'Bearer '+service,'Content-Type':body.mime_type,'Cache-Control':'no-store'};
 const uploaded=await fetch(url+'/storage/v1/object/receipts/'+path,{method:'POST',headers,body:bytes});
 if(!uploaded.ok){
  // Lost responses and competing retries may already have uploaded this opaque object.
  const existing=await fetch(url+'/storage/v1/object/receipts/'+path,{headers:{apikey:service,Authorization:'Bearer '+service}});
  if(!existing.ok)throw {status:503,message:'Expense remains posted. Receipt upload failed; retry the same attachment.'};
  const actual=new Uint8Array(await existing.arrayBuffer());
  const actualHash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',actual))).map(v=>v.toString(16).padStart(2,'0')).join('');
  if(actualHash!==hash)throw {status:409,message:'Attachment retry differs from uploaded evidence.'};
 }

 const result=await api('/rest/v1/rpc/attach_expense_receipt',service,service,{actor_claims:claims,expense_id:body.expense_id,request_id:body.request_id,expected_version:body.expected_version,mime_type:body.mime_type,byte_size:bytes.length,sha256:hash});
 return respond(200,result);
 }catch(e){const error=e as {status?:number,message?:string};return respond(error.status??400,{receipt_status:'FAILED',financial_status:'UNCHANGED',error:error.message??'Invalid receipt. Expense posting is unchanged.'});}
});
