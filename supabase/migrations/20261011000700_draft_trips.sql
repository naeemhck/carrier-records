-- T05 aggregate drafts. Lifecycle/financial posting remain T06/T07.
alter table public.consignments add column pickup_stop_id uuid;
alter table public.consignments add column drop_stop_id uuid;
alter table public.consignments add foreign key(business_id,trip_id,pickup_stop_id) references public.stops(business_id,trip_id,id);
alter table public.consignments add foreign key(business_id,trip_id,drop_stop_id) references public.stops(business_id,trip_id,id);
create table private.trip_requests (
 business_id uuid not null references public.businesses(id), request_id uuid not null,
 actor_id uuid not null references public.staff_profiles(id), command jsonb not null, result jsonb not null,
 primary key(business_id,request_id)
);
create table private.trip_sequences (business_id uuid primary key references public.businesses(id), last_number bigint not null);
create table private.trip_reviews (
 token uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id),
 actor_id uuid not null references public.staff_profiles(id), context jsonb not null, expires_at timestamptz not null
);
grant carrier_security to postgres;
grant select,insert on private.trip_requests to carrier_security;
grant select,insert,update on private.trip_sequences to carrier_security;
grant select,insert,delete on private.trip_reviews to carrier_security;
grant insert,update on public.trips to carrier_security;
grant insert,update,delete on public.consignments,public.stops,public.consignment_cars to carrier_security;
grant execute on function public.calculate_quote(text,text,text,text,boolean),public.parse_business_date(text) to carrier_security;

create function private.trip_payload(journey_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t public.trips; result jsonb; rows jsonb;
begin
 select * into t from public.trips where id=journey_id;
 result:=jsonb_build_object('id',t.id,'trip_number',t.trip_number,'version',t.version,'vehicle_id',t.vehicle_id,
  'registration',(select registration from public.vehicles where id=t.vehicle_id),'driver_id',t.driver_id,
  'driver_name',(select display_name from public.parties where id=t.driver_id),
  'origin_office_id',t.origin_office_id,'destination_office_id',t.destination_office_id,
  'origin_name',(select name from public.offices where id=t.origin_office_id),
  'destination_name',(select name from public.offices where id=t.destination_office_id),
  'owner_id',t.owner_id,'owner_snapshot',t.owner_snapshot,'route_id',t.route_id,'route_snapshot',t.route_snapshot,
  'load_kind',t.load_kind,'state',t.state,'planned_dispatch_date',t.planned_dispatch_date,
  'dispatch_date',t.dispatch_date,'arrival_date',t.arrival_date,'notes',t.notes,
  'return_of_trip_id',t.return_of_trip_id,'overlap_confirmed',t.overlap_confirmed,'overlap_reason',t.overlap_reason);
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'position',s.position,'kind',s.kind,'address',s.address) order by s.position),'[]')
 into rows from public.stops s where s.trip_id=t.id;
 result:=result||jsonb_build_object('stops',rows);
 select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'customer_id',c.customer_id,
  'customer_name',(select display_name from public.parties where id=c.customer_id),
  'broker_id',c.broker_id,'broker_name',(select display_name from public.parties where id=c.broker_id),
  'state',c.state,'car_count',c.car_count,'quoted_amount',c.quoted_amount::text,'quote_mode',c.quote_mode,
  'commission_method',c.commission_method,'commission_value',c.commission_value::text,
  'commission',c.commission::text,'customer_charge',c.customer_charge::text,'owner_entitlement',c.owner_entitlement::text,
  'pickup_stop_id',c.pickup_stop_id,'drop_stop_id',c.drop_stop_id,'notes',c.notes,
  'cars',coalesce((select jsonb_agg(jsonb_build_object('id',a.id,'identifier',a.identifier,
   'pickup_stop_id',a.pickup_stop_id,'drop_stop_id',a.drop_stop_id) order by a.identifier)
   from public.consignment_cars a where a.consignment_id=c.id),'[]')) order by c.created_at,c.id),'[]') into rows
 from public.consignments c where c.trip_id=t.id;
 result:=result||jsonb_build_object('consignments',rows,'linked_returns',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,
  'trip_number',r.trip_number,'load_kind',r.load_kind,'state',r.state) order by r.created_at)
  from public.trips r where r.return_of_trip_id=t.id and private.trip_access(t.business_id,r.id)),'[]'));
 return result||jsonb_build_object('totals',jsonb_build_object(
  'car_count',(select coalesce(sum(car_count),0) from public.consignments where trip_id=t.id and state<>'CANCELLED'),
  'customer_charge',(select coalesce(sum(customer_charge),0)::numeric(20,2)::text from public.consignments where trip_id=t.id and state<>'CANCELLED'),
  'commission',(select coalesce(sum(commission),0)::numeric(20,2)::text from public.consignments where trip_id=t.id and state<>'CANCELLED'),
  'owner_entitlement',(select coalesce(sum(owner_entitlement),0)::numeric(20,2)::text from public.consignments where trip_id=t.id and state<>'CANCELLED')));
