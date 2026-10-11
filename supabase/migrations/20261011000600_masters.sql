-- T04: administrator commands; no direct client master writes.
alter table public.businesses add column setup_completed boolean not null default false;
alter table public.party_roles add column archived_at timestamptz;
create table private.master_requests (
 business_id uuid not null references public.businesses(id), request_id uuid not null,
 actor_id uuid not null references public.staff_profiles(id), command jsonb not null,
 result jsonb not null, primary key (business_id, request_id)
);
grant carrier_security to postgres;
grant select, insert on private.master_requests to carrier_security;
grant insert, update on public.businesses, public.offices, public.parties,
 public.party_roles, public.vehicles, public.routes, public.expense_categories to carrier_security;

create function private.master_table(kind text) returns text
language sql immutable set search_path = '' as $$
 select case kind when 'COMPANY' then 'businesses' when 'OFFICE' then 'offices'
 when 'PARTY' then 'parties' when 'VEHICLE' then 'vehicles' when 'ROUTE' then 'routes'
 when 'CATEGORY' then 'expense_categories' else null end
$$;

-- Explicit public contracts: no created_by/Auth IDs or accidental new columns.
create function private.master_payload(kind text, row_data jsonb, administrator boolean)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare result jsonb; keys text[];
begin
 keys := case kind
 when 'COMPANY' then array['id','name','contact_details','setup_completed','version']
 when 'OFFICE' then array['id','code','name','archived_at','version']
 when 'PARTY' then array['id','code','display_name','contact_details','archived_at','version']
 when 'VEHICLE' then array['id','registration','current_owner_id','default_driver_id','archived_at','version']
 when 'ROUTE' then array['id','code','origin_label','destination_label','suggested_fare','archived_at','version']
 when 'CATEGORY' then array['id','name','archived_at','version'] end;
 select jsonb_object_agg(k, row_data->k) into result from unnest(keys) k;
 if kind = 'ROUTE' then
  result := jsonb_set(result, '{suggested_fare}', coalesce(to_jsonb((row_data->>'suggested_fare')::numeric(18,2)::text),'null'::jsonb));
 end if;
 if kind = 'PARTY' then
  result := result || jsonb_build_object('roles', coalesce((select jsonb_agg(role order by role)
   from public.party_roles where party_id=(row_data->>'id')::uuid and archived_at is null),'[]'::jsonb));
 end if;
 if kind='VEHICLE' then
  result := result || jsonb_build_object('current_owner_name',(select display_name from public.parties where id=(row_data->>'current_owner_id')::uuid),
    'default_driver_name',(select display_name from public.parties where id=(row_data->>'default_driver_id')::uuid));
 end if;
 if not administrator then
  result := result - array['contact_details','version','archived_at','setup_completed'];
 end if;
 return result;
end $$;

create function public.list_master_records(kind text, search_text text default '', page_offset integer default 0,
 include_archived boolean default false) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare actor public.staff_profiles; table_name text; result jsonb; company_filter text;
