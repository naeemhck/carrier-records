-- T06: atomic operational transitions and the narrow dispatch-earnings interface.
alter table public.trips add column dispatch_actor_id uuid;
alter table public.trips add column arrival_actor_id uuid;
alter table public.trips add foreign key(business_id,dispatch_actor_id) references public.staff_profiles(business_id,id);
alter table public.trips add foreign key(business_id,arrival_actor_id) references public.staff_profiles(business_id,id);
create table private.lifecycle_requests (
 business_id uuid not null references public.businesses(id), request_id uuid not null,
 actor_id uuid not null references public.staff_profiles(id), command jsonb not null, result jsonb not null,
 primary key(business_id,request_id)
);
create table private.trip_recognition (
 business_id uuid not null, trip_id uuid primary key, effective_date date not null,
 event_ids uuid[] not null, generation integer not null check(generation>0),
 foreign key(business_id,trip_id) references public.trips(business_id,id)
);
do $$ begin
 if not exists(select 1 from pg_roles where rolname='carrier_earnings') then
  create role carrier_earnings nologin noinherit nobypassrls;
 end if;
end $$;
alter role carrier_earnings nologin noinherit nobypassrls;
grant carrier_security,carrier_earnings to postgres;
grant usage on schema public,private to carrier_earnings;
grant select on public.trips,public.consignments,public.financial_events,public.journal_lines,public.allocations to carrier_earnings;
grant insert on public.financial_events,public.journal_lines to carrier_earnings;
grant select,insert,update on private.trip_recognition to carrier_earnings;
grant select on private.trip_recognition to carrier_security;
grant select,insert on private.lifecycle_requests to carrier_security;
grant execute on function private.current_staff(boolean),private.office_access(uuid,uuid) to carrier_earnings;

-- Draft aggregate saves must not remove or rewrite a cancelled load's evidence.
create function private.retain_cancelled_load() returns trigger
language plpgsql security definer set search_path='' as $$
declare retained boolean;
begin
 if tg_table_name='consignments' then retained:=old.state='CANCELLED';
 else retained:=exists(select 1 from public.consignments where id=old.consignment_id and state='CANCELLED'); end if;
 if retained and (tg_op='DELETE' or (to_jsonb(new)-'version'-'updated_at') is distinct from (to_jsonb(old)-'version'-'updated_at'))
  then raise exception 'CANCELLED_CONSIGNMENT_RETAINED' using errcode='22023'; end if;
 if tg_op='DELETE' then return old; end if;
 return new;
end $$;
create trigger zz_retain_cancelled_load before update or delete on public.consignments for each row execute function private.retain_cancelled_load();
create trigger zz_retain_cancelled_load before update or delete on public.consignment_cars for each row execute function private.retain_cancelled_load();
do $$ declare t text; begin
 foreach t in array array['trips','consignments','financial_events','journal_lines','allocations'] loop
  execute format('create policy earnings_read on public.%I for select to carrier_earnings using(true)',t);
 end loop;
end $$;
create policy earnings_insert on public.financial_events for insert to carrier_earnings with check(true);
create policy earnings_insert on public.journal_lines for insert to carrier_earnings with check(true);

-- Only lifecycle commands can invoke this journal writer. No client/general
-- account-management function owner receives financial table write privileges.
create function private.post_dispatch_earnings(journey_id uuid,new_date date,correction_reason text default null) returns void
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; t public.trips; batch private.trip_recognition;
 c public.consignments; previous public.financial_events; posting_id uuid; reverse_id uuid;
 ids uuid[]:=array[]::uuid[]; prior_id uuid; q numeric; o numeric; broker numeric;