end $$;

create function public.get_trip_detail(trip_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles; t public.trips;
begin
 actor:=private.current_staff();
 if actor.id is null or not private.trip_access(actor.business_id,trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into t from public.trips where id=trip_id and business_id=actor.business_id;
 return private.trip_payload(t.id)||jsonb_build_object('can_edit',t.state='DRAFT' and private.office_access(actor.business_id,t.origin_office_id)
  and (actor.role='ADMIN' or t.created_by=actor.auth_user_id));
end $$;

create function public.list_trips(search_text text default '',page_offset integer default 0,
 office_id uuid default null,vehicle_id uuid default null,trip_state text default null,
 date_from text default null,date_to text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles; start_date date; end_date date; result jsonb;
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if page_offset is null or page_offset<0 or search_text is null or length(search_text)>100
  or (trip_state is not null and trip_state not in ('DRAFT','DISPATCHED','ARRIVED','CANCELLED')) then raise exception 'INVALID_QUERY' using errcode='22023'; end if;
 if office_id is not null and not private.office_access(actor.business_id,office_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if date_from is not null then start_date:=public.parse_business_date(date_from); end if;
 if date_to is not null then end_date:=public.parse_business_date(date_to); end if;
 if start_date>end_date then raise exception 'INVALID_DATE_RANGE' using errcode='22023'; end if;
 select coalesce(jsonb_agg(x.row_data order by x.created_at desc,x.id),'[]') into result from (
  select t.id,t.created_at,jsonb_build_object('id',t.id,'trip_number',t.trip_number,'state',t.state,'load_kind',t.load_kind,
   'registration',v.registration,'owner_name',t.owner_snapshot->>'display_name',
   'origin_name',o.name,'destination_name',d.name,'planned_dispatch_date',t.planned_dispatch_date,
   'dispatch_date',t.dispatch_date,'arrival_date',t.arrival_date,'return_of_trip_id',t.return_of_trip_id,
   'car_count',(select coalesce(sum(car_count),0) from public.consignments where trip_id=t.id and state<>'CANCELLED')) row_data
  from public.trips t join public.vehicles v on v.id=t.vehicle_id join public.offices o on o.id=t.origin_office_id join public.offices d on d.id=t.destination_office_id
  where t.business_id=actor.business_id and private.trip_access(actor.business_id,t.id)
   and (office_id is null or office_id in(t.origin_office_id,t.destination_office_id))
   and (list_trips.vehicle_id is null or t.vehicle_id=list_trips.vehicle_id) and (trip_state is null or t.state=trip_state)
   and (start_date is null or coalesce(t.dispatch_date,t.planned_dispatch_date)>=start_date)
   and (end_date is null or coalesce(t.dispatch_date,t.planned_dispatch_date)<=end_date)
   and (search_text='' or concat_ws(' ',t.trip_number,v.registration,t.owner_snapshot->>'display_name') ilike '%'||search_text||'%'
    or exists(select 1 from public.consignments c join public.parties p on p.id=c.customer_id left join public.parties b on b.id=c.broker_id
     where c.trip_id=t.id and concat_ws(' ',p.display_name,p.code,b.display_name,b.code) ilike '%'||search_text||'%'))
   order by t.created_at desc,t.id limit 50 offset page_offset) x;
 return jsonb_build_object('scope',case when actor.role='ADMIN' then 'ALL_OFFICES' else 'ASSIGNED_OFFICES' end,'rows',result);
end $$;

create function private.trip_overlap_context(b uuid,target uuid,vehicle uuid,origin uuid,destination uuid,planned text,parent uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('target',target,'vehicle',vehicle,'origin',origin,'destination',destination,'planned',planned,'parent',parent,
  'overlaps',coalesce((select jsonb_agg(jsonb_build_object('id',id,'version',version) order by id)
   from public.trips where business_id=b and vehicle_id=vehicle and id<>target and state='DISPATCHED'),'[]'))
$$;
create function public.review_trip_overlap(target_id uuid,vehicle_id uuid,origin_office_id uuid,destination_office_id uuid,
 planned_dispatch_date text default null,return_of_trip_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; context jsonb; ticket uuid; visible jsonb; hidden boolean;
begin
 actor:=private.current_staff();
 if actor.id is null or not private.office_access(actor.business_id,origin_office_id)
  or exists(select 1 from public.trips where id=target_id and (business_id<>actor.business_id or not private.office_access(actor.business_id,public.trips.origin_office_id)))
  then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if target_id is null or not exists(select 1 from public.vehicles where id=vehicle_id and business_id=actor.business_id)
  then raise exception 'INVALID_VEHICLE' using errcode='22023'; end if;
 if planned_dispatch_date is not null then perform public.parse_business_date(planned_dispatch_date); end if;
 if return_of_trip_id is not null and not private.trip_access(actor.business_id,return_of_trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 context:=private.trip_overlap_context(actor.business_id,target_id,vehicle_id,origin_office_id,destination_office_id,planned_dispatch_date,return_of_trip_id);
 delete from private.trip_reviews where actor_id=actor.id and expires_at<now();
 insert into private.trip_reviews(business_id,actor_id,context,expires_at) values(actor.business_id,actor.id,context,now()+interval '10 minutes') returning token into ticket;
 select coalesce(jsonb_agg(jsonb_build_object('id',t.id,'trip_number',t.trip_number,'dispatch_date',t.dispatch_date) order by t.id),'[]') into visible
  from public.trips t where t.business_id=actor.business_id and t.vehicle_id=review_trip_overlap.vehicle_id and t.id<>target_id and t.state='DISPATCHED' and private.trip_access(actor.business_id,t.id);
 select exists(select 1 from public.trips t where t.business_id=actor.business_id and t.vehicle_id=review_trip_overlap.vehicle_id and t.id<>target_id and t.state='DISPATCHED' and not private.trip_access(actor.business_id,t.id)) into hidden;
 return jsonb_build_object('review_token',ticket,'requires_confirmation',jsonb_array_length(context->'overlaps')>0,'visible_trips',visible,'restricted_conflict',hidden);
end $$;

create function private.validate_stop_link(items jsonb,stop_id uuid,kind text) returns integer
language plpgsql immutable set search_path='' as $$
declare pos integer;
begin
 if stop_id is null then return null; end if;
 select ordinal::integer into pos from jsonb_array_elements(items) with ordinality s(row_data,ordinal)
  where (row_data->>'id')::uuid=stop_id and row_data->>'kind'=kind;
 if pos is null then raise exception 'INVALID_STOP_LINK' using errcode='22023'; end if;
 return pos;
end $$;

create function public.save_trip(target_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; old public.trips; command_body jsonb; cached private.trip_requests;
 vehicle uuid; driver uuid; origin uuid; destination uuid; route uuid; parent uuid; planned date; defaults jsonb;
 before_data jsonb; result jsonb; context jsonb; review private.trip_reviews; confirmed boolean:=false; sequence_number bigint;
 stop_ids uuid[]; consignment_ids uuid[]; car_ids uuid[]; item jsonb; car jsonb; quote jsonb; pos integer;
 pickup uuid; dropoff uuid; pickup_pos integer; drop_pos integer; customer uuid; broker uuid; n integer;
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if target_id is null or request_id is null or expected_version is null or expected_version<0 or jsonb_typeof(payload) is distinct from 'object'
  or length(payload::text)>250000 then raise exception 'INVALID_COMMAND' using errcode='22023'; end if;
 if exists(select 1 from jsonb_object_keys(payload) k where k not in ('vehicle_id','driver_id','origin_office_id','destination_office_id','route_id',
  'planned_dispatch_date','load_kind','return_of_trip_id','notes','stops','consignments','overlap_confirmed','overlap_reason','review_token','reason'))
  then raise exception 'INVALID_FIELDS' using errcode='22023'; end if;
 vehicle:=(payload->>'vehicle_id')::uuid; driver:=(payload->>'driver_id')::uuid; origin:=(payload->>'origin_office_id')::uuid;
 destination:=(payload->>'destination_office_id')::uuid; route:=(payload->>'route_id')::uuid; parent:=(payload->>'return_of_trip_id')::uuid;
 if not private.office_access(actor.business_id,origin) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended('trip-vehicle:'||coalesce(vehicle::text,''),0));
 actor:=private.current_staff();
 if actor.id is null or not private.office_access(actor.business_id,origin) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into old from public.trips where id=target_id for update;
 if old.id is not null and (old.business_id<>actor.business_id or not private.office_access(actor.business_id,old.origin_office_id)
   or (actor.role<>'ADMIN' and old.created_by is distinct from actor.auth_user_id)) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 command_body:=jsonb_build_object('id',target_id,'version',expected_version,'payload',payload);
 select * into cached from private.trip_requests r where r.business_id=actor.business_id and r.request_id=save_trip.request_id;
 if found then
  if cached.actor_id<>actor.id or cached.command<>command_body then raise exception 'REQUEST_ID_CONFLICT' using errcode='PT409'; end if;
  return cached.result;
 end if;
 if (old.id is null and expected_version<>0) or (old.id is not null and old.version<>expected_version) then raise exception 'VERSION_CONFLICT' using errcode='PT409'; end if;
 if old.id is not null and (old.state<>'DRAFT' or exists(select 1 from public.financial_events where trip_id=old.id)
   or exists(select 1 from public.issued_documents where trip_id=old.id)) then raise exception 'DRAFT_EDIT_UNAVAILABLE' using errcode='22023'; end if;
 if old.id is not null and coalesce(length(btrim(payload->>'reason')),0) not between 1 and 500 then raise exception 'EDIT_REASON_REQUIRED' using errcode='22023'; end if;
 if (select count(*) from public.offices where id in(origin,destination) and business_id=actor.business_id and archived_at is null)<>2
   then raise exception 'ACTIVE_OFFICES_REQUIRED' using errcode='22023'; end if;
 if payload->>'planned_dispatch_date' is not null then planned:=public.parse_business_date(payload->>'planned_dispatch_date'); end if;
 if payload->>'load_kind' is null or payload->>'load_kind' not in ('LOADED','EMPTY') or length(coalesce(payload->>'notes',''))>2000 then raise exception 'INVALID_TRIP' using errcode='22023'; end if;
 if old.id is null or old.vehicle_id is distinct from vehicle then
  defaults:=public.get_trip_defaults(vehicle,route,origin,destination);
 else
  defaults:=jsonb_build_object('owner_id',old.owner_id,'owner_snapshot',old.owner_snapshot,'route_snapshot',old.route_snapshot);
  if old.route_id is distinct from route then
   if route is not null and not exists(select 1 from public.routes where id=route and business_id=actor.business_id and archived_at is null) then raise exception 'ACTIVE_ROUTE_REQUIRED' using errcode='22023'; end if;
   defaults:=defaults||jsonb_build_object('route_snapshot',coalesce((select private.master_payload('ROUTE',to_jsonb(r),false) from public.routes r where id=route),'{}'));
  end if;
 end if;
 if driver is not null and (old.id is null or old.driver_id is distinct from driver) and not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id
  where p.id=driver and p.business_id=actor.business_id and p.archived_at is null and r.role='DRIVER' and r.archived_at is null) then raise exception 'ACTIVE_DRIVER_REQUIRED' using errcode='22023'; end if;
 if parent is not null then
  if parent=target_id or not exists(select 1 from public.trips t where t.id=parent and t.business_id=actor.business_id and t.vehicle_id=vehicle
   and t.origin_office_id=destination and t.destination_office_id=origin and t.state<>'CANCELLED' and private.trip_access(actor.business_id,t.id))
   then raise exception 'INVALID_RETURN_LINK' using errcode='22023'; end if;
  if exists(with recursive chain as(select t.id,t.return_of_trip_id from public.trips t where t.id=parent
   union select t.id,t.return_of_trip_id from public.trips t join chain c on t.id=c.return_of_trip_id) select 1 from chain where id=target_id)
   then raise exception 'RETURN_CYCLE' using errcode='22023'; end if;
 end if;
 if old.id is not null and exists(select 1 from public.trips r where r.return_of_trip_id=old.id and (r.vehicle_id<>vehicle or r.origin_office_id<>destination or r.destination_office_id<>origin))
  then raise exception 'RETURN_DEPENDENCY' using errcode='22023'; end if;
 context:=private.trip_overlap_context(actor.business_id,target_id,vehicle,origin,destination,payload->>'planned_dispatch_date',parent);
 if jsonb_array_length(context->'overlaps')>0 then
  select * into review from private.trip_reviews where token=(payload->>'review_token')::uuid and actor_id=actor.id and business_id=actor.business_id;
  if review.token is null or review.expires_at<now() or payload->'overlap_confirmed' is distinct from 'true'::jsonb
   or coalesce(length(btrim(payload->>'overlap_reason')),0) not between 1 and 500 then raise exception 'OVERLAP_CONFIRMATION_REQUIRED' using errcode='22023'; end if;
  if review.context<>context then raise exception 'OVERLAP_REVIEW_CHANGED' using errcode='PT409'; end if;
  confirmed:=true;
 end if;
 if jsonb_typeof(payload->'stops') is distinct from 'array' or jsonb_typeof(payload->'consignments') is distinct from 'array'
  or jsonb_array_length(payload->'stops')>200 or jsonb_array_length(payload->'consignments')>100
  or (payload->>'load_kind'='EMPTY' and jsonb_array_length(payload->'consignments')<>0)
  or (payload->>'load_kind'='LOADED' and jsonb_array_length(payload->'consignments')=0) then raise exception 'INVALID_LOAD' using errcode='22023'; end if;
 stop_ids:=array(select (s->>'id')::uuid from jsonb_array_elements(payload->'stops') s);
 consignment_ids:=array(select (c->>'id')::uuid from jsonb_array_elements(payload->'consignments') c);
 car_ids:=array(select (a->>'id')::uuid from jsonb_array_elements(payload->'consignments') c cross join lateral jsonb_array_elements(c->'cars') a);
 if array_position(stop_ids,null) is not null or array_position(consignment_ids,null) is not null or array_position(car_ids,null) is not null
  or cardinality(stop_ids)<>(select count(distinct x) from unnest(stop_ids) x)
  or cardinality(consignment_ids)<>(select count(distinct x) from unnest(consignment_ids) x)
  or cardinality(car_ids)<>(select count(distinct x) from unnest(car_ids) x) or cardinality(car_ids)>1000
  or exists(select 1 from public.stops where id=any(stop_ids) and trip_id<>target_id)
  or exists(select 1 from public.consignments where id=any(consignment_ids) and trip_id<>target_id)
  or exists(select 1 from public.consignment_cars where id=any(car_ids) and trip_id<>target_id) then raise exception 'INVALID_CHILD_ID' using errcode='22023'; end if;
 if old.id is not null then before_data:=private.trip_payload(old.id); end if;
 delete from public.consignment_cars where trip_id=target_id and not(id=any(car_ids));
 delete from public.consignments where trip_id=target_id and not(id=any(consignment_ids));
 if old.id is null then
  insert into private.trip_sequences values(actor.business_id,1) on conflict(business_id) do update set last_number=private.trip_sequences.last_number+1 returning last_number into sequence_number;
  insert into public.trips(id,business_id,trip_number,vehicle_id,driver_id,origin_office_id,destination_office_id,route_id,owner_id,owner_snapshot,route_snapshot,
   load_kind,planned_dispatch_date,return_of_trip_id,notes,overlap_confirmed,overlap_reason,created_by)
  values(target_id,actor.business_id,'TRP-'||lpad(sequence_number::text,greatest(6,length(sequence_number::text)),'0'),vehicle,driver,origin,destination,route,
   (defaults->>'owner_id')::uuid,defaults->'owner_snapshot',defaults->'route_snapshot',payload->>'load_kind',planned,parent,coalesce(payload->>'notes',''),confirmed,
   case when confirmed then btrim(payload->>'overlap_reason') end,actor.auth_user_id);
 else
  update public.trips set vehicle_id=vehicle,driver_id=driver,origin_office_id=origin,destination_office_id=destination,route_id=route,
   owner_id=(defaults->>'owner_id')::uuid,owner_snapshot=defaults->'owner_snapshot',route_snapshot=defaults->'route_snapshot',load_kind=payload->>'load_kind',
   planned_dispatch_date=planned,return_of_trip_id=parent,notes=coalesce(payload->>'notes',''),overlap_confirmed=confirmed,
   overlap_reason=case when confirmed then btrim(payload->>'overlap_reason') end,version=version+1 where id=target_id;
 end if;
 -- Temporarily move existing positions out of the way to permit reorder under UNIQUE.
 update public.stops set position=position+1000000,version=version+1 where trip_id=target_id;
 pos:=0;
 for item in select * from jsonb_array_elements(payload->'stops') loop
  pos:=pos+1;
  if jsonb_typeof(item) is distinct from 'object' or exists(select 1 from jsonb_object_keys(item) k where k not in ('id','kind','address'))
   or coalesce(length(btrim(item->>'address')),0) not between 1 and 500 or item->>'kind' is null or item->>'kind' not in ('PICKUP','DROP','OTHER')
   then raise exception 'INVALID_STOP' using errcode='22023'; end if;
  insert into public.stops(id,business_id,trip_id,position,kind,address,created_by) values((item->>'id')::uuid,actor.business_id,target_id,pos,item->>'kind',btrim(item->>'address'),actor.auth_user_id)
  on conflict(id) do update set position=excluded.position,kind=excluded.kind,address=excluded.address,version=public.stops.version+1;
 end loop;
 for item in select * from jsonb_array_elements(payload->'consignments') loop
  if jsonb_typeof(item) is distinct from 'object' or exists(select 1 from jsonb_object_keys(item) k where k not in ('id','customer_id','broker_id','car_count','quoted_amount','quote_mode',
    'commission_method','commission_value','pickup_stop_id','drop_stop_id','notes','cars','commission','customer_charge','owner_entitlement'))
   or jsonb_typeof(item->'cars') is distinct from 'array' or jsonb_typeof(item->'car_count') is distinct from 'number'
   or item->>'car_count' !~ '^[1-9][0-9]{0,5}$' or jsonb_typeof(item->'quoted_amount') is distinct from 'string'
   or jsonb_typeof(item->'commission_value') is distinct from 'string' or length(coalesce(item->>'notes',''))>2000 then raise exception 'INVALID_CONSIGNMENT' using errcode='22023'; end if;
  customer:=(item->>'customer_id')::uuid; broker:=(item->>'broker_id')::uuid; n:=(item->>'car_count')::integer;
  if not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id where p.id=customer and p.business_id=actor.business_id and r.role='CUSTOMER'
    and ((p.archived_at is null and r.archived_at is null) or exists(select 1 from public.consignments c where c.id=(item->>'id')::uuid and c.trip_id=target_id and c.customer_id=customer)))
   or (broker is not null and not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id where p.id=broker and p.business_id=actor.business_id and r.role='BROKER'
    and ((p.archived_at is null and r.archived_at is null) or exists(select 1 from public.consignments c where c.id=(item->>'id')::uuid and c.trip_id=target_id and c.broker_id=broker))))
   then raise exception 'ACTIVE_PARTY_ROLE_REQUIRED' using errcode='22023'; end if;
  quote:=public.calculate_quote(item->>'quoted_amount',item->>'quote_mode',item->>'commission_method',item->>'commission_value',broker is not null);
  pickup:=(item->>'pickup_stop_id')::uuid; dropoff:=(item->>'drop_stop_id')::uuid;
  pickup_pos:=private.validate_stop_link(payload->'stops',pickup,'PICKUP'); drop_pos:=private.validate_stop_link(payload->'stops',dropoff,'DROP');
  if pickup_pos>=drop_pos or jsonb_array_length(item->'cars')>n then raise exception 'INVALID_CAR_STOPS' using errcode='22023'; end if;
  insert into public.consignments(id,business_id,trip_id,customer_id,broker_id,car_count,quoted_amount,quote_mode,commission_method,commission_value,
    commission,customer_charge,owner_entitlement,pickup_stop_id,drop_stop_id,notes,created_by)
  values((item->>'id')::uuid,actor.business_id,target_id,customer,broker,n,(quote->>'quoted_amount')::numeric,item->>'quote_mode',item->>'commission_method',
    (quote->>'commission_value')::numeric,0,0,0,pickup,dropoff,coalesce(item->>'notes',''),actor.auth_user_id)
  on conflict(id) do update set customer_id=excluded.customer_id,broker_id=excluded.broker_id,car_count=excluded.car_count,quoted_amount=excluded.quoted_amount,
   quote_mode=excluded.quote_mode,commission_method=excluded.commission_method,commission_value=excluded.commission_value,
   pickup_stop_id=excluded.pickup_stop_id,drop_stop_id=excluded.drop_stop_id,notes=excluded.notes,version=public.consignments.version+1;
  for car in select * from jsonb_array_elements(item->'cars') loop
   if jsonb_typeof(car) is distinct from 'object' or exists(select 1 from jsonb_object_keys(car) k where k not in ('id','identifier','pickup_stop_id','drop_stop_id'))
    or coalesce(length(btrim(car->>'identifier')),0) not between 1 and 150
    or exists(select 1 from public.consignment_cars where id=(car->>'id')::uuid and consignment_id<>(item->>'id')::uuid) then raise exception 'INVALID_CAR' using errcode='22023'; end if;
   pickup:=coalesce((car->>'pickup_stop_id')::uuid,(item->>'pickup_stop_id')::uuid); dropoff:=coalesce((car->>'drop_stop_id')::uuid,(item->>'drop_stop_id')::uuid);
   pickup_pos:=private.validate_stop_link(payload->'stops',pickup,'PICKUP'); drop_pos:=private.validate_stop_link(payload->'stops',dropoff,'DROP');
   if pickup_pos>=drop_pos then raise exception 'INVALID_CAR_STOPS' using errcode='22023'; end if;
   insert into public.consignment_cars(id,business_id,trip_id,consignment_id,identifier,pickup_stop_id,drop_stop_id,created_by)
   values((car->>'id')::uuid,actor.business_id,target_id,(item->>'id')::uuid,btrim(car->>'identifier'),pickup,dropoff,actor.auth_user_id)
   on conflict(id) do update set identifier=excluded.identifier,pickup_stop_id=excluded.pickup_stop_id,drop_stop_id=excluded.drop_stop_id,version=public.consignment_cars.version+1;
  end loop;
 end loop;
 delete from public.stops where trip_id=target_id and not(id=any(stop_ids));
 result:=public.get_trip_detail(target_id);
 insert into public.audit_events(business_id,actor_id,office_id,trip_id,record_id,record_type,action,reason,before_data,after_data)
  values(actor.business_id,actor.id,origin,target_id,target_id,'TRIP',case when old.id is null then 'CREATE_DRAFT' else 'EDIT_DRAFT' end,
   case when old.id is null then null else btrim(payload->>'reason') end,before_data,result);
 insert into private.trip_requests values(actor.business_id,request_id,actor.id,command_body,result);
 return result;
end $$;

grant create on schema public,private to carrier_security;
alter function private.trip_payload(uuid) owner to carrier_security;
alter function private.trip_overlap_context(uuid,uuid,uuid,uuid,uuid,text,uuid) owner to carrier_security;
alter function private.validate_stop_link(jsonb,uuid,text) owner to carrier_security;
alter function public.get_trip_detail(uuid) owner to carrier_security;
alter function public.list_trips(text,integer,uuid,uuid,text,text,text) owner to carrier_security;
alter function public.review_trip_overlap(uuid,uuid,uuid,uuid,text,uuid) owner to carrier_security;
alter function public.save_trip(uuid,uuid,integer,jsonb) owner to carrier_security;
revoke all on function private.trip_payload(uuid),private.trip_overlap_context(uuid,uuid,uuid,uuid,uuid,text,uuid),private.validate_stop_link(jsonb,uuid,text) from public,anon,authenticated;
revoke all on function public.get_trip_detail(uuid),public.list_trips(text,integer,uuid,uuid,text,text,text),
 public.review_trip_overlap(uuid,uuid,uuid,uuid,text,uuid),public.save_trip(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.get_trip_detail(uuid),public.list_trips(text,integer,uuid,uuid,text,text,text),
 public.review_trip_overlap(uuid,uuid,uuid,uuid,text,uuid),public.save_trip(uuid,uuid,integer,jsonb) to authenticated;
revoke create on schema public,private from carrier_security;
revoke carrier_security from postgres;
