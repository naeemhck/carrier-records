-- T09 expenses are effective costs once; settlements consume claims, not costs.
grant carrier_finance,carrier_security to postgres;
grant create on schema private,public to carrier_finance;
alter table public.expenses add column owner_id uuid;
alter table public.expenses add foreign key(business_id,owner_id) references public.parties(business_id,id);
alter table public.allocations alter column trip_id drop not null;
alter table public.allocations add constraint standalone_expense_allocation check(trip_id is not null or expense_id is not null);
grant select on public.vehicles,public.expense_categories to carrier_finance;
grant insert on public.expenses to carrier_finance;
create policy finance_read on public.vehicles for select to carrier_finance using(true);
create policy finance_read on public.expense_categories for select to carrier_finance using(true);
create policy finance_append on public.expenses for insert to carrier_finance with check(true);
create function private.post_expense(request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; cached public.idempotency_records; digest text; result jsonb;
 vehicle uuid; trip uuid; office uuid; category uuid; payer uuid; bearer uuid; owner uuid; day date; total numeric; funding text; reason text;
 expense uuid:=gen_random_uuid(); posting uuid:=gen_random_uuid(); item jsonb; line public.journal_lines; state jsonb; n numeric; allocated numeric; refs uuid[]:=array[]::uuid[]; lock_id uuid; owner_offset boolean; offset_amount numeric:=0;
begin
 actor:=private.current_staff(); if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if request_id is null or expected_version is distinct from 0 or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>50000
 or exists(select 1 from jsonb_object_keys(payload) k where k not in ('vehicle_id','trip_id','office_id','category_id','effective_date','amount','payer_id','cost_bearer_id','funding_source','reason','allocations','offset_confirmed'))
 or jsonb_typeof(payload->'amount') is distinct from 'string' or jsonb_typeof(payload->'reason') is distinct from 'string' or jsonb_typeof(payload->'allocations') is distinct from 'array'
 then raise exception 'INVALID_EXPENSE' using errcode='22023'; end if;
 total:=public.parse_money(payload->>'amount'); day:=public.parse_business_date(payload->>'effective_date');reason:=btrim(payload->>'reason'); funding:=payload->>'funding_source';
 if total<=0 or length(reason) not between 1 and 500 or funding is null or funding not in ('SELF_FUNDED_COST','PERSONAL_FUNDS','HELD_TRIP_FUNDS') or jsonb_array_length(payload->'allocations')>100 then raise exception 'INVALID_EXPENSE' using errcode='22023'; end if;
 vehicle:=(payload->>'vehicle_id')::uuid;trip:=(payload->>'trip_id')::uuid;office:=(payload->>'office_id')::uuid;category:=(payload->>'category_id')::uuid;payer:=(payload->>'payer_id')::uuid;bearer:=(payload->>'cost_bearer_id')::uuid;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));actor:=private.current_staff();
 if actor.id is null or not private.office_access(actor.business_id,office) or (trip is not null and not private.trip_access(actor.business_id,trip)) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if trip is not null then
  perform pg_advisory_xact_lock(hashtextextended('trip-vehicle:'||vehicle::text,0));
  select owner_id into owner from public.trips where id=trip and business_id=actor.business_id and vehicle_id=vehicle and office in(origin_office_id,destination_office_id);
 else select current_owner_id into owner from public.vehicles where id=vehicle and business_id=actor.business_id; end if;
 if owner is null or not exists(select 1 from public.expense_categories where id=category and business_id=actor.business_id)
 or not exists(select 1 from public.parties where id=payer and business_id=actor.business_id)
 or not exists(select 1 from public.parties where id=bearer and business_id=actor.business_id) then raise exception 'INVALID_REFERENCES' using errcode='22023'; end if;
 if (funding='SELF_FUNDED_COST' and payer<>bearer) or (funding='PERSONAL_FUNDS' and payer=bearer) or (funding='HELD_TRIP_FUNDS' and trip is null) then raise exception 'INVALID_FUNDING_SOURCE' using errcode='22023'; end if;
 owner_offset:=trip is not null and bearer=owner and funding<>'SELF_FUNDED_COST' and exists(select 1 from private.trip_recognition where trip_id=trip);
 if owner_offset then select least(total,coalesce(sum((private.claim_state(l.id)->>'remaining')::numeric),0)) into offset_amount from public.journal_lines l where l.business_id=actor.business_id and l.trip_id=trip and l.party_id=bearer and l.account_purpose='OWNER_PAYABLE' and l.signed_amount<0;end if;
 if owner_offset and payload->'offset_confirmed' is distinct from 'true'::jsonb then raise exception 'OFFSET_CONFIRMATION_REQUIRED' using errcode='22023'; end if;
 -- Explicit owner target and custody source allocations; no automatic netting.
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  if jsonb_typeof(item) is distinct from 'object' or exists(select 1 from jsonb_object_keys(item) k where k not in ('line_id','version','amount','component')) or jsonb_typeof(item->'amount') is distinct from 'string'
   or jsonb_typeof(item->'version') is distinct from 'number' or coalesce(item->>'version','') !~ '^[1-9][0-9]*$' or item->>'component' is null or item->>'component' not in ('OFFSET','CASH') then raise exception 'INVALID_ALLOCATIONS' using errcode='22023'; end if;
  n:=public.parse_money(item->>'amount'); if n<=0 then raise exception 'INVALID_ALLOCATIONS' using errcode='22023'; end if;
  select * into line from public.journal_lines where id=(item->>'line_id')::uuid and business_id=actor.business_id;
  if line.id is null or line.trip_id is distinct from trip or not private.trip_access(actor.business_id,line.trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if (item->>'component'='OFFSET' and (not owner_offset or line.account_purpose<>'OWNER_PAYABLE' or line.party_id<>bearer or line.signed_amount>=0))
   or (item->>'component'='CASH' and (funding<>'HELD_TRIP_FUNDS' or line.account_purpose<>'CUSTODY_RECEIVABLE' or line.party_id<>payer or line.signed_amount<=0)) then raise exception 'INVALID_CLAIM' using errcode='22023'; end if;
  if day<(select effective_date from public.financial_events where id=line.event_id) then raise exception 'EXPENSE_PRECEDES_SOURCE' using errcode='22023'; end if;
  refs:=array_append(refs,line.id);
 end loop;
 select coalesce(sum(public.parse_money(x->>'amount')),0) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'component'='OFFSET';
 if allocated>total then raise exception 'OFFSET_ALLOCATION_MISMATCH' using errcode='22023'; end if;
 select coalesce(sum(public.parse_money(x->>'amount')),0) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'component'='CASH';
 if allocated<>(case when funding='HELD_TRIP_FUNDS' then total else 0 end) then raise exception 'CASH_ALLOCATION_MISMATCH' using errcode='22023'; end if;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 select * into cached from public.idempotency_records r where r.business_id=actor.business_id and r.request_id=post_expense.request_id;
 if found then if cached.actor_id<>actor.id or cached.command<>'EXPENSE' or cached.payload_digest<>digest then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409'; end if;return cached.result;end if;
 if exists(select 1 from public.financial_events e where e.business_id=actor.business_id and e.request_id=post_expense.request_id) then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409'; end if;
 if not exists(select 1 from public.vehicles where id=vehicle and archived_at is null) or not exists(select 1 from public.expense_categories where id=category and archived_at is null)
 or not exists(select 1 from public.offices where id=office and archived_at is null)
 or exists(select 1 from public.parties where id in(payer,bearer) and archived_at is not null) then raise exception 'ACTIVE_REFERENCES_REQUIRED' using errcode='22023'; end if;
 for lock_id in select distinct x from unnest(refs) x order by x loop perform pg_advisory_xact_lock(hashtextextended('claim:'||lock_id::text,0));end loop;
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  state:=private.claim_state((item->>'line_id')::uuid);
  if (state->>'version')::bigint<>(item->>'version')::bigint then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409'; end if;
  select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'line_id'=item->>'line_id';
  if (state->>'remaining')::numeric<allocated then raise exception 'INSUFFICIENT_SOURCE_OR_CLAIM' using errcode='22023'; end if;
 end loop;
 select coalesce(sum(public.parse_money(x->>'amount')),0) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'component'='OFFSET';
 if allocated<>offset_amount then raise exception 'OFFSET_ALLOCATION_MISMATCH' using errcode='22023';end if;
 insert into public.expenses(id,business_id,vehicle_id,trip_id,office_id,category_id,expense_date,amount,payer_id,cost_bearer_id,funding_source,state,notes,created_by,owner_id)
 values(expense,actor.business_id,vehicle,trip,office,category,day,total,payer,bearer,funding,'CONFIRMED',reason,actor.auth_user_id,owner);
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,expense_id,payer_id,payee_id,amount,request_id,reason,created_by)
 values(posting,actor.business_id,'EXPENSE',day,actor.id,office,vehicle,trip,expense,payer,null,total,request_id,reason,actor.auth_user_id);
 if funding<>'SELF_FUNDED_COST' then
  if offset_amount>0 then insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,expense_id,account_purpose,signed_amount,created_by) values(actor.business_id,posting,bearer,office,vehicle,trip,expense,'OWNER_PAYABLE',offset_amount,actor.auth_user_id);end if;
  if total>offset_amount then insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,expense_id,account_purpose,signed_amount,created_by) values(actor.business_id,posting,bearer,office,vehicle,trip,expense,'PARTY_COST_RECOVERY',total-offset_amount,actor.auth_user_id);end if;
  insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,expense_id,account_purpose,signed_amount,created_by) values(actor.business_id,posting,payer,office,vehicle,trip,expense,case when funding='PERSONAL_FUNDS' then 'EXPENSE_REIMBURSEMENT_PAYABLE' else 'CUSTODY_RECEIVABLE' end,-total,actor.auth_user_id);
 end if;
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  select * into line from public.journal_lines where id=(item->>'line_id')::uuid;
  insert into public.allocations(business_id,event_id,trip_id,expense_id,source_event_id,source_line_id,target_line_id,amount,component,created_by)
  values(actor.business_id,posting,trip,expense,line.event_id,case when item->>'component'='CASH' then line.id end,case when item->>'component'='OFFSET' then line.id end,public.parse_money(item->>'amount'),item->>'component',actor.auth_user_id);
 end loop;
 if (select coalesce(sum(signed_amount),0) from public.journal_lines where event_id=posting)<>0 then raise exception 'UNBALANCED_JOURNAL' using errcode='23514';end if;
 result:=jsonb_build_object('record_id',expense,'event_id',posting,'new_version',1,'amount',total::numeric(18,2)::text,'effective_date',day,'funding_source',funding,'offset',offset_amount::numeric(18,2)::text,'receipt_status','NOT_ATTACHED');
 insert into public.audit_events(business_id,actor_id,office_id,record_id,record_type,action,reason,after_data,created_by) values(actor.business_id,actor.id,office,expense,'EXPENSE','CONFIRM',reason,result,actor.auth_user_id);
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by) values(actor.business_id,request_id,actor.id,'EXPENSE',digest,result,actor.auth_user_id);
 return result;
