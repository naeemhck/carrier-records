-- T03: live database authorization. Ordinary JWT roles never get table writes.
create schema if not exists private;
revoke all on schema private from public, anon;
do $$ begin
 if not exists(select 1 from pg_roles where rolname='carrier_security') then
 create role carrier_security nologin noinherit nobypassrls;
 end if;
end $$;
alter role carrier_security nologin noinherit nobypassrls;
grant carrier_security to postgres;
grant usage on schema public, private, auth to carrier_security;
grant usage on schema private to authenticated;
grant select on all tables in schema public to carrier_security;



grant insert, update on public.staff_profiles to carrier_security;
grant insert, delete on public.staff_offices to carrier_security;
grant insert on public.audit_events, public.businesses, public.offices to carrier_security;
alter table public.staff_profiles add column credential_revision integer not null default 1 check (credential_revision > 0);
alter table public.staff_profiles add column auth_change_pending boolean not null default false;
alter table public.staff_profiles add constraint staff_username_format check (username ~ '^[a-z][a-z0-9_.-]{2,31}$');
create table private.password_operations (
 id uuid primary key default gen_random_uuid(), target_id uuid not null references public.staff_profiles(id),
 actor_id uuid not null references public.staff_profiles(id), actor_claims jsonb not null,
 is_reset boolean not null, finished boolean not null default false, created_at timestamptz not null default now()
);
grant select,insert,update on private.password_operations to carrier_security;
do $$ declare t record; begin
 for t in select tablename from pg_tables where schemaname='public' and rowsecurity loop
 execute format('create policy trusted_security on public.%I to carrier_security using (true) with check (true)',t.tablename);
 end loop;
end $$;

-- Auth objects use RLS and their ACLs are reset by local CLI startup. Three
-- fixed, private helpers use the trusted migration owner; never API-exposed.
create function private.auth_identity(uid uuid) returns text language sql stable security definer set search_path='' as $$
 select email from auth.users where id=uid
$$;
create function private.auth_session_valid(uid uuid,sid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users u join auth.sessions s on s.user_id=u.id where u.id=uid and s.id=sid and (u.banned_until is null or u.banned_until<=now()) and (s.not_after is null or s.not_after>now()))
$$;
create function private.revoke_sessions(uid uuid) returns void language sql security definer set search_path='' as $$
 delete from auth.sessions where user_id=uid
$$;
revoke all on function private.auth_identity(uuid),private.auth_session_valid(uuid,uuid),private.revoke_sessions(uuid) from public,anon,authenticated,service_role;
grant execute on function private.auth_identity(uuid),private.auth_session_valid(uuid,uuid),private.revoke_sessions(uuid) to carrier_security;

create function private.current_staff(ready boolean default true) returns public.staff_profiles
language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles; c jsonb := coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb; begin
 select p.* into s from public.staff_profiles p
 where p.auth_user_id=(c->>'sub')::uuid and p.active and not p.auth_change_pending
 and p.credential_revision = (c->>'staff_revision')::integer
 and (not ready or not p.must_change_password)

 and private.auth_session_valid(p.auth_user_id,(c->>'session_id')::uuid)
 and (p.role='ADMIN' or exists(select 1 from public.staff_offices so join public.offices o on o.id=so.office_id where so.staff_id=p.id and o.archived_at is null));
 return s;
exception when invalid_text_representation or numeric_value_out_of_range then return null;
end $$;
create function private.is_admin(b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((private.current_staff()).business_id=b and (private.current_staff()).role='ADMIN',false)
$$;
create function private.office_access(b uuid,o uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(s.business_id=b and (s.role='ADMIN' or exists(select 1 from public.staff_offices a join public.offices x on x.id=a.office_id where a.staff_id=s.id and a.office_id=o and x.archived_at is null)),false) from private.current_staff() s
$$;
create function private.trip_access(b uuid,t uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.trips x where x.business_id=b and x.id=t and (private.office_access(b,x.origin_office_id) or private.office_access(b,x.destination_office_id)))
$$;
create function public.staff_access_token_hook(event jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles; begin
 select p.* into s from public.staff_profiles p where p.auth_user_id=(event->>'user_id')::uuid and p.active and not p.auth_change_pending
 and (p.role='ADMIN' or exists(select 1 from public.staff_offices a join public.offices o on o.id=a.office_id where a.staff_id=p.id and o.archived_at is null));
 if s.id is null then return jsonb_build_object('error',jsonb_build_object('http_code',403,'message','Account unavailable')); end if;
 return jsonb_build_object('claims',jsonb_set(event->'claims','{staff_revision}',to_jsonb(s.credential_revision)));
end $$;
create function public.get_session_profile() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff(false); begin
 if s.id is null then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 return jsonb_build_object('id',s.id,'business_id',s.business_id,'username',s.username,'display_name',s.display_name,'role',s.role,'version',s.version,'must_change_password',s.must_change_password,
 'offices',(select coalesce(jsonb_agg(jsonb_build_object('id',o.id,'name',o.name) order by o.name),'[]') from public.offices o where o.business_id=s.business_id and o.archived_at is null and (s.role='ADMIN' or exists(select 1 from public.staff_offices a where a.staff_id=s.id and a.office_id=o.id))));
end $$;
create function public.list_staff_accounts() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff(); begin
 if s.id is null or s.role<>'ADMIN' then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 return (select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'username',p.username,'display_name',p.display_name,'role',p.role,'active',p.active,'must_change_password',p.must_change_password,'version',p.version,'office_ids',(select coalesce(jsonb_agg(a.office_id),'[]') from public.staff_offices a where a.staff_id=p.id)) order by p.username),'[]') from public.staff_profiles p where p.business_id=s.business_id);
