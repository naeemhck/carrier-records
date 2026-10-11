begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select ok((select bool_and(not has_table_privilege('authenticated',t,'INSERT,UPDATE,DELETE') and not has_table_privilege('anon',t,'INSERT,UPDATE,DELETE')) from unnest(array['public.trips','public.stops','public.consignments','public.consignment_cars']) t),'Draft aggregates reject all direct client writes');
select ok((select bool_and(not has_table_privilege('authenticated',t,'SELECT,INSERT,UPDATE,DELETE')) from unnest(array['private.trip_requests','private.trip_sequences','private.trip_reviews']) t),'Retry state, numbers and hidden overlap context are private');
select ok((select bool_and(relrowsecurity) from pg_class where oid in ('public.trips'::regclass,'public.stops'::regclass,'public.consignments'::regclass,'public.consignment_cars'::regclass)),'Trip children all enforce RLS');
select ok((select bool_and(prosecdef and pg_get_userbyid(proowner)='carrier_security' and proconfig @> array['search_path=""']) from pg_proc where oid in (
 'public.save_trip(uuid,uuid,integer,jsonb)'::regprocedure,
 'public.get_trip_detail(uuid)'::regprocedure,
 'public.list_trips(text,integer,uuid,uuid,text,text,text)'::regprocedure,
 'public.review_trip_overlap(uuid,uuid,uuid,uuid,text,uuid)'::regprocedure)), 'Draft endpoints use restricted owner with empty search path');
select ok(not has_function_privilege('anon','public.save_trip(uuid,uuid,integer,jsonb)','EXECUTE') and has_function_privilege('authenticated','public.save_trip(uuid,uuid,integer,jsonb)','EXECUTE'),'Only signed-in role may call draft save');
select ok(not has_function_privilege('authenticated','private.trip_payload(uuid)','EXECUTE') and not has_function_privilege('authenticated','private.trip_overlap_context(uuid,uuid,uuid,uuid,uuid,text,uuid)','EXECUTE'),'Clients cannot bypass office filters with payload/overlap helpers');
select ok(not has_table_privilege('carrier_security','public.financial_events','INSERT,UPDATE,DELETE') and not has_table_privilege('carrier_security','public.journal_lines','INSERT,UPDATE,DELETE'),'Draft owner cannot post financial history');
select ok(not pg_has_role('authenticated','carrier_security','MEMBER') and not has_schema_privilege('carrier_security','public','CREATE'),'Clients cannot assume privileged owner or replace functions');
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.save_trip(gen_random_uuid(),gen_random_uuid(),0,'{}')$$,'42501','FORBIDDEN','Missing live identity cannot create trip');
select throws_ok($$select public.list_trips()$$,'42501','FORBIDDEN','Missing live identity cannot search trips');
select throws_ok($$select public.get_trip_detail(gen_random_uuid())$$,'42501','FORBIDDEN','Missing live identity cannot get trip details');
select throws_ok($$select public.review_trip_overlap(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),gen_random_uuid())$$,'42501','FORBIDDEN','Missing live identity cannot review vehicle overlaps');
reset role;
select * from finish();
rollback;