end $$;
alter function private.post_expense(uuid,integer,jsonb) owner to carrier_finance;
revoke all on function private.post_expense(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function private.post_expense(uuid,integer,jsonb) to carrier_security;
create or replace function private.post_claim_event(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; cached public.idempotency_records; command_body jsonb; digest text;
 payer uuid; payee uuid; office uuid; business_date date; total numeric; allocated numeric:=0; amount numeric;
 item jsonb; target public.journal_lines; source public.journal_lines; state jsonb;
 posting_id uuid; debit_id uuid; credit_id uuid; result jsonb; refs uuid[]:=array[]::uuid[];
 target_purpose text; target_party uuid; reason text; lock_id uuid;
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if event_kind is null or event_kind not in ('CUSTOMER_RECEIPT','OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','FUNDING_RECOVERY','REIMBURSEMENT','EXPENSE_RECOVERY','EXPENSE_OFFSET','ADVANCE_APPLICATION')
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
 target_purpose:=case event_kind when 'CUSTOMER_RECEIPT' then 'CUSTOMER_RECEIVABLE' when 'EXPENSE_RECOVERY' then 'PARTY_COST_RECOVERY' when 'EXPENSE_OFFSET' then 'PARTY_COST_RECOVERY'
  when 'OWNER_SETTLEMENT' then 'OWNER_PAYABLE' when 'COMMISSION_SETTLEMENT' then 'BROKER_COMMISSION_PAYABLE'
  when 'FUNDING_RECOVERY' then 'TRIP_FUNDING_PAYABLE' when 'REIMBURSEMENT' then 'EXPENSE_REIMBURSEMENT_PAYABLE'
  else 'CUSTOMER_RECEIVABLE' end;
 target_party:=case when event_kind in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY','EXPENSE_OFFSET','ADVANCE_APPLICATION') then payer else payee end;
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
  if target.id is null or not(case when target.trip_id is null then private.office_access(actor.business_id,target.office_id) else private.trip_access(actor.business_id,target.trip_id) end) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if target.trip_id is null and office is distinct from target.office_id then raise exception 'FORBIDDEN' using errcode='42501';end if;
  if target.account_purpose<>target_purpose or target.party_id<>target_party
   or (target_purpose in ('CUSTOMER_RECEIVABLE','PARTY_COST_RECOVERY') and target.signed_amount<=0)
   or (target_purpose not in ('CUSTOMER_RECEIVABLE','PARTY_COST_RECOVERY') and target.signed_amount>=0)
   then raise exception 'INVALID_CLAIM' using errcode='22023'; end if;
  if event_kind in ('EXPENSE_RECOVERY','EXPENSE_OFFSET') and (target.expense_id is null or not exists(select 1 from public.expenses x where x.id=target.expense_id and x.cost_bearer_id=payer and x.state='CONFIRMED' and x.business_id=actor.business_id)) then raise exception 'EXPENSE_CLAIM_REQUIRED' using errcode='22023'; end if;
  if event_kind='REIMBURSEMENT' and (target.expense_id is null or not exists(select 1 from public.expenses x where x.id=target.expense_id and x.business_id=actor.business_id and x.trip_id is not distinct from target.trip_id and x.payer_id=target.party_id and x.state='CONFIRMED')) then raise exception 'EXPENSE_CLAIM_REQUIRED' using errcode='22023'; end if;
  if business_date<(select effective_date from public.financial_events where id=target.event_id) then raise exception 'PAYMENT_PRECEDES_CLAIM' using errcode='22023'; end if;
  refs:=array_append(refs,target.id);
  if event_kind in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY') then
   if item ? 'source_line_id' or item ? 'source_version' then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
  else
   if jsonb_typeof(item->'source_version') is distinct from 'number' or coalesce(item->>'source_version','') !~ '^[1-9][0-9]*$' then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
   select * into source from public.journal_lines where id=(item->>'source_line_id')::uuid and business_id=actor.business_id;
   if source.id is null or not(case when source.trip_id is null then private.office_access(actor.business_id,source.office_id) else private.trip_access(actor.business_id,source.trip_id) end) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if source.party_id<>payer or source.trip_id is distinct from target.trip_id or (target.trip_id is null and (source.expense_id is distinct from target.expense_id or source.office_id<>target.office_id))
    or (event_kind='ADVANCE_APPLICATION' and (source.account_purpose<>'CUSTOMER_ADVANCE_CREDIT' or source.signed_amount>=0 or (source.consignment_id is not null and source.consignment_id is distinct from target.consignment_id)))
    or (event_kind='EXPENSE_OFFSET' and (source.account_purpose<>'OWNER_PAYABLE' or source.signed_amount>=0 or payer<>payee or target.trip_id is null or not exists(select 1 from public.trips t where t.id=target.trip_id and t.owner_id=payer)))
    or (event_kind not in ('ADVANCE_APPLICATION','EXPENSE_OFFSET') and (source.account_purpose<>'CUSTODY_RECEIVABLE' or source.signed_amount<=0))
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
  select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'target_line_id'=item->>'target_line_id';
  if (state->>'remaining')::numeric<allocated then raise exception 'CLAIM_EXHAUSTED' using errcode='22023'; end if;
  if event_kind not in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY') then
   state:=private.claim_state((item->>'source_line_id')::uuid);
   if (state->>'version')::bigint<>(item->>'source_version')::bigint then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409'; end if;
   select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'source_line_id'=item->>'source_line_id';
   if (state->>'remaining')::numeric<allocated then raise exception 'INSUFFICIENT_SOURCE' using errcode='22023'; end if;
  end if;
 end loop;
 posting_id:=gen_random_uuid();
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,payer_id,payee_id,amount,request_id,reason,created_by)
 values(posting_id,actor.business_id,case when event_kind in ('EXPENSE_RECOVERY','EXPENSE_OFFSET') then 'REIMBURSEMENT' else event_kind end,business_date,actor.id,office,payer,payee,total,request_id,reason,actor.auth_user_id);
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid;
  amount:=public.parse_money(item->>'amount'); debit_id:=gen_random_uuid();credit_id:=gen_random_uuid();
  if event_kind in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY') then
   insert into public.journal_lines(id,business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,account_purpose,signed_amount,created_by)
    values(debit_id,actor.business_id,posting_id,payee,office,target.vehicle_id,target.trip_id,target.consignment_id,target.expense_id,'CUSTODY_RECEIVABLE',amount,actor.auth_user_id),
    (credit_id,actor.business_id,posting_id,payer,office,target.vehicle_id,target.trip_id,target.consignment_id,target.expense_id,target_purpose,-amount,actor.auth_user_id);
   insert into public.allocations(business_id,event_id,trip_id,consignment_id,expense_id,target_line_id,amount,component,created_by)
    values(actor.business_id,posting_id,target.trip_id,target.consignment_id,target.expense_id,target.id,amount,'CASH',actor.auth_user_id);
  else
   select * into source from public.journal_lines where id=(item->>'source_line_id')::uuid;
   insert into public.journal_lines(id,business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,account_purpose,signed_amount,created_by)
    values(debit_id,actor.business_id,posting_id,case when event_kind='ADVANCE_APPLICATION' then payer else payee end,office,target.vehicle_id,target.trip_id,target.consignment_id,target.expense_id,
      case when event_kind='ADVANCE_APPLICATION' then 'CUSTOMER_ADVANCE_CREDIT' when event_kind='EXPENSE_OFFSET' then 'OWNER_PAYABLE' else target_purpose end,amount,actor.auth_user_id),
    (credit_id,actor.business_id,posting_id,payer,office,target.vehicle_id,target.trip_id,case when event_kind='ADVANCE_APPLICATION' then target.consignment_id else source.consignment_id end,case when event_kind='EXPENSE_OFFSET' then target.expense_id else source.expense_id end,
      case when event_kind='ADVANCE_APPLICATION' then 'CUSTOMER_RECEIVABLE' when event_kind='EXPENSE_OFFSET' then 'PARTY_COST_RECOVERY' else 'CUSTODY_RECEIVABLE' end,-amount,actor.auth_user_id);
   insert into public.allocations(business_id,event_id,trip_id,consignment_id,expense_id,source_event_id,source_line_id,target_line_id,amount,component,created_by)
    values(actor.business_id,posting_id,target.trip_id,target.consignment_id,target.expense_id,source.event_id,source.id,target.id,amount,
     case when event_kind='ADVANCE_APPLICATION' then 'CREDIT_APPLICATION' when event_kind='EXPENSE_OFFSET' then 'OFFSET' else 'CASH' end,actor.auth_user_id);
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


create or replace function public.post_financial_event(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if event_kind='EXPENSE' then return private.post_expense(request_id,expected_version,payload); end if;
 if event_kind='ADVANCE_APPLICATION' and payload->>'payer_id' is distinct from payload->>'payee_id' then raise exception 'INVALID_PARTIES' using errcode='22023'; end if;
 if event_kind in ('OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','FUNDING_RECOVERY','ADVANCE_APPLICATION','REIMBURSEMENT','EXPENSE_RECOVERY','EXPENSE_OFFSET') or (event_kind='CUSTOMER_RECEIPT' and not(payload ? 'credits')) then
  return private.post_claim_event(event_kind,request_id,expected_version,payload);
 elsif event_kind in ('CUSTOMER_RECEIPT','ADVANCE','CUSTODY_TRANSFER','PERSONAL_FUNDING','REFUND') then
  return private.post_money_movement(event_kind,request_id,expected_version,payload);
 end if;
 raise exception 'WORKFLOW_NOT_AVAILABLE' using errcode='22023';
end $$;

-- Scoped expense payloads explicitly enumerate attributes and stringify money.
create function public.list_expenses(vehicle_id uuid default null,trip_id uuid default null,offset_rows integer default 0) returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(q.data),'[]') from (select jsonb_build_object('id',x.id,'vehicle_id',x.vehicle_id,'trip_id',x.trip_id,'office_id',x.office_id,'category_id',x.category_id,'expense_date',x.expense_date,'amount',x.amount::text,'payer_id',x.payer_id,'cost_bearer_id',x.cost_bearer_id,'funding_source',x.funding_source,'notes',x.notes,'version',x.version) data from public.expenses x where x.state='CONFIRMED' and (list_expenses.vehicle_id is null or x.vehicle_id=list_expenses.vehicle_id) and (list_expenses.trip_id is null or x.trip_id=list_expenses.trip_id) order by x.expense_date desc,x.id limit 50 offset greatest(0,least(offset_rows,100000))) q
$$;
revoke all on function public.list_expenses(uuid,uuid,integer) from public,anon;
grant execute on function public.list_expenses(uuid,uuid,integer) to authenticated;
create function public.get_expense_claims(expense_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); x public.expenses;
begin
 select * into x from public.expenses where id=expense_id and business_id=actor.business_id;
 if actor.id is null or x.id is null or not(case when x.trip_id is null then private.office_access(x.business_id,x.office_id) else private.trip_access(x.business_id,x.trip_id) end) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('line_id',l.id,'party_id',l.party_id,'account_purpose',l.account_purpose,'expense_id',l.expense_id,'remaining',private.claim_state(l.id)->>'remaining','version',private.claim_state(l.id)->'version')) from public.journal_lines l where l.expense_id=x.id and (l.account_purpose='CUSTODY_RECEIVABLE' and l.signed_amount>0 or l.account_purpose='PARTY_COST_RECOVERY' and l.signed_amount>0 or l.account_purpose='EXPENSE_REIMBURSEMENT_PAYABLE' and l.signed_amount<0) and (private.claim_state(l.id)->>'remaining')::numeric>0),'[]');