end $$;
create function public.authorize_trip_operation(trip_id uuid,operation text) returns boolean language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff(); t public.trips; permitted boolean; begin
 select x.* into t from public.trips x where x.id=trip_id and x.business_id=s.business_id;
 permitted:=case operation when 'EDIT_FARE' then private.office_access(t.business_id,t.origin_office_id) when 'DISPATCH' then private.office_access(t.business_id,t.origin_office_id) when 'ARRIVAL' then private.office_access(t.business_id,t.destination_office_id) when 'POST_MONEY' then private.trip_access(t.business_id,t.id) when 'EXPENSE' then private.trip_access(t.business_id,t.id) else false end;
 if s.id is null or t.id is null or not coalesce(permitted,false) then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 return true;
end $$;
create function public.get_balance_summary(scope text) returns jsonb language plpgsql stable set search_path='' as $$
declare s public.staff_profiles:=private.current_staff(); totals jsonb; begin
 if s.id is null or scope is null or scope not in ('ASSIGNED','ALL') or (scope='ALL' and s.role<>'ADMIN') then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 -- SECURITY INVOKER: the source rows retain RLS; JSON amounts are exact strings.
 select coalesce(jsonb_object_agg(q.account_purpose,q.total),'{}') into totals from
 (select l.account_purpose, sum(l.signed_amount)::numeric(18,2)::text total from public.journal_lines l where l.business_id=s.business_id group by l.account_purpose) q;
 return jsonb_build_object('scope',scope,'complete',s.role='ADMIN','label',case when s.role='ADMIN' then 'Complete business balance' else 'Assigned-office records — not a complete business balance' end,'totals',totals);
end $$;

create function private.audit_staff(actor public.staff_profiles,target public.staff_profiles,action text) returns void language sql set search_path='' as $$
 insert into public.audit_events(business_id,actor_id,record_type,record_id,action,after_data,created_by)
 values(actor.business_id,actor.id,'STAFF_ACCOUNT',target.id,action,jsonb_build_object('username',target.username,'role',target.role,'active',target.active,'must_change_password',target.must_change_password),actor.auth_user_id)
$$;
create function private.validate_offices(b uuid,ids uuid[]) returns void language plpgsql set search_path='' as $$ begin
 if ids is null or exists(select 1 from unnest(ids) x where x is null or not exists(select 1 from public.offices o where o.id=x and o.business_id=b and o.archived_at is null)) then raise exception 'VALIDATION_ERROR: offices'; end if;
end $$;
create function public.admin_manage_staff(target_id uuid,expected_version integer,display_name text,account_role text,active boolean,office_ids uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.staff_profiles:=private.current_staff(); t public.staff_profiles; begin
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||a.business_id::text,0)); a:=private.current_staff();
 if a.id is null or a.role<>'ADMIN' then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 select p.* into t from public.staff_profiles p where p.id=target_id and p.business_id=a.business_id for update;
 if t.id is null then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 if expected_version is null or t.version<>expected_version then raise exception using errcode='PT409',message='VERSION_CONFLICT'; end if;
 if t.auth_change_pending then raise exception 'PASSWORD_CHANGE_PENDING'; end if;
 if account_role not in ('ADMIN','STAFF') or active is null or coalesce(length(btrim(display_name)),0)=0 then raise exception 'VALIDATION_ERROR'; end if;
 if t.id=a.id and (not active or account_role<>'ADMIN') then raise exception 'Cannot disable or demote your own administrator account'; end if;
 perform private.validate_offices(a.business_id,office_ids);
 update public.staff_profiles p set display_name=btrim(admin_manage_staff.display_name),role=account_role,active=admin_manage_staff.active,credential_revision=p.credential_revision+1,version=p.version+1 where p.id=t.id returning * into t;
 delete from public.staff_offices so where so.staff_id=t.id;
 insert into public.staff_offices(business_id,staff_id,office_id,created_by) select a.business_id,t.id,x,a.auth_user_id from (select distinct unnest(office_ids) x) q;
 perform private.revoke_sessions(t.auth_user_id);
 perform private.audit_staff(a,t,'ACCOUNT_UPDATED');
 return jsonb_build_object('id',t.id,'version',t.version);