begin
 actor := private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 table_name := private.master_table(kind);
 if table_name is null or page_offset is null or page_offset < 0 or length(search_text)>100 then
  raise exception 'INVALID_MASTER_QUERY' using errcode='22023'; end if;
 if actor.role <> 'ADMIN' and (include_archived or kind='COMPANY') then
  raise exception 'FORBIDDEN' using errcode='42501'; end if;
 company_filter := case when kind='COMPANY' then 'r.id=$1' else 'r.business_id=$1' end;
 -- Staff receive choices only. Offices are destinations, not permission grants.
 execute format('select coalesce(jsonb_agg(private.master_payload($2,x.data,$3)),''[]''::jsonb) from
  (select to_jsonb(r) data from public.%I r where %s
   and ($4 or not(to_jsonb(r) ? ''archived_at'') or to_jsonb(r)->>''archived_at'' is null)
   and ($5='''' or concat_ws('' '',to_jsonb(r)->>''name'',to_jsonb(r)->>''display_name'',to_jsonb(r)->>''registration'',to_jsonb(r)->>''code'') ilike ''%%'' || $5 || ''%%'')
   order by coalesce(to_jsonb(r)->>''name'',to_jsonb(r)->>''display_name'',to_jsonb(r)->>''registration'',to_jsonb(r)->>''code''),r.id limit 50 offset $6) x', table_name, company_filter)
 into result using actor.business_id,kind,actor.role='ADMIN',include_archived,coalesce(search_text,''),page_offset;
 return result;
end $$;

create function public.save_master_record(kind text, target_id uuid, request_id uuid,
 expected_version integer, payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor public.staff_profiles; table_name text; allowed text[]; fields text[]; k text;
 before_row jsonb; before_contract jsonb; after_row jsonb; values_row jsonb; command_body jsonb; saved private.master_requests;
 column_names text; assignments text; role_name text; archived boolean;
begin
 actor := private.current_staff();
 if actor.id is null or actor.role <> 'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if target_id is null or request_id is null or expected_version is null or expected_version<0
  or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>10000 then raise exception 'INVALID_COMMAND' using errcode='22023'; end if;
 table_name := private.master_table(kind);
 allowed := case kind
 when 'COMPANY' then array['name','contact_details']
 when 'OFFICE' then array['code','name','archived']
 when 'PARTY' then array['code','display_name','contact_details','roles','archived']
 when 'VEHICLE' then array['registration','current_owner_id','default_driver_id','archived']
 when 'ROUTE' then array['code','origin_label','destination_label','suggested_fare','archived']
 when 'CATEGORY' then array['name','archived'] end;
 if table_name is null or exists(select 1 from jsonb_object_keys(payload) key where not(key=any(allowed)))
  then raise exception 'INVALID_FIELDS' using errcode='22023'; end if;
 -- Serialize all master edits and retries within this business; recheck live authority.
 -- Share the account-management lock so an administrator demotion cannot race this check.
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));
 actor := private.current_staff();
 if actor.id is null or actor.role <> 'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 command_body := jsonb_build_object('kind',kind,'id',target_id,'version',expected_version,'payload',payload);
 select * into saved from private.master_requests r where r.business_id=actor.business_id and r.request_id=save_master_record.request_id;
 if found then
  if saved.actor_id<>actor.id or saved.command<>command_body then raise exception 'REQUEST_ID_CONFLICT' using errcode='PT409'; end if;
  return saved.result;
 end if;
 if kind='COMPANY' and target_id<>actor.business_id then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 execute format('select to_jsonb(r) from public.%I r where id=$1 and %s for update',table_name,
  case when kind='COMPANY' then 'id=$2' else 'business_id=$2' end) into before_row using target_id,actor.business_id;
 if (before_row is null and expected_version<>0) or (before_row is not null and (before_row->>'version')::integer<>expected_version)
  or (kind='COMPANY' and before_row is null) then raise exception 'VERSION_CONFLICT' using errcode='PT409'; end if;
 before_contract := case when before_row is null then null else private.master_payload(kind,before_row,true) end;
 values_row := payload - array['roles','archived'];
 foreach k in array array['name','code','display_name','registration','origin_label','destination_label'] loop
  if values_row ? k then
   if jsonb_typeof(values_row->k)<>'string' or length(btrim(values_row->>k)) not between 1 and 150 then
    raise exception 'INVALID_LABEL' using errcode='22023'; end if;
   values_row := jsonb_set(values_row,array[k],to_jsonb(btrim(values_row->>k)));
  end if;
 end loop;
 if values_row ? 'contact_details' then
  if jsonb_typeof(values_row->'contact_details')<>'object' or exists(select 1 from jsonb_each(values_row->'contact_details') e
    where e.key not in ('address','phone','email','logo_url') or jsonb_typeof(e.value)<>'string' or length(e.value#>>'{}')>500)
   or (coalesce(values_row#>>'{contact_details,logo_url}','')<>'' and values_row#>>'{contact_details,logo_url}' !~ '^https://[^[:space:]]+$')
   then raise exception 'INVALID_CONTACTS' using errcode='22023'; end if;
 end if;
 if kind='ROUTE' and values_row ? 'suggested_fare' and values_row->'suggested_fare'<>'null'::jsonb then
  if jsonb_typeof(values_row->'suggested_fare')<>'string' then raise exception 'DECIMAL_STRING_REQUIRED' using errcode='22023'; end if;
  values_row := jsonb_set(values_row,'{suggested_fare}',to_jsonb(public.parse_money(values_row->>'suggested_fare')));
 end if;
 if payload ? 'archived' then
  if jsonb_typeof(payload->'archived')<>'boolean' then raise exception 'INVALID_ARCHIVE' using errcode='22023'; end if;
  archived := (payload->>'archived')::boolean;
  values_row := values_row || jsonb_build_object('archived_at',case when archived then coalesce(before_row->>'archived_at',now()::text) end);
 end if;
 if kind='COMPANY' then values_row := values_row || '{"setup_completed":true}'::jsonb; end if;
 if kind='PARTY' then
  if jsonb_typeof(payload->'roles') is distinct from 'array' or jsonb_array_length(payload->'roles')=0
   or exists(select 1 from jsonb_array_elements(payload->'roles') r where jsonb_typeof(r)<>'string' or r#>>'{}' not in ('OWNER','CUSTOMER','BROKER','DRIVER','BUSINESS','OTHER'))
   then raise exception 'INVALID_ROLES' using errcode='22023'; end if;
 end if;
 if kind='VEHICLE' and coalesce(values_row->>'archived_at',case when not(values_row ? 'archived_at') then before_row->>'archived_at' end) is null then
  if not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id
   where p.business_id=actor.business_id and p.id=coalesce(values_row->>'current_owner_id',before_row->>'current_owner_id')::uuid
    and p.archived_at is null and r.role='OWNER' and r.archived_at is null) then raise exception 'ACTIVE_OWNER_REQUIRED' using errcode='22023'; end if;
  if coalesce(values_row->>'default_driver_id',case when not(values_row ? 'default_driver_id') then before_row->>'default_driver_id' end) is not null
   and not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id
    where p.business_id=actor.business_id and p.id=coalesce(values_row->>'default_driver_id',before_row->>'default_driver_id')::uuid
     and p.archived_at is null and r.role='DRIVER' and r.archived_at is null) then raise exception 'ACTIVE_DRIVER_REQUIRED' using errcode='22023'; end if;
 end if;
 fields := array(select jsonb_object_keys(values_row));
 if before_row is null then
  values_row := values_row || jsonb_build_object('id',target_id,'business_id',actor.business_id,'created_by',actor.auth_user_id,'version',1);
  fields := array(select jsonb_object_keys(values_row));
  select string_agg(format('%I',f),',') into column_names from unnest(fields) f;
  execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I,$1) returning to_jsonb(%I.*)',
    table_name,column_names,column_names,table_name,table_name) into after_row using values_row;
 else
  values_row := before_row || values_row || jsonb_build_object('version',expected_version+1);
  fields := array_append(fields,'version');
  select string_agg(format('%I=x.%I',f,f),',') into assignments from unnest(fields) f;
  execute format('update public.%I r set %s from jsonb_populate_record(null::public.%I,$1) x where r.id=$2 returning to_jsonb(r)',
    table_name,assignments,table_name) into after_row using values_row,target_id;
 end if;
 if kind='PARTY' then
  -- Archive roles rather than deleting referenced historical role links.
  update public.party_roles set archived_at=now(),version=version+1 where party_id=target_id and archived_at is null
   and not (payload->'roles' ? role);
  for role_name in select distinct jsonb_array_elements_text(payload->'roles') loop
   insert into public.party_roles(business_id,party_id,role,created_by) values(actor.business_id,target_id,role_name,actor.auth_user_id)
   on conflict(business_id,party_id,role) do update set archived_at=null,version=public.party_roles.version+1;
  end loop;
 end if;
 insert into public.audit_events(business_id,actor_id,record_id,record_type,action,before_data,after_data)
  values(actor.business_id,actor.id,target_id,kind,case when before_row is null then 'CREATE' else 'UPDATE' end,
   before_contract,private.master_payload(kind,after_row,true));
 after_row := private.master_payload(kind,after_row,true);
 insert into private.master_requests values(actor.business_id,request_id,actor.id,command_body,after_row);
 return after_row;
end $$;

-- Issuance must call this inside its eventual T13 transaction, not rely on a UI check.
create function public.require_document_setup() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare actor public.staff_profiles; company public.businesses;
begin
 actor := private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select * into company from public.businesses where id=actor.business_id;
 if not company.setup_completed or btrim(company.name)='' or btrim(actor.display_name)='' then
  raise exception 'COMPANY_SETUP_REQUIRED' using errcode='22023'; end if;
 return jsonb_build_object('company',jsonb_build_object('name',company.name,'contact_details',company.contact_details),
  'issuer',jsonb_build_object('id',actor.id,'display_name',actor.display_name));
end $$;

-- T05 uses this same server contract to capture defaults once, after explicit fare review.
create function public.get_trip_defaults(vehicle_id uuid, route_id uuid, origin_office_id uuid, destination_office_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor public.staff_profiles; vehicle public.vehicles; owner public.parties; route public.routes;
begin
 actor := private.current_staff();
 if actor.id is null or not private.office_access(actor.business_id,origin_office_id) then
  raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if origin_office_id=destination_office_id or (select count(*) from public.offices where business_id=actor.business_id
   and id in (origin_office_id,destination_office_id) and archived_at is null)<>2 then raise exception 'ACTIVE_OFFICES_REQUIRED' using errcode='22023'; end if;
 select * into vehicle from public.vehicles v where v.id=vehicle_id and business_id=actor.business_id and archived_at is null;
 select * into owner from public.parties p where p.id=vehicle.current_owner_id and business_id=actor.business_id and archived_at is null;
 if vehicle.id is null or owner.id is null or not exists(select 1 from public.party_roles where party_id=owner.id and role='OWNER' and archived_at is null)
  then raise exception 'ACTIVE_VEHICLE_OWNER_REQUIRED' using errcode='22023'; end if;
 if vehicle.default_driver_id is not null and not exists(select 1 from public.parties p join public.party_roles r on r.party_id=p.id
   where p.id=vehicle.default_driver_id and p.archived_at is null and r.role='DRIVER' and r.archived_at is null) then
  raise exception 'ACTIVE_DRIVER_REQUIRED' using errcode='22023'; end if;
 if route_id is not null then
  select * into route from public.routes r where r.id=route_id and business_id=actor.business_id and archived_at is null;
  if route.id is null then raise exception 'ACTIVE_ROUTE_REQUIRED' using errcode='22023'; end if;
 end if;
 return jsonb_build_object('vehicle_id',vehicle.id,'driver_id',vehicle.default_driver_id,'owner_id',owner.id,
  'owner_snapshot',jsonb_build_object('id',owner.id,'display_name',owner.display_name,'code',owner.code),
  'route_id',route.id,'route_snapshot',case when route.id is null then '{}'::jsonb else private.master_payload('ROUTE',to_jsonb(route),false) end,
  'suggested_fare',case when route.suggested_fare is null then null else route.suggested_fare::text end);
end $$;

grant create on schema public,private to carrier_security;
alter function private.master_table(text) owner to carrier_security;
alter function private.master_payload(text,jsonb,boolean) owner to carrier_security;
alter function public.list_master_records(text,text,integer,boolean) owner to carrier_security;
alter function public.save_master_record(text,uuid,uuid,integer,jsonb) owner to carrier_security;
alter function public.require_document_setup() owner to carrier_security;
alter function public.get_trip_defaults(uuid,uuid,uuid,uuid) owner to carrier_security;
revoke all on function private.master_table(text), private.master_payload(text,jsonb,boolean) from public,anon,authenticated;
revoke all on function public.list_master_records(text,text,integer,boolean),public.save_master_record(text,uuid,uuid,integer,jsonb),
 public.require_document_setup(),public.get_trip_defaults(uuid,uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function public.list_master_records(text,text,integer,boolean),public.save_master_record(text,uuid,uuid,integer,jsonb),
 public.require_document_setup(),public.get_trip_defaults(uuid,uuid,uuid,uuid) to authenticated;
grant execute on function public.parse_money(text) to carrier_security;
revoke create on schema public,private from carrier_security;
revoke carrier_security from postgres;