end $$;
alter function public.get_expense_claims(uuid) owner to carrier_finance;
revoke all on function public.get_expense_claims(uuid) from public,anon;grant execute on function public.get_expense_claims(uuid) to authenticated;
revoke create on schema private,public from carrier_finance;
revoke carrier_finance,carrier_security from postgres;

create table private.abandoned_receipts(object_path text primary key,business_id uuid not null references public.businesses(id),claimed_at timestamptz not null default now());
grant select,insert on private.abandoned_receipts to carrier_security;
-- Evidence is appended independently; the confirmed expense is never updated.
create table public.expense_evidence (
 expense_id uuid primary key references public.expenses(id), receipt_id uuid not null unique references public.receipt_files(id),
 request_id uuid not null unique, actor_id uuid not null references public.staff_profiles(id), created_at timestamptz not null default now()
);
alter table public.expense_evidence enable row level security;
create policy evidence_read on public.expense_evidence for select to authenticated using(exists(select 1 from public.expenses x where x.id=expense_id));
grant select on public.expense_evidence to authenticated;
revoke all on public.expense_evidence from anon;
grant carrier_security to postgres;
grant create on schema public to carrier_security;
grant usage on schema storage to carrier_security;
grant select on storage.objects to carrier_security;
create policy evidence_object_verify on storage.objects for select to carrier_security using(bucket_id='receipts');
grant select,insert on public.receipt_files,public.expense_evidence to carrier_security;
create policy evidence_security on public.expense_evidence to carrier_security using(true) with check(true);
create policy receipt_append on public.receipt_files for insert to carrier_security with check(true);
create function public.attach_expense_receipt(actor_claims jsonb,expense_id uuid,request_id uuid,expected_version integer,mime_type text,byte_size integer,sha256 text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; x public.expenses; previous public.expense_evidence; receipt public.receipt_files; path text; receipt_id uuid;
begin
 perform set_config('request.jwt.claims',actor_claims::text,true);actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));actor:=private.current_staff();
 select * into x from public.expenses where id=expense_id and business_id=actor.business_id;
 if actor.id is null or x.id is null or not(case when x.trip_id is null then private.office_access(x.business_id,x.office_id) else private.trip_access(x.business_id,x.trip_id) end) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if expected_version is distinct from x.version or x.state<>'CONFIRMED' then raise exception 'VERSION_CONFLICT' using errcode='PT409';end if;
 if request_id is null or mime_type not in('image/jpeg','image/png','application/pdf') or byte_size not between 1 and 5242880 or sha256 !~ '^[0-9a-f]{64}$' or mime_type is null or byte_size is null or sha256 is null then raise exception 'INVALID_EVIDENCE' using errcode='22023';end if;
 perform pg_advisory_xact_lock(hashtextextended('expense-evidence:'||x.id::text,0));
 path:=x.business_id::text||'/'||x.id::text||'/'||request_id::text;
 if exists(select 1 from private.abandoned_receipts a where a.object_path=path) then raise exception 'ABANDONED_UPLOAD_EXPIRED' using errcode='22023';end if;
 select * into previous from public.expense_evidence e where e.expense_id=x.id or e.request_id=attach_expense_receipt.request_id;
 if found then
  select * into receipt from public.receipt_files where id=previous.receipt_id;
  if previous.expense_id<>x.id or previous.request_id<>request_id or previous.actor_id<>actor.id or receipt.sha256<>sha256 or receipt.byte_size<>byte_size or receipt.mime_type<>mime_type then raise exception 'EVIDENCE_ALREADY_ATTACHED_OR_RETRY_MISMATCH' using errcode='PT409';end if;
  return jsonb_build_object('receipt_id',receipt.id,'object_path',receipt.object_path,'receipt_status','ATTACHED');
 end if;
 if not exists(select 1 from storage.objects o where o.bucket_id='receipts' and o.name=path and (o.metadata->>'size')::bigint=byte_size and o.metadata->>'mimetype'=mime_type) then raise exception 'UPLOAD_NOT_PRESENT' using errcode='22023';end if;
 receipt_id:=gen_random_uuid();
 insert into public.receipt_files(id,business_id,office_id,trip_id,object_path,mime_type,byte_size,sha256,created_by) values(receipt_id,x.business_id,x.office_id,x.trip_id,path,mime_type,byte_size,sha256,actor.auth_user_id);
 insert into public.expense_evidence(expense_id,receipt_id,request_id,actor_id) values(x.id,receipt_id,request_id,actor.id);
 return jsonb_build_object('receipt_id',receipt_id,'object_path',path,'receipt_status','ATTACHED');
