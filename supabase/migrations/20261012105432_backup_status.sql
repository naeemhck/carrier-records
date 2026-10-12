
-- T16: service-only verified helper reports, administrator-only sanitized status.
grant carrier_security to postgres;
grant create on schema private,public to carrier_security;
alter table public.backup_status drop constraint backup_status_outcome_check;
alter table public.backup_status add constraint backup_status_outcome_check check(outcome in('NEVER_RUN','RUNNING','SUCCESS','FAILED'));
alter table public.backup_status add column last_run_id uuid;
alter table public.backup_status add column schedule jsonb not null default '{"active":false}'::jsonb;
alter table public.backup_status add column metrics jsonb not null default '{}'::jsonb;
create table private.backup_runs (
 run_id uuid primary key, business_id uuid not null references public.businesses(id), admin_staff_id uuid not null references public.staff_profiles(id),
 started_at timestamptz not null default now(), finished_at timestamptz, outcome text not null check(outcome in('RUNNING','SUCCESS','FAILED')),
 verified_digest text, metrics jsonb not null default '{}', safe_error_code text
);
create index backup_runs_business_time on private.backup_runs(business_id,started_at desc);
alter table private.backup_runs enable row level security;
create policy backup_owner on private.backup_runs to carrier_security using(true) with check(true);
grant select,insert,update on private.backup_runs,public.backup_status to carrier_security;
create function public.record_backup_status(business_id uuid,admin_staff_id uuid,run_id uuid,outcome text,verified_digest text default null,metrics jsonb default '{}',pending_receipts integer default 0,safe_error_code text default null,schedule jsonb default '{"active":false}') returns jsonb
language plpgsql security definer set search_path='' as $$
<<backup_command>>
declare admin public.staff_profiles;previous private.backup_runs;latest public.backup_status;result jsonb;k text;begin
 -- Caller holds the separately trusted helper service credential; ordinary clients cannot invoke this interface.
 select * into admin from public.staff_profiles s where s.id=admin_staff_id and s.business_id=record_backup_status.business_id;
 if admin.id is null or admin.role<>'ADMIN' or not admin.active or admin.auth_change_pending or admin.must_change_password then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||admin.business_id::text,0));
 select * into admin from public.staff_profiles s where s.id=admin_staff_id and s.business_id=record_backup_status.business_id and s.role='ADMIN' and s.active and not s.auth_change_pending and not s.must_change_password;
 if admin.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if run_id is null or outcome is null or outcome not in('RUNNING','SUCCESS','FAILED') or pending_receipts is null or pending_receipts<0 or (outcome='SUCCESS' and (verified_digest is null or verified_digest !~ '^[0-9a-f]{64}$' or pending_receipts<>0))
 or (safe_error_code is not null and safe_error_code not in('AUTHORIZATION_FAILED','DATABASE_EXPORT_FAILED','RECEIPT_COPY_FAILED','ARCHIVE_VERIFY_FAILED','LOCAL_IO_FAILED','STATUS_REPORT_FAILED','INTERRUPTED','RETENTION_FAILED','CREDENTIAL_UNAVAILABLE','CONFIGURATION_INVALID')) then raise exception 'INVALID_BACKUP_REPORT' using errcode='22023';end if;
 if jsonb_typeof(metrics) is distinct from 'object' or exists(select 1 from jsonb_each(metrics) e where e.key not in('database_bytes','storage_bytes','dump_bytes','receipt_bytes','http_bytes','reused_receipts','downloaded_receipts','egress_budget_bytes','other_egress_bytes') or (e.value<>'null'::jsonb and (jsonb_typeof(e.value)<>'number' or e.value#>>'{}' !~ '^[0-9]{1,16}$'))) then raise exception 'INVALID_BACKUP_METRICS' using errcode='22023';end if;
 if jsonb_typeof(schedule) is distinct from 'object' or exists(select 1 from jsonb_object_keys(schedule) f where f not in('active','daily_time','time_zone')) or jsonb_typeof(schedule->'active') is distinct from 'boolean' or (schedule ? 'daily_time' and coalesce(schedule->>'daily_time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') or (schedule ? 'time_zone' and (jsonb_typeof(schedule->'time_zone')<>'string' or length(schedule->>'time_zone') not between 1 and 100)) then raise exception 'INVALID_SCHEDULE_STATUS' using errcode='22023';end if;
 select * into previous from private.backup_runs r where r.run_id=record_backup_status.run_id for update;
 if found then
 if previous.business_id<>admin.business_id or previous.admin_staff_id<>admin.id then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;
 if previous.outcome<>'RUNNING' then
 if previous.outcome<>outcome or previous.verified_digest is distinct from verified_digest or previous.metrics is distinct from metrics or previous.safe_error_code is distinct from safe_error_code then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;
 return jsonb_build_object('run_id',run_id,'outcome',outcome);
 end if;
 else
 if outcome<>'RUNNING' then raise exception 'BACKUP_ATTEMPT_REQUIRED' using errcode='22023';end if;
 insert into private.backup_runs(run_id,business_id,admin_staff_id,outcome) values(run_id,admin.business_id,admin.id,'RUNNING');
 end if;
 if outcome<>'RUNNING' then update private.backup_runs r set outcome=record_backup_status.outcome,verified_digest=record_backup_status.verified_digest,metrics=record_backup_status.metrics,safe_error_code=record_backup_status.safe_error_code,finished_at=now() where r.run_id=record_backup_status.run_id;end if;
 select * into latest from public.backup_status s where s.business_id=admin.business_id and s.admin_staff_id=admin.id for update;
 if latest.id is not null and latest.last_run_id is distinct from run_id and previous.started_at is not null and latest.last_attempt_at>previous.started_at then return jsonb_build_object('run_id',run_id,'outcome',outcome);end if;
 if latest.id is null then
 insert into public.backup_status(business_id,admin_staff_id,outcome,last_run_id,last_attempt_at,schedule,metrics,created_by) values(admin.business_id,admin.id,outcome,run_id,now(),schedule,metrics,admin.auth_user_id);
 else
 update public.backup_status s set last_run_id=record_backup_status.run_id,last_attempt_at=coalesce(previous.started_at,now()),outcome=record_backup_status.outcome,last_verified_success_at=case when record_backup_status.outcome='SUCCESS' then now() else s.last_verified_success_at end,pending_receipt_count=pending_receipts,safe_error_code=record_backup_status.safe_error_code,schedule=record_backup_status.schedule,metrics=case when record_backup_status.outcome='SUCCESS' then record_backup_status.metrics else s.metrics end,version=s.version+1 where s.id=latest.id;
 end if;
 return jsonb_build_object('run_id',run_id,'outcome',outcome);
end $$;
create function public.get_backup_status() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a public.staff_profiles:=private.current_staff();s public.backup_status;traffic numeric;db numeric;files numeric;egress numeric;budget numeric;level text:='NORMAL';begin
 if a.id is null or a.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select * into s from public.backup_status where business_id=a.business_id order by last_attempt_at desc nulls last,id limit 1;
 select coalesce(sum(coalesce((metrics->>'dump_bytes')::numeric,0)+coalesce((metrics->>'receipt_bytes')::numeric,0)+coalesce((metrics->>'http_bytes')::numeric,0)),0) into traffic from private.backup_runs where business_id=a.business_id and started_at>=date_trunc('month',now() at time zone 'Asia/Karachi') at time zone 'Asia/Karachi' and outcome in('SUCCESS','FAILED');
 db:=coalesce((s.metrics->>'database_bytes')::numeric,0);files:=coalesce((s.metrics->>'storage_bytes')::numeric,0);budget:=coalesce((s.metrics->>'egress_budget_bytes')::numeric,5000000000);egress:=traffic+coalesce((s.metrics->>'other_egress_bytes')::numeric,0);
 if db>=450000000 or files>=900000000 or egress>=budget*0.9 then level:='90_PERCENT';elsif db>=375000000 or files>=750000000 or egress>=budget*0.75 then level:='75_PERCENT';end if;
 return jsonb_build_object('outcome',coalesce(s.outcome,'NEVER_RUN'),'last_attempt_at',s.last_attempt_at,'last_verified_success_at',(select max(last_verified_success_at) from public.backup_status where business_id=a.business_id),'stale',not exists(select 1 from public.backup_status where business_id=a.business_id and last_verified_success_at>now()-interval '26 hours'),'interrupted',s.outcome='RUNNING' and s.last_attempt_at<now()-interval '2 hours','pending_receipt_count',coalesce(s.pending_receipt_count,0),'safe_error_code',s.safe_error_code,'schedule',coalesce(s.schedule,'{"active":false}'),'metrics',coalesce(s.metrics,'{}'),'backup_traffic_monthly_bytes',traffic::numeric(38,0)::text,'incomplete_traffic_attempts',(select count(*) from private.backup_runs where business_id=a.business_id and (outcome='RUNNING' or safe_error_code in('DATABASE_EXPORT_FAILED','INTERRUPTED','LOCAL_IO_FAILED'))),'quota_level',level,'other_traffic_known',s.metrics->'other_egress_bytes' is not null and s.metrics->'other_egress_bytes'<>'null'::jsonb,'off_pc_copy_reminder',true,'restoration_verified',false);
end $$;
alter function public.record_backup_status(uuid,uuid,uuid,text,text,jsonb,integer,text,jsonb) owner to carrier_security;
alter function public.get_backup_status() owner to carrier_security;
revoke all on function public.record_backup_status(uuid,uuid,uuid,text,text,jsonb,integer,text,jsonb),public.get_backup_status() from public,anon,authenticated;
grant execute on function public.record_backup_status(uuid,uuid,uuid,text,text,jsonb,integer,text,jsonb) to service_role;
grant execute on function public.get_backup_status() to authenticated;
revoke create on schema private,public from carrier_security;revoke carrier_security from postgres;