end $$;
-- These RPCs are service-only. Edge Functions pass claims from a JWT verified by Auth.
create function public.register_staff(actor_claims jsonb,auth_user_id uuid,username text,display_name text,account_role text,office_ids uuid[]) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.staff_profiles; t public.staff_profiles; begin
 perform set_config('request.jwt.claims',actor_claims::text,true); a:=private.current_staff();
 if a.id is null or a.role<>'ADMIN' then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 perform private.validate_offices(a.business_id,office_ids);
 if username !~ '^[a-z][a-z0-9_.-]{2,31}$' or account_role not in ('ADMIN','STAFF') or coalesce(length(btrim(display_name)),0)=0 then raise exception 'VALIDATION_ERROR'; end if;
 if private.auth_identity(register_staff.auth_user_id) is distinct from username||'.'||a.business_id::text||'@staff.invalid' then raise exception 'AUTH_IDENTITY_MISMATCH'; end if;
 insert into public.staff_profiles(business_id,auth_user_id,username,display_name,role,created_by) values(a.business_id,register_staff.auth_user_id,username,btrim(display_name),account_role,a.auth_user_id) returning * into t;
 insert into public.staff_offices(business_id,staff_id,office_id,created_by) select a.business_id,t.id,x,a.auth_user_id from (select distinct unnest(office_ids) x) q;
 perform private.audit_staff(a,t,'ACCOUNT_CREATED');
 return jsonb_build_object('id',t.id,'version',t.version);