end $$;
alter function public.attach_expense_receipt(jsonb,uuid,uuid,integer,text,integer,text) owner to carrier_security;
revoke all on function public.attach_expense_receipt(jsonb,uuid,uuid,integer,text,integer,text) from public,anon,authenticated;
grant execute on function public.attach_expense_receipt(jsonb,uuid,uuid,integer,text,integer,text) to service_role;
revoke create on schema public from carrier_security;
revoke carrier_security from postgres;

create function public.get_expense_totals(vehicle_id uuid,from_date date,to_date date,trip_id uuid default null) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('scope','PERMITTED_RECORDS','date_basis',case when get_expense_totals.trip_id is null then 'EXPENSE_DATE' else 'LIFETIME_TRIP' end,'vehicle_cost',coalesce(sum(x.amount),0)::numeric(38,2)::text,'owner_cost',coalesce(sum(x.amount) filter(where x.cost_bearer_id=x.owner_id),0)::numeric(38,2)::text)
 from public.expenses x where x.state='CONFIRMED' and x.vehicle_id=get_expense_totals.vehicle_id and (case when get_expense_totals.trip_id is not null then x.trip_id=get_expense_totals.trip_id else x.expense_date between from_date and to_date end) and not exists(select 1 from public.expenses r where r.replaces_expense_id=x.id)
