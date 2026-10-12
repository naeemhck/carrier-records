
-- T15: new records only, reviewed atomic imports. No journal upload.
grant carrier_security to postgres;
grant create on schema public,private to carrier_security;
alter table public.expense_categories add column code text generated always as ('CAT-'||id::text) stored;
alter table public.expense_categories add unique(business_id,code);
create table private.import_reviews (
 business_id uuid not null references public.businesses(id), batch_id uuid not null,
 actor_id uuid not null references public.staff_profiles(id), command jsonb not null,
 review_token uuid not null default gen_random_uuid(), fingerprint text not null,
 preview jsonb not null, expires_at timestamptz not null default now()+interval '30 minutes',
 result jsonb, primary key(business_id,batch_id)
);
create table private.import_expense_drafts (
 id uuid primary key, business_id uuid not null references public.businesses(id),
 actor_id uuid not null references public.staff_profiles(id), office_id uuid not null references public.offices(id),
 trip_id uuid references public.trips(id), payload jsonb not null, version integer not null default 1,
 result jsonb, request_id uuid, confirmed_actor_id uuid references public.staff_profiles(id), confirmed_payload jsonb
);
alter table private.import_reviews enable row level security;
alter table private.import_expense_drafts enable row level security;
create policy import_owner on private.import_reviews to carrier_security using(true) with check(true);
create policy import_owner on private.import_expense_drafts to carrier_security using(true) with check(true);
grant select,insert,update on private.import_reviews,private.import_expense_drafts to carrier_security;
grant insert,update on public.import_batches,public.import_rows to carrier_security;
create function private.import_fields() returns jsonb language sql immutable set search_path='' as $$ select '{"PARTY": ["row_key", "code", "display_name", "roles", "address", "phone", "email"], "VEHICLE": ["row_key", "registration", "owner_code", "driver_code"], "ROUTE": ["row_key", "code", "origin_label", "destination_label", "suggested_fare"], "TRIP_DRAFT": ["row_key", "vehicle_code", "driver_code", "origin_code", "destination_code", "route_code", "load_kind", "planned_dispatch_date", "return_trip_code", "notes", "overlap_reason"], "CONSIGNMENT_DRAFT": ["row_key", "trip_key", "customer_code", "broker_code", "car_count", "quoted_amount", "quote_mode", "commission_method", "commission_value", "pickup_stop_key", "drop_stop_key", "notes"], "STOP": ["row_key", "trip_key", "position", "stop_kind", "address"], "CAR": ["row_key", "consignment_key", "identifier", "pickup_stop_key", "drop_stop_key"], "EXPENSE_DRAFT": ["row_key", "vehicle_code", "trip_code", "trip_key", "office_code", "category_code", "expense_date", "amount", "payer_code", "cost_bearer_code", "funding_source", "notes"]}'::jsonb $$;
create function public.get_import_templates() returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if (private.current_staff()).id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 return jsonb_build_object('template_version',1,'fields',private.import_fields(),'offices',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name)),'[]') from public.offices where private.office_access(business_id,id)),'category_codes',
 (select coalesce(jsonb_agg(jsonb_build_object('code',code,'name',name)),'[]') from public.expense_categories where business_id=(private.current_staff()).business_id and archived_at is null));
