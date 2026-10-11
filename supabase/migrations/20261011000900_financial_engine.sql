-- T07 immutable posting/claim kernel. Payment-entry workflows remain T08/T09.
do $$ begin
 if not exists(select 1 from pg_roles where rolname='carrier_finance') then
  create role carrier_finance nologin noinherit nobypassrls;
 end if;
end $$;
alter role carrier_finance nologin noinherit nobypassrls;
grant carrier_security,carrier_finance to postgres;
grant usage on schema public,private to carrier_finance;
grant execute on function public.parse_money(text),public.parse_business_date(text) to carrier_finance;
grant select on public.trips,public.parties,public.party_roles,public.offices,public.consignments,public.expenses,
 public.financial_events,public.journal_lines,public.allocations,public.idempotency_records to carrier_finance;
grant insert on public.financial_events,public.journal_lines,public.allocations,public.idempotency_records,public.audit_events to carrier_finance;
grant execute on function private.current_staff(boolean),private.office_access(uuid,uuid),private.trip_access(uuid,uuid) to carrier_finance;

-- Keep source RLS and invoker semantics; aggregate totals are wider than a
-- single posting and must not overflow NUMERIC(18,2).
create or replace function public.get_balance_summary(scope text) returns jsonb
language plpgsql stable set search_path='' as $$
declare s public.staff_profiles:=private.current_staff(); totals jsonb;
begin
 if s.id is null or scope is null or scope not in ('ASSIGNED','ALL') or (scope='ALL' and s.role<>'ADMIN') then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select coalesce(jsonb_object_agg(q.account_purpose,q.total),'{}') into totals from
  (select l.account_purpose,sum(l.signed_amount)::numeric(38,2)::text total from public.journal_lines l where l.business_id=s.business_id group by l.account_purpose) q;
 return jsonb_build_object('scope',scope,'complete',s.role='ADMIN','label',case when s.role='ADMIN' then 'Complete business balance' else 'Assigned-office records — not a complete business balance' end,'totals',totals);
end $$;
do $$ declare t text; begin
 foreach t in array array['trips','parties','party_roles','offices','consignments','expenses','financial_events','journal_lines','allocations','idempotency_records'] loop
  execute format('create policy finance_read on public.%I for select to carrier_finance using(true)',t);
 end loop;
 foreach t in array array['financial_events','journal_lines','allocations','idempotency_records','audit_events'] loop
  execute format('create policy finance_append on public.%I for insert to carrier_finance with check(true)',t);
 end loop;
end $$;