$$;
revoke all on function public.get_expense_totals(uuid,date,date,uuid) from public,anon;
grant execute on function public.get_expense_totals(uuid,date,date,uuid) to authenticated;

create or replace function private.protect_funded_draft() returns trigger
language plpgsql security definer set search_path='' as $$
declare affected uuid;
begin
 if tg_table_name='trips' then affected:=old.id; else affected:=old.trip_id; end if;
 if exists(select 1 from public.allocations a where a.trip_id=affected) or exists(select 1 from public.expenses x where x.trip_id=affected) then
  if tg_table_name='trips' then
   if new.state='CANCELLED' or (old.state='DRAFT' and
    (new.vehicle_id,new.owner_id,new.origin_office_id,new.destination_office_id,new.load_kind) is distinct from
    (old.vehicle_id,old.owner_id,old.origin_office_id,old.destination_office_id,old.load_kind)) then
     raise exception 'FINANCIAL_DEPENDENCIES' using errcode='22023'; end if;
  elsif tg_op='DELETE' then raise exception 'FINANCIAL_DEPENDENCIES' using errcode='22023';
  elsif (new.customer_id,new.trip_id) is distinct from (old.customer_id,old.trip_id)
   or (new.state is distinct from old.state and not(old.state='ACTIVE' and new.state='DELIVERED')) then raise exception 'FINANCIAL_DEPENDENCIES' using errcode='22023'; end if;
 end if;
 return case when tg_op='DELETE' then old else new end;
