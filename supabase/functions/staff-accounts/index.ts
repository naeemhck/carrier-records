// Privileged credentials exist only in the Edge runtime environment.
const url = Deno.env.get('SUPABASE_URL')!;
const publicKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
class ApiError extends Error { constructor(public status: number, message: string, public code = 'ACCOUNT_REQUEST_REJECTED') { super(message); } }
async function call(path: string, key: string, token: string, body?: unknown, method = 'POST'): Promise<any> {
 const response = await fetch(`${url}${path}`, { method, headers: { apikey: key, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }, ...(body === undefined ? {} : {body: JSON.stringify(body)}) });
 const data = await response.json().catch(() => null);
 if (!response.ok) {
 const code = path.startsWith('/auth/v1/token') ? 'CURRENT_PASSWORD_VERIFICATION_FAILED' : path === '/auth/v1/user' ? 'ACCOUNT_SESSION_REJECTED' : path.endsWith('/get_session_profile') ? 'ACCOUNT_ACCESS_REJECTED' : path.endsWith('/begin_staff_password') ? 'PASSWORD_PREPARATION_FAILED' : 'ACCOUNT_SERVICE_REJECTED';
 throw new ApiError(response.status === 409 || data?.code === '40001' ? 409 : 403, data?.code === '40001' ? 'Record changed. Reload and retry.' : 'Request denied or unavailable.', code);
 }
 return data;
}
function password(value: unknown): string {
 if (typeof value !== 'string' || value.length < 12 || value.length > 128) throw new ApiError(400, 'Password must contain 12 to 128 characters.');
 return value;
}
function uuid(value: unknown): string {
 if (typeof value !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) throw new ApiError(400, 'Invalid identifier.');
 return value;
}
Deno.serve(async request => {
 if (request.method === 'OPTIONS') return new Response(null, {headers: cors});
 const respond = (status: number, data: unknown) => new Response(JSON.stringify(data), {status,headers: {...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
 try {
 if (request.method !== 'POST') throw new ApiError(405,'POST required.');
 const bearer = request.headers.get('Authorization') ?? '';
 if (!bearer.startsWith('Bearer ')) throw new ApiError(401,'Sign in required.');
 const token = bearer.slice(7);
 const user = await call('/auth/v1/user', publicKey, token, undefined, 'GET');
 const claims = JSON.parse(new TextDecoder().decode(Uint8Array.from(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/')), c=>c.charCodeAt(0))));
 // Auth has verified the token; SQL independently verifies its live session/revision.
 if (claims.sub !== user.id) throw new ApiError(401,'Sign in required.');
 const profile = await call('/rest/v1/rpc/get_session_profile',publicKey,token,{});
 const body = await request.json();
 const fields: Record<string,string[]> = {
 create: ['action','username','display_name','role','office_ids','password'],
 reset: ['action','target_id','expected_version','password'],
 change: ['action','current_password','password','expected_version'],
 };
 if (!body || !fields[body.action] || Object.keys(body).some(k=>!fields[body.action].includes(k))) throw new ApiError(400,'Invalid account request.');
 const nextPassword = password(body.password);
 const serviceRpc = (name: string, data: unknown) => call(`/rest/v1/rpc/${name}`,secret,secret,data);
 if (body.action === 'create') {
 if (profile.role !== 'ADMIN' || profile.must_change_password) throw new ApiError(403,'Administrator access required.');
 if (typeof body.username !== 'string' || !/^[a-z][a-z0-9_.-]{2,31}$/.test(body.username) || typeof body.display_name !== 'string' || !body.display_name.trim() || !['ADMIN','STAFF'].includes(body.role) || !Array.isArray(body.office_ids)) throw new ApiError(400,'Invalid account details.');
 const offices = body.office_ids.map(uuid);
 const created = await call('/auth/v1/admin/users',secret,secret,{email:`${body.username}.${profile.business_id}@staff.invalid`,password:nextPassword,email_confirm:true});
 try {
 const result = await serviceRpc('register_staff',{actor_claims:claims,auth_user_id:created.id,username:body.username,display_name:body.display_name,account_role:body.role,office_ids:offices});
 return respond(200,result);
 } catch (error) {
 // No profile means no usable login. Compensate the orphan identity without logging secrets.
 await call(`/auth/v1/admin/users/${created.id}`,secret,secret,undefined,'DELETE').catch(()=>{});
 throw error;
 }
 }
 const reset = body.action === 'reset';
 if (reset && (profile.role !== 'ADMIN' || profile.must_change_password)) throw new ApiError(403,'Administrator access required.');
 if (!Number.isInteger(body.expected_version) || body.expected_version < 1) throw new ApiError(400,'Version required.');
 if (!reset) {
 // Existing dashboard-created credentials can predate our new-password policy.
 // Auth must verify them; the 12-character minimum still applies to all new ones.
 const currentPassword = body.current_password;
 if (typeof currentPassword !== 'string' || currentPassword.length < 1 || currentPassword.length > 128) throw new ApiError(400,'Current password required (maximum 128 characters).');
 if (currentPassword === nextPassword) throw new ApiError(400,'Choose a different password.');
 const verified = await call('/auth/v1/token?grant_type=password',publicKey,publicKey,{email:`${profile.username}.${profile.business_id}@staff.invalid`,password:currentPassword});
 if (verified.user.id !== user.id) throw new ApiError(403,'Password verification failed.');
 // This temporary verification session is removed together with all target sessions below.
 }
 const operation = await serviceRpc('begin_staff_password',{actor_claims:claims,target_id:reset?uuid(body.target_id):profile.id,expected_version:body.expected_version,is_reset:reset});
 try {
 await call(`/auth/v1/admin/users/${operation.auth_user_id}`,secret,secret,{password:nextPassword},'PUT');
 await serviceRpc('finish_staff_password',{operation_id:operation.operation_id});
 } catch {
 // External Auth/SQL failure leaves the account locked. Never report partial work as success.
 return respond(503,{error:'Password change incomplete. Account is locked; administrator recovery is required.',operation_id:operation.operation_id});
 }
 return respond(200,{sign_in_required:true});
 } catch (error) {
 return respond(error instanceof ApiError ? error.status : 400,{error:error instanceof ApiError ? error.message : 'Invalid request.',error_code:error instanceof ApiError ? error.code : 'ACCOUNT_REQUEST_INVALID'});
 }
});