begin
 actor:=private.current_staff(); select * into t from public.trips where id=journey_id;
 if actor.id is null or t.business_id is distinct from actor.business_id or not private.office_access(actor.business_id,t.origin_office_id)
  or new_date is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into batch from private.trip_recognition where trip_id=t.id for update;
 if batch.trip_id is not null then
  if coalesce(length(btrim(correction_reason)),0) not between 1 and 500 then raise exception 'CORRECTION_REASON_REQUIRED' using errcode='22023'; end if;
  -- Until T07/T10 can explicitly unwind dependent settlements, block all
  -- non-recognition financial activity or allocations on this journey.
  if exists(select 1 from public.financial_events where trip_id=t.id and kind not in ('DISPATCH','REVERSAL','REPLACEMENT'))
   or exists(select 1 from public.allocations a where a.trip_id=t.id or a.source_event_id=any(batch.event_ids)
    or a.source_line_id in(select id from public.journal_lines where public.journal_lines.event_id=any(batch.event_ids))
    or a.target_line_id in(select id from public.journal_lines where public.journal_lines.event_id=any(batch.event_ids)))
   then raise exception 'DEPENDENT_SETTLEMENTS' using errcode='22023'; end if;
  foreach prior_id in array batch.event_ids loop
   select * into previous from public.financial_events where id=prior_id and business_id=t.business_id;
   if previous.id is null or exists(select 1 from public.financial_events where reversal_of_id=prior_id)
    then raise exception 'RECOGNITION_HISTORY_CONFLICT' using errcode='PT409'; end if;
   reverse_id:=gen_random_uuid();
   insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id,reversal_of_id,reason,created_by)
    values(reverse_id,t.business_id,'REVERSAL',previous.effective_date,actor.id,t.origin_office_id,t.vehicle_id,t.id,previous.consignment_id,previous.amount,gen_random_uuid(),prior_id,btrim(correction_reason),actor.auth_user_id);
   insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    select business_id,reverse_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,-signed_amount,actor.auth_user_id from public.journal_lines where public.journal_lines.event_id=prior_id;
   posting_id:=gen_random_uuid();
   insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id,replacement_of_id,reason,created_by)
    values(posting_id,t.business_id,'REPLACEMENT',new_date,actor.id,t.origin_office_id,t.vehicle_id,t.id,previous.consignment_id,previous.amount,gen_random_uuid(),prior_id,btrim(correction_reason),actor.auth_user_id);
   insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    select business_id,posting_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,actor.auth_user_id from public.journal_lines where public.journal_lines.event_id=prior_id;
   ids:=array_append(ids,posting_id);
  end loop;
  update private.trip_recognition set event_ids=ids,effective_date=new_date,generation=generation+1 where trip_id=t.id;
 else
  if t.state<>'DRAFT' or exists(select 1 from public.financial_events where trip_id=t.id and kind in ('DISPATCH','REPLACEMENT'))
    then raise exception 'RECOGNITION_HISTORY_CONFLICT' using errcode='PT409'; end if;
  for c in select * from public.consignments where trip_id=t.id and state='ACTIVE' order by id loop
   q:=c.customer_charge; o:=c.owner_entitlement; broker:=c.commission;
   if q<>o+broker or q<0 or o<0 or broker<0 then raise exception 'INVALID_QUOTE_SNAPSHOT' using errcode='22023'; end if;
   posting_id:=gen_random_uuid();
   insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id,created_by)
    values(posting_id,t.business_id,'DISPATCH',new_date,actor.id,t.origin_office_id,t.vehicle_id,t.id,c.id,q,gen_random_uuid(),actor.auth_user_id);
   if q>0 then insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    values(t.business_id,posting_id,c.customer_id,t.origin_office_id,t.vehicle_id,t.id,c.id,'CUSTOMER_RECEIVABLE',q,actor.auth_user_id); end if;
   if o>0 then insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    values(t.business_id,posting_id,t.owner_id,t.origin_office_id,t.vehicle_id,t.id,c.id,'OWNER_PAYABLE',-o,actor.auth_user_id); end if;
   if broker>0 then insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    values(t.business_id,posting_id,c.broker_id,t.origin_office_id,t.vehicle_id,t.id,c.id,'BROKER_COMMISSION_PAYABLE',-broker,actor.auth_user_id); end if;
   ids:=array_append(ids,posting_id);
  end loop;
  insert into private.trip_recognition values(t.business_id,t.id,new_date,ids,1);
 end if;
end $$;