-- Balances are derived, not editable counters. Reversed source lines are closed;
-- future allocation reversals restore the exact source amount with a new revision.
create function private.claim_state(line_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('remaining',
  (case when exists(select 1 from public.financial_events r where r.reversal_of_id=l.event_id)
    or e.kind='REVERSAL' then 0 else abs(l.signed_amount)-coalesce(sum(
      case when a.reversal_of_id is null then a.amount else -a.amount end),0) end)::numeric(18,2)::text,
  'version',1+count(a.id))
 from public.journal_lines l join public.financial_events e on e.id=l.event_id
 left join public.allocations a on a.source_line_id=l.id or a.target_line_id=l.id
 where l.id=line_id group by l.id,e.kind
$$;

-- Trusted callers supply a semantic event kind, never client journal lines.
-- The private settlement primitives support testing and future T08/T09 commands;
-- only CUSTOMER_RECEIPT is exposed by the T07 public wrapper.
create function private.post_claim_event(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; cached public.idempotency_records; command_body jsonb; digest text;
 payer uuid; payee uuid; office uuid; business_date date; total numeric; allocated numeric:=0; amount numeric;
 item jsonb; target public.journal_lines; source public.journal_lines; state jsonb;
 posting_id uuid; debit_id uuid; credit_id uuid; result jsonb; refs uuid[]:=array[]::uuid[];
 target_purpose text; target_party uuid; reason text; lock_id uuid;
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if event_kind is null or event_kind not in ('CUSTOMER_RECEIPT','OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','FUNDING_RECOVERY','REIMBURSEMENT','ADVANCE_APPLICATION')
  then raise exception 'UNSUPPORTED_EVENT' using errcode='22023'; end if;
 if request_id is null or expected_version is distinct from 0 or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>50000
  then raise exception 'INVALID_COMMAND' using errcode='22023'; end if;
 if exists(select 1 from jsonb_object_keys(payload) k where k not in ('payer_id','payee_id','office_id','effective_date','amount','reason','allocations'))
  or jsonb_typeof(payload->'amount') is distinct from 'string' or jsonb_typeof(payload->'reason') is distinct from 'string'
  or jsonb_typeof(payload->'allocations') is distinct from 'array'
  then raise exception 'INVALID_FIELDS' using errcode='22023'; end if;
 if jsonb_array_length(payload->'allocations') not between 1 and 100 then raise exception 'INVALID_ALLOCATIONS' using errcode='22023'; end if;
 total:=public.parse_money(payload->>'amount');
 if total<=0 then raise exception 'POSITIVE_AMOUNT_REQUIRED' using errcode='22023'; end if;
 reason:=btrim(payload->>'reason');
 if length(reason) not between 1 and 500 then raise exception 'REASON_REQUIRED' using errcode='22023'; end if;
 business_date:=public.parse_business_date(payload->>'effective_date');
 payer:=(payload->>'payer_id')::uuid; payee:=(payload->>'payee_id')::uuid; office:=(payload->>'office_id')::uuid;
 -- Same lock order as account changes and T06 dispatch/date corrections.
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));
 actor:=private.current_staff();
 if actor.id is null or not private.office_access(actor.business_id,office) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if not exists(select 1 from public.offices where id=office and business_id=actor.business_id)
  or not exists(select 1 from public.parties where id=payer and business_id=actor.business_id)
  or not exists(select 1 from public.parties where id=payee and business_id=actor.business_id)
  then raise exception 'INVALID_PARTIES_OR_OFFICE' using errcode='22023'; end if;
 target_purpose:=case event_kind when 'CUSTOMER_RECEIPT' then 'CUSTOMER_RECEIVABLE'
  when 'OWNER_SETTLEMENT' then 'OWNER_PAYABLE' when 'COMMISSION_SETTLEMENT' then 'BROKER_COMMISSION_PAYABLE'
  when 'FUNDING_RECOVERY' then 'TRIP_FUNDING_PAYABLE' when 'REIMBURSEMENT' then 'EXPENSE_REIMBURSEMENT_PAYABLE'
  else 'CUSTOMER_RECEIVABLE' end;
 target_party:=case when event_kind in ('CUSTOMER_RECEIPT','ADVANCE_APPLICATION') then payer else payee end;
 -- Validate every referenced record/office before idempotency lookup. Never
 -- return a formerly authorized global/bulk result after access is revoked.
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  if jsonb_typeof(item) is distinct from 'object' or exists(select 1 from jsonb_object_keys(item) k where k not in ('target_line_id','target_version','source_line_id','source_version','amount'))
   or jsonb_typeof(item->'amount') is distinct from 'string' or jsonb_typeof(item->'target_version') is distinct from 'number'
   or coalesce(item->>'target_version','') !~ '^[1-9][0-9]*$'
   then raise exception 'INVALID_ALLOCATIONS' using errcode='22023'; end if;
  amount:=public.parse_money(item->>'amount');
  if amount<=0 then raise exception 'POSITIVE_AMOUNT_REQUIRED' using errcode='22023'; end if;
  select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid and business_id=actor.business_id;
  if target.id is null or not private.trip_access(actor.business_id,target.trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if target.account_purpose<>target_purpose or target.party_id<>target_party
   or (target_purpose='CUSTOMER_RECEIVABLE' and target.signed_amount<=0)
   or (target_purpose<>'CUSTOMER_RECEIVABLE' and target.signed_amount>=0)
   then raise exception 'INVALID_CLAIM' using errcode='22023'; end if;
  if event_kind='REIMBURSEMENT' and (target.expense_id is null or not exists(select 1 from public.expenses x where x.id=target.expense_id and x.business_id=actor.business_id and x.trip_id=target.trip_id and x.payer_id=target.party_id and x.state='CONFIRMED')) then raise exception 'EXPENSE_CLAIM_REQUIRED' using errcode='22023'; end if;
  if business_date<(select effective_date from public.financial_events where id=target.event_id) then raise exception 'PAYMENT_PRECEDES_CLAIM' using errcode='22023'; end if;
  if target.id=any(refs) then raise exception 'DUPLICATE_TARGET' using errcode='22023'; end if;
  refs:=array_append(refs,target.id);
  if event_kind='CUSTOMER_RECEIPT' then
   if item ? 'source_line_id' or item ? 'source_version' then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
  else
   if jsonb_typeof(item->'source_version') is distinct from 'number' or coalesce(item->>'source_version','') !~ '^[1-9][0-9]*$' then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
   select * into source from public.journal_lines where id=(item->>'source_line_id')::uuid and business_id=actor.business_id;
   if source.id is null or not private.trip_access(actor.business_id,source.trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if source.party_id<>payer or source.trip_id is distinct from target.trip_id
    or (event_kind='ADVANCE_APPLICATION' and (source.account_purpose<>'CUSTOMER_ADVANCE_CREDIT' or source.signed_amount>=0 or (source.consignment_id is not null and source.consignment_id is distinct from target.consignment_id)))
    or (event_kind<>'ADVANCE_APPLICATION' and (source.account_purpose<>'CUSTODY_RECEIVABLE' or source.signed_amount<=0))
    then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
   if business_date<(select effective_date from public.financial_events where id=source.event_id) then raise exception 'PAYMENT_PRECEDES_SOURCE' using errcode='22023'; end if;
   refs:=array_append(refs,source.id);
  end if;
  allocated:=allocated+amount;
 end loop;
 if allocated<>total then raise exception 'ALLOCATION_MISMATCH' using errcode='22023'; end if;
 command_body:=jsonb_build_object('kind',event_kind,'version',expected_version,'payload',payload);
 digest:=encode(sha256(convert_to(command_body::text,'UTF8')),'hex');
 select * into cached from public.idempotency_records r where r.business_id=actor.business_id and r.request_id=post_claim_event.request_id;
 if found then
  if cached.actor_id<>actor.id or cached.command<>event_kind or cached.payload_digest<>digest then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409'; end if;
  return cached.result;
 end if;
 if exists(select 1 from public.financial_events e where e.business_id=actor.business_id and e.request_id=post_claim_event.request_id)
  then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409'; end if;
 if not exists(select 1 from public.offices where id=office and business_id=actor.business_id and archived_at is null) or not exists(select 1 from public.parties where id=payee and business_id=actor.business_id and archived_at is null) then raise exception 'ACTIVE_RECIPIENT_OR_OFFICE_REQUIRED' using errcode='22023'; end if;
 -- No UPDATE grants on immutable journals are needed for ordered advisory locks.
 for lock_id in select distinct x from unnest(refs) x order by x loop
  perform pg_advisory_xact_lock(hashtextextended('claim:'||lock_id::text,0));
 end loop;
 -- Validate source aggregates once before writing; several targets can consume
 -- one custody line, but cannot collectively overdraw it.
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  state:=private.claim_state((item->>'target_line_id')::uuid);
  if (state->>'version')::bigint<>(item->>'target_version')::bigint then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409'; end if;
  if (state->>'remaining')::numeric<public.parse_money(item->>'amount') then raise exception 'CLAIM_EXHAUSTED' using errcode='22023'; end if;
  if event_kind<>'CUSTOMER_RECEIPT' then
   state:=private.claim_state((item->>'source_line_id')::uuid);
   if (state->>'version')::bigint<>(item->>'source_version')::bigint then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409'; end if;
   select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'source_line_id'=item->>'source_line_id';
   if (state->>'remaining')::numeric<allocated then raise exception 'INSUFFICIENT_SOURCE' using errcode='22023'; end if;
  end if;
 end loop;
 posting_id:=gen_random_uuid();
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,payer_id,payee_id,amount,request_id,reason,created_by)
 values(posting_id,actor.business_id,event_kind,business_date,actor.id,office,payer,payee,total,request_id,reason,actor.auth_user_id);
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid;
  amount:=public.parse_money(item->>'amount'); debit_id:=gen_random_uuid();credit_id:=gen_random_uuid();
  if event_kind='CUSTOMER_RECEIPT' then
   insert into public.journal_lines(id,business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    values(debit_id,actor.business_id,posting_id,payee,office,target.vehicle_id,target.trip_id,target.consignment_id,'CUSTODY_RECEIVABLE',amount,actor.auth_user_id),
    (credit_id,actor.business_id,posting_id,payer,office,target.vehicle_id,target.trip_id,target.consignment_id,'CUSTOMER_RECEIVABLE',-amount,actor.auth_user_id);
   insert into public.allocations(business_id,event_id,trip_id,consignment_id,target_line_id,amount,component,created_by)
    values(actor.business_id,posting_id,target.trip_id,target.consignment_id,target.id,amount,'CASH',actor.auth_user_id);
  else
   select * into source from public.journal_lines where id=(item->>'source_line_id')::uuid;
   insert into public.journal_lines(id,business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,account_purpose,signed_amount,created_by)
    values(debit_id,actor.business_id,posting_id,case when event_kind='ADVANCE_APPLICATION' then payer else payee end,office,target.vehicle_id,target.trip_id,target.consignment_id,target.expense_id,
      case when event_kind='ADVANCE_APPLICATION' then 'CUSTOMER_ADVANCE_CREDIT' else target_purpose end,amount,actor.auth_user_id),
    (credit_id,actor.business_id,posting_id,payer,office,target.vehicle_id,target.trip_id,source.consignment_id,source.expense_id,
      case when event_kind='ADVANCE_APPLICATION' then 'CUSTOMER_RECEIVABLE' else 'CUSTODY_RECEIVABLE' end,-amount,actor.auth_user_id);
   insert into public.allocations(business_id,event_id,trip_id,consignment_id,expense_id,source_event_id,source_line_id,target_line_id,amount,component,created_by)
    values(actor.business_id,posting_id,target.trip_id,target.consignment_id,target.expense_id,source.event_id,source.id,target.id,amount,
     case when event_kind='ADVANCE_APPLICATION' then 'CREDIT_APPLICATION' else 'CASH' end,actor.auth_user_id);
  end if;
 end loop;
 -- Enforce balance before constructing success as well as at final commit.
 if (select coalesce(sum(signed_amount),0) from public.journal_lines where public.journal_lines.event_id=posting_id)<>0 then raise exception 'UNBALANCED_JOURNAL' using errcode='23514'; end if;
 result:=jsonb_build_object('record_id',posting_id,'new_version',1,'kind',event_kind,'amount',total::numeric(18,2)::text,'effective_date',business_date,
  'allocations',(select jsonb_agg(jsonb_build_object('trip_id',a.trip_id,'target_line_id',a.target_line_id,'amount',a.amount::text,
   'target',private.claim_state(a.target_line_id),'source',case when a.source_line_id is not null then private.claim_state(a.source_line_id) end)) from public.allocations a where a.event_id=posting_id));
 insert into public.audit_events(business_id,actor_id,office_id,record_id,record_type,action,reason,after_data,created_by)
  values(actor.business_id,actor.id,office,posting_id,'FINANCIAL_EVENT',event_kind,reason,result,actor.auth_user_id);
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by)
  values(actor.business_id,request_id,actor.id,event_kind,digest,result,actor.auth_user_id);
 return result;
end $$;

create function public.post_financial_event(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if event_kind is distinct from 'CUSTOMER_RECEIPT' then raise exception 'WORKFLOW_NOT_AVAILABLE' using errcode='22023'; end if;
 return private.post_claim_event(event_kind,request_id,expected_version,payload);
end $$;

create function public.get_trip_financials(trip_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles; balances jsonb; claims jsonb;
begin
 actor:=private.current_staff();
 if actor.id is null or not private.trip_access(actor.business_id,trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('party_id',x.party_id,'account_purpose',x.account_purpose,'balance',x.balance)),'[]') into balances
  from(select l.party_id,l.account_purpose,sum(l.signed_amount)::numeric(38,2)::text balance from public.journal_lines l
   where l.business_id=actor.business_id and l.trip_id=get_trip_financials.trip_id group by l.party_id,l.account_purpose) x;
 select coalesce(jsonb_agg(jsonb_build_object('line_id',l.id,'party_id',l.party_id,'account_purpose',l.account_purpose,
  'consignment_id',l.consignment_id,'expense_id',l.expense_id,'effective_date',e.effective_date,
  'remaining',s.v->>'remaining','version',(s.v->>'version')::bigint) order by l.id),'[]') into claims
 from public.journal_lines l join public.financial_events e on e.id=l.event_id
 cross join lateral(select private.claim_state(l.id) v) s
 where l.business_id=actor.business_id and l.trip_id=get_trip_financials.trip_id and (s.v->>'remaining')::numeric>0
  and ((l.account_purpose in ('CUSTOMER_RECEIVABLE','CUSTODY_RECEIVABLE','PARTY_COST_RECOVERY') and l.signed_amount>0)
    or (l.account_purpose in ('OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE','CUSTOMER_ADVANCE_CREDIT','EXPENSE_REIMBURSEMENT_PAYABLE','TRIP_FUNDING_PAYABLE') and l.signed_amount<0));
 return jsonb_build_object('scope','TRIP','complete',true,'label','This permitted trip only; not a complete party or business balance',
  'balances',balances,'claims',claims);
end $$;

grant create on schema public,private to carrier_finance,carrier_security;
alter function private.claim_state(uuid) owner to carrier_finance;
alter function private.post_claim_event(text,uuid,integer,jsonb) owner to carrier_finance;
alter function public.post_financial_event(text,uuid,integer,jsonb) owner to carrier_security;
alter function public.get_trip_financials(uuid) owner to carrier_security;
revoke all on function private.claim_state(uuid),private.post_claim_event(text,uuid,integer,jsonb),public.post_financial_event(text,uuid,integer,jsonb),public.get_trip_financials(uuid) from public,anon,authenticated;
grant execute on function private.claim_state(uuid),private.post_claim_event(text,uuid,integer,jsonb) to carrier_security;
grant execute on function public.post_financial_event(text,uuid,integer,jsonb),public.get_trip_financials(uuid) to authenticated;
revoke create on schema public,private from carrier_finance,carrier_security;
revoke carrier_finance,carrier_security from postgres;