end $$;

grant carrier_security to postgres;
grant create on schema public to carrier_security;
create function public.reserve_abandoned_receipts(actor_claims jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; obj record; paths jsonb:='[]'::jsonb;
begin
 perform set_config('request.jwt.claims',actor_claims::text,true);actor:=private.current_staff();
 if actor.id is null or actor.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));actor:=private.current_staff();
 if actor.id is null or actor.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;
 for obj in select o.name from storage.objects o where o.bucket_id='receipts' and o.name like actor.business_id::text||'/%' and o.name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}$' and o.created_at<now()-interval '24 hours' order by o.name loop
  perform pg_advisory_xact_lock(hashtextextended('expense-evidence:'||split_part(obj.name,'/',2),0));
  if not exists(select 1 from public.receipt_files r where r.object_path=obj.name and r.business_id=actor.business_id) then
   insert into private.abandoned_receipts(object_path,business_id) values(obj.name,actor.business_id) on conflict do nothing;
   paths:=paths||jsonb_build_array(obj.name);
  end if;
 end loop;
 return paths;
end $$;
alter function public.reserve_abandoned_receipts(jsonb) owner to carrier_security;
revoke all on function public.reserve_abandoned_receipts(jsonb) from public,anon,authenticated;
grant execute on function public.reserve_abandoned_receipts(jsonb) to service_role;
revoke create on schema public from carrier_security;
revoke carrier_security from postgres;