end $$;
create function public.begin_staff_password(actor_claims jsonb,target_id uuid,expected_version integer,is_reset boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.staff_profiles; t public.staff_profiles; op uuid; begin
 perform set_config('request.jwt.claims',actor_claims::text,true); a:=private.current_staff(false);
 if a.id is null or is_reset is null or (is_reset and (a.role<>'ADMIN' or a.must_change_password)) or (not is_reset and a.id<>target_id) then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 select p.* into t from public.staff_profiles p where p.id=target_id and p.business_id=a.business_id for update;
 if t.id is null or not t.active then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 if expected_version is null or t.version<>expected_version then raise exception using errcode='PT409',message='VERSION_CONFLICT'; end if;
 if t.auth_change_pending then raise exception 'PASSWORD_CHANGE_PENDING'; end if;
 insert into private.password_operations(target_id,actor_id,actor_claims,is_reset) values(t.id,a.id,actor_claims,is_reset) returning id into op;
 update public.staff_profiles p set auth_change_pending=true,must_change_password=true,credential_revision=p.credential_revision+1,version=p.version+1 where p.id=t.id;
 perform private.revoke_sessions(t.auth_user_id);
 return jsonb_build_object('operation_id',op,'auth_user_id',t.auth_user_id);
end $$;
create function public.finish_staff_password(operation_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare op private.password_operations; a public.staff_profiles; t public.staff_profiles; begin
 select x.* into op from private.password_operations x where x.id=operation_id for update;
 if op.id is null or op.finished then raise exception 'INVALID_PASSWORD_OPERATION'; end if;
 select p.* into t from public.staff_profiles p where p.id=op.target_id for update;
 select p.* into a from public.staff_profiles p where p.id=op.actor_id;
 if not t.auth_change_pending or not a.active or a.business_id<>t.business_id then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 if a.id<>t.id then
 perform set_config('request.jwt.claims',op.actor_claims::text,true); a:=private.current_staff();
 if a.id is null or a.role<>'ADMIN' then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 end if;
 update public.staff_profiles p set auth_change_pending=false,must_change_password=op.is_reset,version=p.version+1 where p.id=t.id returning * into t;
 perform private.revoke_sessions(t.auth_user_id);
 update private.password_operations set finished=true where id=op.id;
 perform private.audit_staff(a,t,case when op.is_reset then 'PASSWORD_RESET' else 'PASSWORD_CHANGED' end);
end $$;
create function public.bootstrap_staff_admin(business_id uuid,company_name text,auth_user_id uuid,username text,display_name text) returns void language plpgsql security definer set search_path='' as $$
declare t public.staff_profiles; begin
 perform pg_advisory_xact_lock(723031);
 if exists(select 1 from public.businesses) then raise exception 'ALREADY_CONFIGURED'; end if;
 if private.auth_identity(bootstrap_staff_admin.auth_user_id) is distinct from username||'.'||business_id::text||'@staff.invalid' then raise exception 'AUTH_IDENTITY_MISMATCH'; end if;
 insert into public.businesses(id,name,created_by) values(business_id,company_name,auth_user_id);
 insert into public.staff_profiles(business_id,auth_user_id,username,display_name,role,created_by) values(business_id,auth_user_id,username,display_name,'ADMIN',auth_user_id) returning * into t;
 perform private.audit_staff(t,t,'ADMIN_BOOTSTRAPPED');
end $$;

create function public.recover_staff_password(target_id uuid,expected_version integer,actor_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare a public.staff_profiles; t public.staff_profiles; begin
 select p.* into t from public.staff_profiles p where p.id=target_id for update;
 select p.* into a from public.staff_profiles p where p.id=actor_id and p.business_id=t.business_id and p.active and p.role='ADMIN';
 if t.id is null or a.id is null or not t.auth_change_pending then raise exception using errcode='42501',message='FORBIDDEN'; end if;
 if expected_version is null or t.version<>expected_version then raise exception using errcode='PT409',message='VERSION_CONFLICT'; end if;
 update public.staff_profiles p set auth_change_pending=false,must_change_password=true,credential_revision=p.credential_revision+1,version=p.version+1 where p.id=t.id returning * into t;
 update private.password_operations o set finished=true where o.target_id=t.id and not o.finished;
 perform private.revoke_sessions(t.auth_user_id);
 perform private.audit_staff(a,t,'PASSWORD_RECOVERED');
end $$;

-- All ordinary writes stay closed, including administrator JWTs.
grant select on public.offices,public.trips,public.consignments,public.stops,public.consignment_cars,public.expenses,public.receipt_files,public.journal_lines to authenticated;
create policy office_read on public.offices for select to authenticated using(private.office_access(business_id,id));
create policy trip_read on public.trips for select to authenticated using(private.trip_access(business_id,id));
create policy consignment_read on public.consignments for select to authenticated using(private.trip_access(business_id,trip_id));
create policy stop_read on public.stops for select to authenticated using(private.trip_access(business_id,trip_id));
create policy car_read on public.consignment_cars for select to authenticated using(private.trip_access(business_id,trip_id));
create policy expense_read on public.expenses for select to authenticated using(case when trip_id is null then private.office_access(business_id,office_id) else private.trip_access(business_id,trip_id) end);
create policy receipt_read on public.receipt_files for select to authenticated using(case when trip_id is null then private.office_access(business_id,office_id) else private.trip_access(business_id,trip_id) end);
-- Do not expose global event amounts, allocation source identifiers or unscoped metadata.
create policy journal_read on public.journal_lines for select to authenticated using(case when trip_id is null then private.office_access(business_id,office_id) else private.trip_access(business_id,trip_id) end);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('receipts','receipts',false,5242880,array['image/jpeg','image/png','application/pdf']);
create policy receipt_download on storage.objects for select to authenticated using(bucket_id='receipts' and storage.allow_any_operation(array['object.get_authenticated','object.get_authenticated_info']) and exists(select 1 from public.receipt_files r where r.object_path=name));

-- A dedicated NOLOGIN owner has only the listed rights and pinned search paths.
grant create on schema public,private to carrier_security;
do $$ declare f record; begin
 for f in select p.oid::regprocedure signature,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname='private' and p.proname not in ('auth_identity','auth_session_valid','revoke_sessions')) or (n.nspname='public' and p.proname in ('staff_access_token_hook','get_session_profile','list_staff_accounts','authorize_trip_operation','get_balance_summary','admin_manage_staff','register_staff','begin_staff_password','finish_staff_password','bootstrap_staff_admin','recover_staff_password')) loop
 execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 execute format('alter function %s owner to carrier_security',f.signature);
 end loop;
end $$;
revoke create on schema public,private from carrier_security;

grant execute on function private.current_staff(boolean),private.is_admin(uuid),private.office_access(uuid,uuid),private.trip_access(uuid,uuid) to authenticated;
grant execute on function public.get_session_profile(),public.list_staff_accounts(),public.authorize_trip_operation(uuid,text),public.get_balance_summary(text),public.admin_manage_staff(uuid,integer,text,text,boolean,uuid[]) to authenticated;
grant execute on function public.register_staff(jsonb,uuid,text,text,text,uuid[]),public.begin_staff_password(jsonb,uuid,integer,boolean),public.finish_staff_password(uuid),public.bootstrap_staff_admin(uuid,text,uuid,text,text),public.recover_staff_password(uuid,integer,uuid) to service_role;
grant execute on function public.staff_access_token_hook(jsonb) to supabase_auth_admin;


revoke carrier_security from postgres;
