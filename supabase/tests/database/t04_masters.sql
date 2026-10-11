begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select ok(not has_schema_privilege('carrier_security','public','CREATE') and not has_schema_privilege('carrier_security','private','CREATE'),'Master owner cannot create replacement functions');
select ok(not pg_has_role('authenticated','carrier_security','MEMBER'),'Client cannot assume master function owner');
select ok(not has_table_privilege('authenticated','private.master_requests','SELECT,INSERT,UPDATE,DELETE'),'Master retry commands are private');
select ok(not has_function_privilege('authenticated','private.master_payload(text,jsonb,boolean)','EXECUTE'),'Payload helper is not callable by clients');
select ok(not has_function_privilege('anon','public.save_master_record(text,uuid,uuid,integer,jsonb)','EXECUTE'),'Anonymous cannot execute master saves');
select ok((select bool_and(prosecdef and pg_get_userbyid(proowner)='carrier_security' and proconfig @> array['search_path=""']) from pg_proc where oid in (
 'public.save_master_record(text,uuid,uuid,integer,jsonb)'::regprocedure,
 'public.list_master_records(text,text,integer,boolean)'::regprocedure,
 'public.get_trip_defaults(uuid,uuid,uuid,uuid)'::regprocedure,
 'public.require_document_setup()'::regprocedure)), 'Public commands use restricted owner and pinned empty search path');
select ok((select bool_and(relrowsecurity) from pg_class where oid in ('public.businesses'::regclass,'public.offices'::regclass,'public.parties'::regclass,
 'public.party_roles'::regclass,'public.vehicles'::regclass,'public.routes'::regclass,'public.expense_categories'::regclass)),'All master tables have RLS');
select ok((select bool_and(not has_table_privilege('authenticated',t,'INSERT,UPDATE,DELETE')) from unnest(array['public.businesses','public.offices','public.parties','public.party_roles','public.vehicles','public.routes','public.expense_categories']) t),'No master table permits direct client writes');
-- Temporary test membership only, rolled back; private helpers stay client-closed.
grant carrier_security to postgres;
select is(private.master_payload('ROUTE','{"id":"00000000-0000-4000-8000-000000000001","suggested_fare":9999999999999999.99}'::jsonb,false)->>'suggested_fare','9999999999999999.99','Maximum route fare returned as exact decimal string');
select ok(not(private.master_payload('PARTY','{"id":"00000000-0000-4000-8000-000000000001","contact_details":{"phone":"secret"},"created_by":"secret"}'::jsonb,false) ? 'contact_details'),'Staff choices exclude contact details');
revoke carrier_security from postgres;
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.list_master_records('PARTY')$$,'42501','FORBIDDEN','Unverified session cannot list master choices');
select throws_ok($$select public.save_master_record('CATEGORY',gen_random_uuid(),gen_random_uuid(),0,'{"name":"Bypass"}')$$,'42501','FORBIDDEN','Unverified session cannot create a master');
select throws_ok($$select public.require_document_setup()$$,'42501','FORBIDDEN','Unverified session cannot retrieve company/issuer context');
select throws_ok($$select public.get_trip_defaults(gen_random_uuid(),null,gen_random_uuid(),gen_random_uuid())$$,'42501','FORBIDDEN','Unverified session cannot prepare snapshots');
reset role;
select * from finish();
rollback;