end $$;
create function private.import_id(batch uuid,key text) returns uuid language sql immutable set search_path='' as $$ select md5(batch::text||':'||key)::uuid $$;
create function private.import_reference(kind text,code text,party_role text default null) returns jsonb
language plpgsql stable set search_path='' as $$
declare a public.staff_profiles:=private.current_staff(); rows jsonb; tab text; field text;
begin
 if coalesce(btrim(code),'')='' then return null;end if;
 tab:=case kind when 'PARTY' then 'parties' when 'VEHICLE' then 'vehicles' when 'ROUTE' then 'routes' when 'OFFICE' then 'offices' when 'CATEGORY' then 'expense_categories' when 'TRIP' then 'trips' end;
 field:=case kind when 'VEHICLE' then 'registration' when 'TRIP' then 'trip_number' else 'code' end;
 if tab is null then raise exception 'INVALID_REFERENCE' using errcode='22023';end if;
 execute format('select coalesce(jsonb_agg(jsonb_build_object(''id'',r.id,''version'',r.version)),''[]''::jsonb) from public.%I r where business_id=$1 and lower(btrim(%I))=lower(btrim($2)) %s',tab,field,case when kind='TRIP' then 'and private.trip_access(business_id,id)' else 'and archived_at is null' end) into rows using a.business_id,code;
 if jsonb_array_length(rows)<>1 then raise exception 'REFERENCE_NOT_FOUND_OR_AMBIGUOUS' using errcode='22023';end if;
 if party_role is not null and not exists(select 1 from public.party_roles where party_id=(rows#>>'{0,id}')::uuid and role=party_role and archived_at is null) then raise exception 'PARTY_ROLE_REQUIRED' using errcode='22023';end if;
 return rows->0;
end $$;
create function private.import_refs(d jsonb) returns jsonb language plpgsql stable set search_path='' as $$
declare k text; kind text; role text; refs jsonb:='{}';begin
 foreach k in array array['owner_code','driver_code','customer_code','broker_code','payer_code','cost_bearer_code','vehicle_code','route_code','origin_code','destination_code','office_code','category_code','trip_code','return_trip_code'] loop
 if d ? k and coalesce(d->>k,'')<>'' then
 kind:=case when k in('vehicle_code') then 'VEHICLE' when k='route_code' then 'ROUTE' when k in('origin_code','destination_code','office_code') then 'OFFICE' when k='category_code' then 'CATEGORY' when k in('trip_code','return_trip_code') then 'TRIP' else 'PARTY' end;
 role:=case k when 'owner_code' then 'OWNER' when 'driver_code' then 'DRIVER' when 'customer_code' then 'CUSTOMER' when 'broker_code' then 'BROKER' end;
 refs:=refs||jsonb_build_object(k,private.import_reference(kind,d->>k,role));
 end if;end loop;return refs;end $$;
create function private.import_child(batch uuid,rows jsonb,key text,kind text,parent text default null) returns uuid
language plpgsql immutable set search_path='' as $$ declare r jsonb;begin
 if coalesce(key,'')='' then return null;end if;
 select x into r from jsonb_array_elements(rows) x where x->>'row_key'=key and x->>'kind'=kind;
 if r is null or (parent is not null and r#>>'{data,trip_key}' is distinct from parent) then raise exception 'UNKNOWN_OR_WRONG_PARENT_ROW_KEY' using errcode='22023';end if;
 return private.import_id(batch,key);end $$;
create function private.import_apply(command jsonb,allow_overlap boolean) returns jsonb
language plpgsql set search_path='' as $$
declare a public.staff_profiles:=private.current_staff(); batch uuid:=(command->>'batch_id')::uuid; rows jsonb:=command->'rows'; r jsonb; d jsonb; k text; refs jsonb; p jsonb; target uuid;
 errors jsonb:='[]'; preview jsonb:='[]'; prepared jsonb:='{}'; fingerprints jsonb:='[]'; warnings jsonb:='[]'; output jsonb; stops jsonb; consignments jsonb; review jsonb; child jsonb; quote jsonb; n integer; office uuid; trip uuid; owner uuid; kind text;
begin
 if exists(select 1 from jsonb_array_elements(rows) x group by x->>'row_key' having count(*)>1) then raise exception 'DUPLICATE_ROW_KEY' using errcode='22023';end if;
 -- One shared authority/master lock is acquired by the public envelopes before this routine.
 for r in select x from jsonb_array_elements(rows) x order by case x->>'kind' when 'PARTY' then 1 when 'VEHICLE' then 2 when 'ROUTE' then 3 when 'STOP' then 4 when 'CONSIGNMENT_DRAFT' then 5 when 'CAR' then 6 when 'TRIP_DRAFT' then 7 when 'EXPENSE_DRAFT' then 8 else 9 end loop
 begin
 kind:=r->>'kind';d:=r->'data';k:=r->>'row_key';target:=private.import_id(batch,k);
 if jsonb_typeof(r)<>'object' or exists(select 1 from jsonb_object_keys(r) f where f not in('kind','row_key','data')) or k is null or k !~ '^[A-Za-z0-9_-]{1,64}$' or jsonb_typeof(d) is distinct from 'object' or kind is null or not(private.import_fields() ? kind)
 or exists(select 1 from jsonb_each(d) e where jsonb_typeof(e.value)<>'string' or length(e.value#>>'{}')>2000 or not((private.import_fields()->kind) ? e.key) or e.key='row_key' or e.value#>>'{}' ~ '^\s*[=+@]') then raise exception 'INVALID_FIELDS_OR_FORMULA' using errcode='22023';end if;
 if kind in('PARTY','VEHICLE','ROUTE') and a.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if (kind in('STOP','CONSIGNMENT_DRAFT') and coalesce(d->>'trip_key','')='') or (kind='CAR' and (coalesce(d->>'consignment_key','')='' or length(btrim(coalesce(d->>'identifier',''))) not between 1 and 150)) then raise exception 'INVALID_CHILD_REFERENCE' using errcode='22023';end if;
 refs:=private.import_refs(d);p:='{}';output:=null;
 if kind='PARTY' then
 p:=jsonb_build_object('code',d->>'code','display_name',d->>'display_name','roles',to_jsonb(string_to_array(d->>'roles',',')),'contact_details',jsonb_build_object('address',coalesce(d->>'address',''),'phone',coalesce(d->>'phone',''),'email',coalesce(d->>'email','')),'archived',false);
 output:=public.save_master_record('PARTY',target,private.import_id(batch,k||'-command'),0,p);
 elsif kind='VEHICLE' then
 p:=jsonb_build_object('registration',d->>'registration','current_owner_id',refs#>>'{owner_code,id}','default_driver_id',refs#>>'{driver_code,id}','archived',false);
 output:=public.save_master_record('VEHICLE',target,private.import_id(batch,k||'-command'),0,p);
 elsif kind='ROUTE' then
 p:=jsonb_build_object('code',d->>'code','origin_label',d->>'origin_label','destination_label',d->>'destination_label','suggested_fare',nullif(d->>'suggested_fare',''),'archived',false);
 output:=public.save_master_record('ROUTE',target,private.import_id(batch,k||'-command'),0,p);
 elsif kind='STOP' then
 perform private.import_child(batch,rows,d->>'trip_key','TRIP_DRAFT');
 if coalesce(d->>'position','') !~ '^[1-9][0-9]{0,2}$' then raise exception 'INVALID_STOP_POSITION' using errcode='22023';end if;
 if d->>'stop_kind' not in('PICKUP','DROP','OTHER') or length(btrim(coalesce(d->>'address',''))) not between 1 and 500 then raise exception 'INVALID_STOP' using errcode='22023';end if;
 p:=jsonb_build_object('id',target,'kind',d->>'stop_kind','address',d->>'address');
 elsif kind='CONSIGNMENT_DRAFT' then
 perform private.import_child(batch,rows,d->>'trip_key','TRIP_DRAFT');
 if coalesce(d->>'car_count','') !~ '^[1-9][0-9]{0,5}$' then raise exception 'INVALID_CAR_COUNT' using errcode='22023';end if;
 quote:=public.calculate_quote(d->>'quoted_amount',d->>'quote_mode',d->>'commission_method',d->>'commission_value',refs ? 'broker_code');
 p:=jsonb_build_object('id',target,'customer_id',refs#>>'{customer_code,id}','broker_id',refs#>>'{broker_code,id}','car_count',(d->>'car_count')::integer,'quoted_amount',d->>'quoted_amount','quote_mode',d->>'quote_mode','commission_method',d->>'commission_method','commission_value',d->>'commission_value','notes',coalesce(d->>'notes',''),'pickup_stop_id',private.import_child(batch,rows,d->>'pickup_stop_key','STOP',d->>'trip_key'),'drop_stop_id',private.import_child(batch,rows,d->>'drop_stop_key','STOP',d->>'trip_key'));
 output:=quote;
 elsif kind='CAR' then
 perform private.import_child(batch,rows,d->>'consignment_key','CONSIGNMENT_DRAFT');
 select to_jsonb(x#>>'{data,trip_key}') into child from jsonb_array_elements(rows) x where x->>'row_key'=d->>'consignment_key';
 p:=jsonb_build_object('id',target,'identifier',d->>'identifier','pickup_stop_id',private.import_child(batch,rows,d->>'pickup_stop_key','STOP',child#>>'{}'),'drop_stop_id',private.import_child(batch,rows,d->>'drop_stop_key','STOP',child#>>'{}'));
 elsif kind='TRIP_DRAFT' then
 if exists(select 1 from jsonb_array_elements(rows) x where x->>'kind'='STOP' and x#>>'{data,trip_key}'=k group by x#>>'{data,position}' having count(*)>1) then raise exception 'DUPLICATE_STOP_POSITION' using errcode='22023';end if;
 select coalesce(jsonb_agg(prepared->(x->>'row_key') order by (x#>>'{data,position}')::integer),'[]') into stops from jsonb_array_elements(rows) x where x->>'kind'='STOP' and x#>>'{data,trip_key}'=k;
 consignments:='[]';
 for child in select x from jsonb_array_elements(rows) x where x->>'kind'='CONSIGNMENT_DRAFT' and x#>>'{data,trip_key}'=k loop
 p:=prepared->(child->>'row_key');if p is null then raise exception 'INVALID_CHILD_ROW' using errcode='22023';end if;
 p:=p||jsonb_build_object('cars',coalesce((select jsonb_agg(prepared->(x->>'row_key')) from jsonb_array_elements(rows) x where x->>'kind'='CAR' and x#>>'{data,consignment_key}'=child->>'row_key'),'[]'));
 consignments:=consignments||jsonb_build_array(p);end loop;
 review:=public.review_trip_overlap(target,(refs#>>'{vehicle_code,id}')::uuid,(refs#>>'{origin_code,id}')::uuid,(refs#>>'{destination_code,id}')::uuid,nullif(d->>'planned_dispatch_date',''),(refs#>>'{return_trip_code,id}')::uuid);
 if (review->>'requires_confirmation')::boolean then warnings:=warnings||jsonb_build_array(jsonb_build_object('row_key',k,'code','ACTIVE_VEHICLE_OVERLAP'));end if;
 p:=jsonb_build_object('vehicle_id',refs#>>'{vehicle_code,id}','driver_id',refs#>>'{driver_code,id}','origin_office_id',refs#>>'{origin_code,id}','destination_office_id',refs#>>'{destination_code,id}','route_id',refs#>>'{route_code,id}','return_of_trip_id',refs#>>'{return_trip_code,id}','load_kind',d->>'load_kind','planned_dispatch_date',nullif(d->>'planned_dispatch_date',''),'notes',coalesce(d->>'notes',''),'stops',stops,'consignments',consignments,'reason','Reviewed new-operation import','review_token',review->'review_token','overlap_confirmed',allow_overlap,'overlap_reason',nullif(d->>'overlap_reason',''));
 output:=public.save_trip(target,private.import_id(batch,k||'-command'),0,p);
 -- Review tokens are transient; compare the actual overlap set instead.
 fingerprints:=fingerprints||jsonb_build_array(jsonb_build_object('row_key',k,'overlap',private.trip_overlap_context(a.business_id,target,(refs#>>'{vehicle_code,id}')::uuid,(refs#>>'{origin_code,id}')::uuid,(refs#>>'{destination_code,id}')::uuid,nullif(d->>'planned_dispatch_date',''),(refs#>>'{return_trip_code,id}')::uuid)));
 p:=p-'review_token';
 elsif kind='EXPENSE_DRAFT' then
 office:=(refs#>>'{office_code,id}')::uuid;trip:=(refs#>>'{trip_code,id}')::uuid;
 if coalesce(d->>'trip_key','')<>'' then if trip is not null then raise exception 'ONE_TRIP_REFERENCE_REQUIRED' using errcode='22023';end if;trip:=private.import_child(batch,rows,d->>'trip_key','TRIP_DRAFT');end if;
 if not private.office_access(a.business_id,office) or (trip is not null and not private.trip_access(a.business_id,trip)) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if trip is not null then select owner_id into owner from public.trips where id=trip and vehicle_id=(refs#>>'{vehicle_code,id}')::uuid and office in(origin_office_id,destination_office_id);else select current_owner_id into owner from public.vehicles where id=(refs#>>'{vehicle_code,id}')::uuid;end if;
 if owner is null or not(refs ?& array['category_code','payer_code','cost_bearer_code']) or public.parse_money(d->>'amount')<=0 then raise exception 'INVALID_EXPENSE_REFERENCES_OR_AMOUNT' using errcode='22023';end if;
 perform public.parse_business_date(d->>'expense_date');
 if coalesce(d->>'funding_source','') not in('SELF_FUNDED_COST','PERSONAL_FUNDS','HELD_TRIP_FUNDS') or (d->>'funding_source'='SELF_FUNDED_COST' and refs#>>'{payer_code,id}'<>refs#>>'{cost_bearer_code,id}') or (d->>'funding_source'='PERSONAL_FUNDS' and refs#>>'{payer_code,id}'=refs#>>'{cost_bearer_code,id}') or (d->>'funding_source'='HELD_TRIP_FUNDS' and trip is null) or length(btrim(coalesce(d->>'notes',''))) not between 1 and 500 then raise exception 'INVALID_EXPENSE_DRAFT' using errcode='22023';end if;
 p:=jsonb_build_object('vehicle_id',refs#>>'{vehicle_code,id}','trip_id',trip,'office_id',office,'category_id',refs#>>'{category_code,id}','effective_date',d->>'expense_date','amount',public.parse_money(d->>'amount')::numeric(18,2)::text,'payer_id',refs#>>'{payer_code,id}','cost_bearer_id',refs#>>'{cost_bearer_code,id}','funding_source',d->>'funding_source','reason',d->>'notes');
 insert into private.import_expense_drafts(id,business_id,actor_id,office_id,trip_id,payload) values(target,a.business_id,a.id,office,trip,p);output:=p;
 end if;
 prepared:=prepared||jsonb_build_object(k,p);
 fingerprints:=fingerprints||jsonb_build_array(jsonb_build_object('row_key',k,'references',refs,'payload',p));
 preview:=preview||jsonb_build_array(jsonb_build_object('row_key',k,'kind',kind,'result_id',target,'values',coalesce(output,p)));
 exception when others then
 errors:=errors||jsonb_build_array(jsonb_build_object('row_key',coalesce(r->>'row_key','?'),'kind',r->>'kind','code',case when sqlerrm ~ '^[A-Z_]+$' then sqlerrm else 'INVALID_ROW_OR_DUPLICATE_REFERENCE' end));
 end;end loop;
 return jsonb_build_object('errors',errors,'rows',preview,'warnings',warnings,'fingerprint',encode(sha256(convert_to(fingerprints::text,'UTF8')),'hex'));
end $$;
create function public.validate_import(command jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.staff_profiles;review private.import_reviews;result jsonb;batch uuid;begin
 a:=private.current_staff();if a.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if jsonb_typeof(command) is distinct from 'object' or command->'template_version' is distinct from '1'::jsonb or exists(select 1 from jsonb_object_keys(command) k where k not in('batch_id','template_version','rows','office_code')) or jsonb_typeof(command->'rows') is distinct from 'array' or jsonb_array_length(command->'rows') not between 1 and 1000 or length(command::text)>1000000 then raise exception 'INVALID_IMPORT_TEMPLATE' using errcode='22023';end if;
 batch:=(command->>'batch_id')::uuid;if batch is null then raise exception 'INVALID_IMPORT_BATCH' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||a.business_id::text,0));a:=private.current_staff();
 if a.id is null or not private.office_access(a.business_id,(private.import_reference('OFFICE',command->>'office_code')->>'id')::uuid) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select * into review from private.import_reviews where business_id=a.business_id and batch_id=batch;
 if found and (review.actor_id<>a.id or review.command<>command) then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;
 if review.result is not null then return review.preview||jsonb_build_object('review_token',review.review_token,'committed',true);end if;
 begin result:=private.import_apply(command,true);raise exception using errcode='PZ001',message='IMPORT_DRY_RUN_ROLLBACK';exception when sqlstate 'PZ001' then null;end;
 insert into private.import_reviews(business_id,batch_id,actor_id,command,fingerprint,preview) values(a.business_id,batch,a.id,command,result->>'fingerprint',result-'fingerprint')
 on conflict(business_id,batch_id) do update set review_token=gen_random_uuid(),fingerprint=excluded.fingerprint,preview=excluded.preview,expires_at=now()+interval '30 minutes' returning * into review;
 return review.preview||jsonb_build_object('review_token',review.review_token,'committed',false);
end $$;
create function public.commit_import(command jsonb,review_token uuid,confirm_overlap boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
<<commit_state>>
declare a public.staff_profiles;review private.import_reviews;check_result jsonb;result jsonb;batch uuid;office uuid;item jsonb;n integer:=0;begin
 a:=private.current_staff();if a.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||a.business_id::text,0));a:=private.current_staff();if a.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 batch:=(command->>'batch_id')::uuid;office:=(private.import_reference('OFFICE',command->>'office_code')->>'id')::uuid;
 if not private.office_access(a.business_id,office) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select * into review from private.import_reviews where business_id=a.business_id and batch_id=batch for update;
 if review.actor_id is distinct from a.id or review.command is distinct from command or review.review_token is distinct from commit_import.review_token then raise exception 'REVIEW_MISMATCH' using errcode='PT409';end if;
 -- Every retry rechecks scope of the whole batch, including child origins/expense offices.
 for item in select x from jsonb_array_elements(command->'rows') x loop
 if item->>'kind' in('PARTY','VEHICLE','ROUTE') and a.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if item->>'kind' in('TRIP_DRAFT','EXPENSE_DRAFT') and not private.office_access(a.business_id,(private.import_reference('OFFICE',case when item->>'kind'='TRIP_DRAFT' then item#>>'{data,origin_code}' else item#>>'{data,office_code}' end)->>'id')::uuid) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if item->>'kind'='EXPENSE_DRAFT' and coalesce(item#>>'{data,trip_code}','')<>'' then perform private.import_reference('TRIP',item#>>'{data,trip_code}');end if;
 end loop;
 if review.result is not null then return review.result;end if;
 if review.expires_at<now() or jsonb_array_length(review.preview->'errors')<>0 then raise exception 'IMPORT_REVALIDATION_REQUIRED' using errcode='PT409';end if;
 begin check_result:=private.import_apply(command,true);raise exception using errcode='PZ001',message='IMPORT_DRY_RUN_ROLLBACK';exception when sqlstate 'PZ001' then null;end;
 if jsonb_array_length(check_result->'errors')<>0 or check_result->>'fingerprint'<>review.fingerprint then raise exception 'IMPORT_REVALIDATION_REQUIRED' using errcode='PT409';end if;
 result:=private.import_apply(command,confirm_overlap);
 if jsonb_array_length(result->'errors')<>0 then raise exception 'IMPORT_REVALIDATION_REQUIRED' using errcode='PT409';end if;
 insert into public.import_batches(id,business_id,client_batch_id,template_version,office_id,state,payload_digest,committed_at,created_by) values(batch,a.business_id,batch,1,office,'COMMITTED',encode(sha256(convert_to(command::text,'UTF8')),'hex'),now(),a.auth_user_id);
 for item in select x from jsonb_array_elements(command->'rows') x loop n:=n+1;
 insert into public.import_rows(business_id,batch_id,client_row_id,row_number,record_kind,payload,result_record_id,created_by) values(a.business_id,batch,private.import_id(batch,item->>'row_key'),n,item->>'kind',item->'data',private.import_id(batch,item->>'row_key'),a.auth_user_id);end loop;
 result:=jsonb_build_object('batch_id',batch,'committed',true,'rows',result->'rows');
 update private.import_reviews set result=commit_state.result where business_id=a.business_id and batch_id=batch;
 return result;
end $$;
create function public.list_import_expense_drafts(page_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.staff_profiles:=private.current_staff();begin
 if a.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if page_offset is null or page_offset<0 then raise exception 'INVALID_OFFSET' using errcode='22023';end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',d.id,'version',d.version,'payload',d.payload,
 'vehicle',(select private.master_payload('VEHICLE',to_jsonb(v),false) from public.vehicles v where id=(d.payload->>'vehicle_id')::uuid),
 'category',(select private.master_payload('CATEGORY',to_jsonb(v),false) from public.expense_categories v where id=(d.payload->>'category_id')::uuid),
 'payer',(select private.master_payload('PARTY',to_jsonb(v),false) from public.parties v where id=(d.payload->>'payer_id')::uuid),
 'bearer',(select private.master_payload('PARTY',to_jsonb(v),false) from public.parties v where id=(d.payload->>'cost_bearer_id')::uuid),
 'trip',case when d.trip_id is null then null else public.get_trip_detail(d.trip_id) end
 )),'[]') from (select * from private.import_expense_drafts where business_id=a.business_id and result is null and (a.role='ADMIN' or actor_id=a.id) and private.office_access(a.business_id,office_id) and (trip_id is null or private.trip_access(a.business_id,trip_id)) order by id limit 50 offset page_offset) d);end $$;
create function public.confirm_import_expense(target_id uuid,expected_version integer,request_id uuid,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
<<expense_state>>
declare a public.staff_profiles;d private.import_expense_drafts;result jsonb;begin
 a:=private.current_staff();if a.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||a.business_id::text,0));a:=private.current_staff();
 select * into d from private.import_expense_drafts where id=target_id and business_id=a.business_id for update;
 if a.id is null or d.id is null or (a.role<>'ADMIN' and d.actor_id<>a.id) or not private.office_access(a.business_id,d.office_id) or (d.trip_id is not null and not private.trip_access(a.business_id,d.trip_id)) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if d.result is not null then if d.confirmed_actor_id is distinct from a.id or d.request_id is distinct from request_id or d.confirmed_payload is distinct from payload then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;return d.result;end if;
 if expected_version is distinct from d.version then raise exception 'VERSION_CONFLICT' using errcode='PT409';end if;
 result:=public.post_financial_event('EXPENSE',request_id,0,payload);
 update private.import_expense_drafts set result=expense_state.result,request_id=confirm_import_expense.request_id,confirmed_actor_id=a.id,confirmed_payload=confirm_import_expense.payload,version=version+1 where id=target_id;
 return result;
end $$;
do $$ declare f record;begin for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='private' and p.proname in('import_fields','import_id','import_reference','import_refs','import_child','import_apply')) or (n.nspname='public' and p.proname in('get_import_templates','validate_import','commit_import','list_import_expense_drafts','confirm_import_expense')) loop
 execute format('alter function %s owner to carrier_security',f.signature);execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 if f.signature::text like 'get_import_templates%' or f.signature::text like 'validate_import%' or f.signature::text like 'commit_import%' or f.signature::text like 'list_import_expense_drafts%' or f.signature::text like 'confirm_import_expense%' then execute format('grant execute on function %s to authenticated',f.signature);end if;
 end loop;end $$;
grant execute on function private.import_fields(),private.import_id(uuid,text) to postgres;
revoke create on schema public,private from carrier_security;revoke carrier_security from postgres;