create or replace function public.get_trip_detail(trip_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles; t public.trips; origin boolean; destination boolean; creator boolean;
begin
 actor:=private.current_staff();
 if actor.id is null or not private.trip_access(actor.business_id,trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into t from public.trips where id=trip_id and business_id=actor.business_id;
 origin:=private.office_access(actor.business_id,t.origin_office_id); destination:=private.office_access(actor.business_id,t.destination_office_id);
 creator:=actor.role='ADMIN' or t.created_by=actor.auth_user_id;
 return private.trip_payload(t.id)||jsonb_build_object(
  'can_edit',t.state='DRAFT' and origin and creator and not exists(select 1 from public.financial_events where public.financial_events.trip_id=t.id) and not exists(select 1 from public.issued_documents where public.issued_documents.trip_id=t.id),
  'can_dispatch',t.state='DRAFT' and origin,'can_arrive',t.state='DISPATCHED' and destination,
  'can_cancel_draft',t.state='DRAFT' and origin and creator,
  'can_cancel_consignment',t.state='DRAFT' and origin and creator,
  'can_correct_operation',t.state in ('DISPATCHED','ARRIVED') and origin and creator,
  'can_correct_dispatch_date',t.state in ('DISPATCHED','ARRIVED') and origin and (actor.role='ADMIN' or t.dispatch_actor_id=actor.id),
  'can_correct_arrival_date',t.state='ARRIVED' and destination and (actor.role='ADMIN' or t.arrival_actor_id=actor.id),
  'earnings_recognized',exists(select 1 from private.trip_recognition where private.trip_recognition.trip_id=t.id));
end $$;

create function private.run_trip_lifecycle(action text,target_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; t public.trips; cached private.lifecycle_requests; command_body jsonb;
 origin boolean; destination boolean; effective_date date; before_data jsonb; result jsonb; context jsonb; review private.trip_reviews;
 confirmed boolean:=false; reason text; child_id uuid; driver uuid;
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if target_id is null or request_id is null or expected_version is null or expected_version<1 or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>10000
  then raise exception 'INVALID_COMMAND' using errcode='22023'; end if;
 select * into t from public.trips where id=target_id and business_id=actor.business_id;
 if t.id is null or not private.trip_access(actor.business_id,t.id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 -- Match T05 lock order. Reread the vehicle under the business lock; a draft
 -- edit must not change it between the lookup and overlap/state serialization.
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));
 select * into t from public.trips where id=target_id and business_id=actor.business_id;
 perform pg_advisory_xact_lock(hashtextextended('trip-vehicle:'||t.vehicle_id::text,0));
 actor:=private.current_staff(); select * into t from public.trips where id=target_id and business_id=actor.business_id for update;
 origin:=private.office_access(actor.business_id,t.origin_office_id); destination:=private.office_access(actor.business_id,t.destination_office_id);
 if actor.id is null or t.id is null or (action in ('DISPATCH','CANCEL_DRAFT','CANCEL_CONSIGNMENT','CORRECT_OPERATION','CORRECT_DISPATCH_DATE') and not origin)
  or (action in ('ARRIVE','CORRECT_ARRIVAL_DATE') and not destination)
  or (action in ('CANCEL_DRAFT','CANCEL_CONSIGNMENT','CORRECT_OPERATION') and actor.role<>'ADMIN' and t.created_by is distinct from actor.auth_user_id)
  or (action='CORRECT_DISPATCH_DATE' and actor.role<>'ADMIN' and t.dispatch_actor_id is distinct from actor.id)
  or (action='CORRECT_ARRIVAL_DATE' and actor.role<>'ADMIN' and t.arrival_actor_id is distinct from actor.id)
  then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if action not in ('DISPATCH','ARRIVE','CANCEL_DRAFT','CANCEL_CONSIGNMENT','CORRECT_OPERATION','CORRECT_DISPATCH_DATE','CORRECT_ARRIVAL_DATE')
  then raise exception 'INVALID_ACTION' using errcode='22023'; end if;
 command_body:=jsonb_build_object('action',action,'id',target_id,'version',expected_version,'payload',payload);
 select * into cached from private.lifecycle_requests r where r.business_id=actor.business_id and r.request_id=run_trip_lifecycle.request_id;
 if found then
  if cached.actor_id<>actor.id or cached.command<>command_body then raise exception 'REQUEST_ID_CONFLICT' using errcode='PT409'; end if;
  return cached.result;
 end if;
 if t.version<>expected_version then raise exception 'VERSION_CONFLICT' using errcode='PT409'; end if;
 if exists(select 1 from jsonb_object_keys(payload) k where k not in (
  select unnest(case action when 'DISPATCH' then array['dispatch_date','review_token','overlap_confirmed','overlap_reason','reason']
   when 'ARRIVE' then array['arrival_date','reason'] when 'CANCEL_CONSIGNMENT' then array['consignment_id','reason']
   when 'CORRECT_OPERATION' then array['notes','driver_id','reason'] when 'CORRECT_DISPATCH_DATE' then array['dispatch_date','reason']
   when 'CORRECT_ARRIVAL_DATE' then array['arrival_date','reason'] else array['reason'] end)))
  then raise exception 'INVALID_FIELDS' using errcode='22023'; end if;
 reason:=btrim(payload->>'reason');
 if coalesce(length(reason),0) not between 1 and 500 then raise exception 'REASON_REQUIRED' using errcode='22023'; end if;
 before_data:=private.trip_payload(t.id);
 if action='DISPATCH' then
  if t.state<>'DRAFT' then raise exception 'INVALID_TRANSITION' using errcode='22023'; end if;
  effective_date:=public.parse_business_date(payload->>'dispatch_date');
  if effective_date is null then raise exception 'ACTUAL_DATE_REQUIRED' using errcode='22023'; end if;
  if (select count(*) from public.offices where id in(t.origin_office_id,t.destination_office_id) and archived_at is null)<>2
   or not exists(select 1 from public.vehicles where id=t.vehicle_id and archived_at is null)
   or (t.load_kind='LOADED' and not exists(select 1 from public.consignments where trip_id=t.id and state='ACTIVE'))
   then raise exception 'DISPATCH_NOT_READY' using errcode='22023'; end if;
  context:=private.trip_overlap_context(actor.business_id,t.id,t.vehicle_id,t.origin_office_id,t.destination_office_id,payload->>'dispatch_date',t.return_of_trip_id);
  if jsonb_array_length(context->'overlaps')>0 then
   select * into review from private.trip_reviews where token=(payload->>'review_token')::uuid and actor_id=actor.id and business_id=actor.business_id;
   if review.token is null or review.expires_at<now() or payload->'overlap_confirmed' is distinct from 'true'::jsonb or coalesce(length(btrim(payload->>'overlap_reason')),0) not between 1 and 500
    then raise exception 'OVERLAP_CONFIRMATION_REQUIRED' using errcode='22023'; end if;
   if review.context<>context then raise exception 'OVERLAP_REVIEW_CHANGED' using errcode='PT409'; end if;
   confirmed:=true;
  end if;
  perform private.post_dispatch_earnings(t.id,effective_date);
  update public.trips set state='DISPATCHED',dispatch_date=effective_date,dispatch_actor_id=actor.id,overlap_confirmed=confirmed,
   overlap_reason=case when confirmed then btrim(payload->>'overlap_reason') end,version=version+1 where id=t.id;
 elsif action='ARRIVE' then
  if t.state<>'DISPATCHED' then raise exception 'INVALID_TRANSITION' using errcode='22023'; end if;
  effective_date:=public.parse_business_date(payload->>'arrival_date');
  if effective_date is null or effective_date<t.dispatch_date then raise exception 'INVALID_ARRIVAL_DATE' using errcode='22023'; end if;
  update public.consignments set state='DELIVERED',version=version+1 where trip_id=t.id and state='ACTIVE';
  update public.trips set state='ARRIVED',arrival_date=effective_date,arrival_actor_id=actor.id,version=version+1 where id=t.id;
 elsif action in ('CANCEL_DRAFT','CANCEL_CONSIGNMENT') then
  if t.state<>'DRAFT' then raise exception 'FINANCIAL_ADJUSTMENT_REQUIRED' using errcode='22023'; end if;
  if exists(select 1 from public.financial_events where trip_id=t.id) or exists(select 1 from public.expenses where trip_id=t.id and state='CONFIRMED')
   or exists(select 1 from public.issued_documents where trip_id=t.id) then raise exception 'DEPENDENT_SETTLEMENTS' using errcode='22023'; end if;
  if action='CANCEL_CONSIGNMENT' then
   child_id:=(payload->>'consignment_id')::uuid;
   if not exists(select 1 from public.consignments where id=child_id and trip_id=t.id and state='ACTIVE') then raise exception 'INVALID_CONSIGNMENT' using errcode='22023'; end if;
   update public.consignments set state='CANCELLED',version=version+1 where id=child_id;
   update public.trips set version=version+1 where id=t.id;
  else
   if exists(select 1 from public.trips where return_of_trip_id=t.id and state<>'CANCELLED') then raise exception 'RETURN_DEPENDENCY' using errcode='22023'; end if;
   update public.consignments set state='CANCELLED',version=version+1 where trip_id=t.id and state='ACTIVE';
   update public.trips set state='CANCELLED',version=version+1 where id=t.id;
  end if;
 elsif action='CORRECT_OPERATION' then
  if t.state not in ('DISPATCHED','ARRIVED') then raise exception 'INVALID_TRANSITION' using errcode='22023'; end if;
  if not(payload ? 'notes' or payload ? 'driver_id') or (payload ? 'notes' and (jsonb_typeof(payload->'notes') is distinct from 'string' or length(payload->>'notes')>2000)) then raise exception 'INVALID_FIELDS' using errcode='22023'; end if;
  driver:=case when payload ? 'driver_id' then (payload->>'driver_id')::uuid else t.driver_id end;
  if driver is not null and driver is distinct from t.driver_id and not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id where p.id=driver and p.business_id=t.business_id and p.archived_at is null and r.role='DRIVER' and r.archived_at is null)
   then raise exception 'ACTIVE_DRIVER_REQUIRED' using errcode='22023'; end if;
  update public.trips set notes=case when payload ? 'notes' then payload->>'notes' else notes end,driver_id=driver,version=version+1 where id=t.id;
 elsif action='CORRECT_DISPATCH_DATE' then
  if t.state not in ('DISPATCHED','ARRIVED') then raise exception 'INVALID_TRANSITION' using errcode='22023'; end if;
  effective_date:=public.parse_business_date(payload->>'dispatch_date');
  if effective_date is null or effective_date=t.dispatch_date or effective_date>t.arrival_date then raise exception 'INVALID_DISPATCH_DATE' using errcode='22023'; end if;
  if not exists(select 1 from private.trip_recognition where trip_id=t.id) then raise exception 'EARNINGS_HISTORY_UNAVAILABLE' using errcode='22023'; end if;
  if exists(select 1 from public.issued_documents where trip_id=t.id) then raise exception 'DEPENDENT_SETTLEMENTS' using errcode='22023'; end if;
  perform private.post_dispatch_earnings(t.id,effective_date,reason);
  update public.trips set dispatch_date=effective_date,version=version+1 where id=t.id;
 else
  if t.state<>'ARRIVED' then raise exception 'INVALID_TRANSITION' using errcode='22023'; end if;
  effective_date:=public.parse_business_date(payload->>'arrival_date');
  if effective_date is null or effective_date<t.dispatch_date or effective_date=t.arrival_date then raise exception 'INVALID_ARRIVAL_DATE' using errcode='22023'; end if;
  update public.trips set arrival_date=effective_date,version=version+1 where id=t.id;
 end if;
 result:=public.get_trip_detail(t.id);
 insert into public.audit_events(business_id,actor_id,office_id,trip_id,record_id,record_type,action,reason,before_data,after_data,created_by)
  values(actor.business_id,actor.id,case when action in ('ARRIVE','CORRECT_ARRIVAL_DATE') then t.destination_office_id else t.origin_office_id end,t.id,t.id,'TRIP',action,reason,before_data,result,actor.auth_user_id);
 insert into private.lifecycle_requests values(actor.business_id,request_id,actor.id,command_body,result);
 return result;
end $$;

create function public.dispatch_trip(target_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language sql security definer set search_path='' as $$ select private.run_trip_lifecycle('DISPATCH',target_id,request_id,expected_version,payload) $$;
create function public.arrive_trip(target_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language sql security definer set search_path='' as $$ select private.run_trip_lifecycle('ARRIVE',target_id,request_id,expected_version,payload) $$;
create function public.correct_trip_operation(action text,target_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if action not in ('CANCEL_DRAFT','CANCEL_CONSIGNMENT','CORRECT_OPERATION','CORRECT_DISPATCH_DATE','CORRECT_ARRIVAL_DATE') or action is null then raise exception 'INVALID_ACTION' using errcode='22023'; end if;
 return private.run_trip_lifecycle(action,target_id,request_id,expected_version,payload);
end $$;
create function private.trip_history_values(v jsonb) returns jsonb language sql immutable set search_path='' as $$
 select coalesce(jsonb_object_agg(key,value),'{}') from jsonb_each(coalesce(v,'{}'))
 where key in ('version','state','load_kind','dispatch_date','arrival_date','planned_dispatch_date','notes','driver_name','overlap_confirmed','overlap_reason','totals')
$$;
create function public.get_trip_history(trip_id uuid,page_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles; rows jsonb;
begin
 actor:=private.current_staff();
 if actor.id is null or not private.trip_access(actor.business_id,trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if page_offset is null or page_offset<0 then raise exception 'INVALID_QUERY' using errcode='22023'; end if;
 select coalesce(jsonb_agg(x.data order by x.recorded_at desc,x.id),'[]') into rows from (
  select a.id,a.recorded_at,jsonb_build_object('action',a.action,'actor_name',s.display_name,'recorded_at',a.recorded_at,'reason',a.reason,
   'before',private.trip_history_values(a.before_data),'after',private.trip_history_values(a.after_data)) data
  from public.audit_events a join public.staff_profiles s on s.id=a.actor_id where a.business_id=actor.business_id and a.trip_id=get_trip_history.trip_id and a.record_type='TRIP'
  order by a.recorded_at desc,a.id limit 50 offset page_offset) x;
 return jsonb_build_object('rows',rows);
end $$;

grant create on schema public,private to carrier_security,carrier_earnings;
alter function private.post_dispatch_earnings(uuid,date,text) owner to carrier_earnings;
alter function private.run_trip_lifecycle(text,uuid,uuid,integer,jsonb) owner to carrier_security;
alter function private.trip_history_values(jsonb) owner to carrier_security;
alter function private.retain_cancelled_load() owner to carrier_security;
revoke all on function private.retain_cancelled_load() from public,anon,authenticated;
alter function public.dispatch_trip(uuid,uuid,integer,jsonb) owner to carrier_security;
alter function public.arrive_trip(uuid,uuid,integer,jsonb) owner to carrier_security;
alter function public.correct_trip_operation(text,uuid,uuid,integer,jsonb) owner to carrier_security;
alter function public.get_trip_history(uuid,integer) owner to carrier_security;
revoke all on function private.post_dispatch_earnings(uuid,date,text),private.run_trip_lifecycle(text,uuid,uuid,integer,jsonb),private.trip_history_values(jsonb) from public,anon,authenticated;
grant execute on function private.post_dispatch_earnings(uuid,date,text) to carrier_security;
revoke all on function public.dispatch_trip(uuid,uuid,integer,jsonb),public.arrive_trip(uuid,uuid,integer,jsonb),public.correct_trip_operation(text,uuid,uuid,integer,jsonb),public.get_trip_history(uuid,integer) from public,anon,authenticated;
grant execute on function public.dispatch_trip(uuid,uuid,integer,jsonb),public.arrive_trip(uuid,uuid,integer,jsonb),public.correct_trip_operation(text,uuid,uuid,integer,jsonb),public.get_trip_history(uuid,integer) to authenticated;
revoke create on schema public,private from carrier_security,carrier_earnings;
revoke carrier_security,carrier_earnings from postgres;
