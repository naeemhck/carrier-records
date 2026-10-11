-- T08 semantic money movements. No arbitrary client journal or expense offsets.
grant carrier_finance,carrier_security to postgres;
grant create on schema private to carrier_finance;
-- A claim can be explicitly paid from several sources; aggregate both sides.
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
  select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'target_line_id'=item->>'target_line_id';
  if (state->>'remaining')::numeric<allocated then raise exception 'CLAIM_EXHAUSTED' using errcode='22023'; end if;
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
    (credit_id,actor.business_id,posting_id,payer,office,target.vehicle_id,target.trip_id,case when event_kind='ADVANCE_APPLICATION' then target.consignment_id else source.consignment_id end,source.expense_id,
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


create function private.post_money_movement(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles; cached public.idempotency_records; digest text; result jsonb;
 payer uuid; payee uuid; office uuid; day date; total numeric; allocated numeric:=0; amount numeric;
 item jsonb; items jsonb; target public.journal_lines; source public.journal_lines; t public.trips;
 trip uuid; consignment uuid; refs uuid[]:=array[]::uuid[]; lock_id uuid; state jsonb;
 posting uuid:=gen_random_uuid(); debit_purpose text; credit_purpose text; debit_party uuid; credit_party uuid;
 reason text; source_id uuid; target_id uuid; source_event uuid;
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if event_kind not in ('CUSTOMER_RECEIPT','ADVANCE','CUSTODY_TRANSFER','PERSONAL_FUNDING','REFUND') or event_kind is null
  then raise exception 'WORKFLOW_NOT_AVAILABLE' using errcode='22023'; end if;
 if request_id is null or expected_version is distinct from 0 or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>50000
  then raise exception 'INVALID_COMMAND' using errcode='22023'; end if;
 if exists(select 1 from jsonb_object_keys(payload) k where k not in ('payer_id','payee_id','office_id','effective_date','amount','reason','allocations','credits'))
  or jsonb_typeof(payload->'amount') is distinct from 'string' or jsonb_typeof(payload->'reason') is distinct from 'string'
  or jsonb_typeof(payload->'allocations') is distinct from 'array'
  or (payload ? 'credits' and (event_kind<>'CUSTOMER_RECEIPT' or jsonb_typeof(payload->'credits') is distinct from 'array'))
  then raise exception 'INVALID_FIELDS' using errcode='22023'; end if;
 items:=(payload->'allocations')||coalesce(payload->'credits','[]');
 if jsonb_array_length(items) not between 1 and 100 then raise exception 'INVALID_ALLOCATIONS' using errcode='22023'; end if;
 total:=public.parse_money(payload->>'amount'); reason:=btrim(payload->>'reason'); day:=public.parse_business_date(payload->>'effective_date');
 if total<=0 or length(reason) not between 1 and 500 then raise exception 'POSITIVE_AMOUNT_AND_REASON_REQUIRED' using errcode='22023'; end if;
 payer:=(payload->>'payer_id')::uuid; payee:=(payload->>'payee_id')::uuid; office:=(payload->>'office_id')::uuid;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));
 actor:=private.current_staff();
 if actor.id is null or not private.office_access(actor.business_id,office) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if not exists(select 1 from public.offices where id=office and business_id=actor.business_id)
  or not exists(select 1 from public.parties where id=payer and business_id=actor.business_id)
  or not exists(select 1 from public.parties where id=payee and business_id=actor.business_id)
  then raise exception 'INVALID_PARTIES_OR_OFFICE' using errcode='22023'; end if;
 if event_kind='CUSTODY_TRANSFER' and payer=payee then raise exception 'DISTINCT_CUSTODIANS_REQUIRED' using errcode='22023'; end if;
 -- Validate all references before returning a cached result, including credits.
 for item in select * from jsonb_array_elements(items) loop
  if jsonb_typeof(item) is distinct from 'object' or jsonb_typeof(item->'amount') is distinct from 'string'
   or exists(select 1 from jsonb_object_keys(item) k where k not in ('amount','trip_id','consignment_id','target_line_id','target_version','source_line_id','source_version'))
   then raise exception 'INVALID_ALLOCATIONS' using errcode='22023'; end if;
  amount:=public.parse_money(item->>'amount');
  if amount<=0 then raise exception 'POSITIVE_AMOUNT_REQUIRED' using errcode='22023'; end if;
  target_id:=null;source_id:=null;
  if event_kind in ('PERSONAL_FUNDING','REFUND') or (event_kind='CUSTOMER_RECEIPT' and item ? 'target_line_id') then
   if item ? 'trip_id' or item ? 'consignment_id' or jsonb_typeof(item->'target_version') is distinct from 'number'
    or coalesce(item->>'target_version','') !~ '^[1-9][0-9]*$' then raise exception 'INVALID_TARGET' using errcode='22023'; end if;
   select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid and business_id=actor.business_id;
   if target.id is null or not private.trip_access(actor.business_id,target.trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if (event_kind='PERSONAL_FUNDING' and (target.account_purpose<>'OWNER_PAYABLE' or target.party_id<>payee or target.signed_amount>=0))
    or (event_kind='REFUND' and (target.account_purpose<>'CUSTOMER_ADVANCE_CREDIT' or target.party_id<>payee or target.signed_amount>=0))
    or (event_kind='CUSTOMER_RECEIPT' and (target.account_purpose<>'CUSTOMER_RECEIVABLE' or target.party_id<>payer or target.signed_amount<=0))
    then raise exception 'INVALID_CLAIM' using errcode='22023'; end if;
   if day<(select effective_date from public.financial_events where id=target.event_id) then raise exception 'PAYMENT_PRECEDES_CLAIM' using errcode='22023'; end if;
   target_id:=target.id;trip:=target.trip_id;consignment:=target.consignment_id;
   refs:=array_append(refs,target.id);
  elsif event_kind in ('ADVANCE','CUSTOMER_RECEIPT') then
   if item ? 'target_line_id' or item ? 'target_version' then raise exception 'INVALID_TARGET' using errcode='22023'; end if;
   trip:=(item->>'trip_id')::uuid;consignment:=(item->>'consignment_id')::uuid;
   if not private.trip_access(actor.business_id,trip) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   -- A trip-level credit still requires this customer's documented relationship.
   if not exists(select 1 from public.consignments c where c.trip_id=trip and c.business_id=actor.business_id and c.customer_id=payer
     and (consignment is null or c.id=consignment)) then raise exception 'CUSTOMER_TRIP_REQUIRED' using errcode='22023'; end if;
   if event_kind='CUSTOMER_RECEIPT' and not exists(select 1 from private.trip_recognition r where r.trip_id=trip)
    then raise exception 'DRAFT_REQUIRES_ADVANCE' using errcode='22023'; end if;
   if event_kind='CUSTOMER_RECEIPT' and day<(select dispatch_date from public.trips where id=trip)
    then raise exception 'PAYMENT_PRECEDES_CLAIM' using errcode='22023'; end if;
  elsif event_kind<>'CUSTODY_TRANSFER' then raise exception 'INVALID_ALLOCATIONS' using errcode='22023';
  end if;
  if event_kind in ('CUSTODY_TRANSFER','REFUND') then
   if jsonb_typeof(item->'source_version') is distinct from 'number' or coalesce(item->>'source_version','') !~ '^[1-9][0-9]*$'
    or (event_kind='CUSTODY_TRANSFER' and (item ? 'target_line_id' or item ? 'target_version' or item ? 'trip_id' or item ? 'consignment_id')) then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
   select * into source from public.journal_lines where id=(item->>'source_line_id')::uuid and business_id=actor.business_id;
   if source.id is null or not private.trip_access(actor.business_id,source.trip_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
   if source.party_id<>payer or source.account_purpose<>'CUSTODY_RECEIVABLE' or source.signed_amount<=0
    or (event_kind='REFUND' and source.trip_id is distinct from trip) then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
   if day<(select effective_date from public.financial_events where id=source.event_id) then raise exception 'PAYMENT_PRECEDES_SOURCE' using errcode='22023'; end if;
   if event_kind='CUSTODY_TRANSFER' then trip:=source.trip_id;consignment:=source.consignment_id; end if;
   source_id:=source.id;refs:=array_append(refs,source.id);
  elsif item ? 'source_line_id' or item ? 'source_version' then raise exception 'INVALID_SOURCE' using errcode='22023'; end if;
  select * into t from public.trips where id=trip and business_id=actor.business_id;
  if t.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
  if event_kind in ('ADVANCE','CUSTOMER_RECEIPT') and not(item ? 'target_line_id') and t.state='CANCELLED'
   then raise exception 'CANCELLED_TRIP' using errcode='22023'; end if;
  allocated:=allocated+amount;
 end loop;
 -- Credit entries cannot disguise existing customer claims, nor vice versa.
 if event_kind='CUSTOMER_RECEIPT' and (exists(select 1 from jsonb_array_elements(payload->'allocations') x where not(x ? 'target_line_id'))
  or exists(select 1 from jsonb_array_elements(coalesce(payload->'credits','[]')) x where x ? 'target_line_id')) then raise exception 'INVALID_CREDIT_COMPONENT' using errcode='22023'; end if;
 if allocated<>total then raise exception 'ALLOCATION_MISMATCH' using errcode='22023'; end if;
 digest:=encode(sha256(convert_to(jsonb_build_object('kind',event_kind,'version',expected_version,'payload',payload)::text,'UTF8')),'hex');
 select * into cached from public.idempotency_records r where r.business_id=actor.business_id and r.request_id=post_money_movement.request_id;
 if found then
  if cached.actor_id<>actor.id or cached.command<>event_kind or cached.payload_digest<>digest then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409'; end if;
  return cached.result;
 end if;
 if exists(select 1 from public.financial_events e where e.business_id=actor.business_id and e.request_id=post_money_movement.request_id) then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409'; end if;
 if not exists(select 1 from public.offices where id=office and archived_at is null)
  or not exists(select 1 from public.parties where id=payee and archived_at is null) then raise exception 'ACTIVE_RECIPIENT_OR_OFFICE_REQUIRED' using errcode='22023'; end if;
 for lock_id in select distinct x from unnest(refs) x order by x loop perform pg_advisory_xact_lock(hashtextextended('claim:'||lock_id::text,0)); end loop;
 for item in select * from jsonb_array_elements(items) loop
  foreach lock_id in array array[(item->>'target_line_id')::uuid,(item->>'source_line_id')::uuid] loop
   if lock_id is not null then
    state:=private.claim_state(lock_id);
    if (state->>'version')::bigint<>(case when lock_id=(item->>'target_line_id')::uuid then item->>'target_version' else item->>'source_version' end)::bigint
     then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409'; end if;
    select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(items) x
     where x->>'target_line_id'=lock_id::text or x->>'source_line_id'=lock_id::text;
    if (state->>'remaining')::numeric<allocated then raise exception 'INSUFFICIENT_SOURCE_OR_CLAIM' using errcode='22023'; end if;
   end if;
  end loop;
 end loop;
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,payer_id,payee_id,amount,request_id,reason,created_by)
  values(posting,actor.business_id,event_kind,day,actor.id,office,payer,payee,total,request_id,reason,actor.auth_user_id);
 for item in select * from jsonb_array_elements(items) loop
  source_id:=(item->>'source_line_id')::uuid;target_id:=(item->>'target_line_id')::uuid;source_event:=null;
  if target_id is not null then select * into target from public.journal_lines where id=target_id;trip:=target.trip_id;consignment:=target.consignment_id;
  elsif source_id is not null then select * into source from public.journal_lines where id=source_id;trip:=source.trip_id;consignment:=source.consignment_id;
  else trip:=(item->>'trip_id')::uuid;consignment:=(item->>'consignment_id')::uuid; end if;
  if source_id is not null then select event_id into source_event from public.journal_lines where id=source_id; end if;
  select * into t from public.trips where id=trip;
  amount:=public.parse_money(item->>'amount');
  debit_purpose:=case event_kind when 'PERSONAL_FUNDING' then 'OWNER_PAYABLE' when 'REFUND' then 'CUSTOMER_ADVANCE_CREDIT' else 'CUSTODY_RECEIVABLE' end;
  credit_purpose:=case event_kind when 'PERSONAL_FUNDING' then 'TRIP_FUNDING_PAYABLE' when 'CUSTODY_TRANSFER' then 'CUSTODY_RECEIVABLE' when 'REFUND' then 'CUSTODY_RECEIVABLE'
   when 'CUSTOMER_RECEIPT' then case when target_id is null then 'CUSTOMER_ADVANCE_CREDIT' else 'CUSTOMER_RECEIVABLE' end else 'CUSTOMER_ADVANCE_CREDIT' end;
  debit_party:=payee;credit_party:=payer;
  if event_kind='REFUND' then debit_party:=payee;credit_party:=payer; end if;
  insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
   values(actor.business_id,posting,debit_party,office,t.vehicle_id,trip,consignment,debit_purpose,amount,actor.auth_user_id),
   (actor.business_id,posting,credit_party,office,t.vehicle_id,trip,case when source_id is not null then (select consignment_id from public.journal_lines where id=source_id) else consignment end,credit_purpose,-amount,actor.auth_user_id);
  insert into public.allocations(business_id,event_id,trip_id,consignment_id,source_event_id,source_line_id,target_line_id,amount,component,created_by)
   values(actor.business_id,posting,trip,consignment,source_event,source_id,target_id,amount,'CASH',actor.auth_user_id);
 end loop;
 if (select sum(signed_amount) from public.journal_lines where event_id=posting)<>0 then raise exception 'UNBALANCED_JOURNAL' using errcode='23514'; end if;
 result:=jsonb_build_object('record_id',posting,'new_version',1,'kind',event_kind,'amount',total::numeric(18,2)::text,'effective_date',day,
  'allocations',(select jsonb_agg(jsonb_build_object('trip_id',a.trip_id,'amount',a.amount::text,'target_line_id',a.target_line_id,
   'target',case when a.target_line_id is not null then private.claim_state(a.target_line_id) end,'source',case when a.source_line_id is not null then private.claim_state(a.source_line_id) end)) from public.allocations a where event_id=posting));
 insert into public.audit_events(business_id,actor_id,office_id,record_id,record_type,action,reason,after_data,created_by)
  values(actor.business_id,actor.id,office,posting,'FINANCIAL_EVENT',event_kind,reason,result,actor.auth_user_id);
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by)
  values(actor.business_id,request_id,actor.id,event_kind,digest,result,actor.auth_user_id);
 return result;
end $$;
-- The recognition marker is read only; no permission to create earnings.
grant select on private.trip_recognition to carrier_finance;
alter function private.post_money_movement(text,uuid,integer,jsonb) owner to carrier_finance;
revoke all on function private.post_money_movement(text,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function private.post_money_movement(text,uuid,integer,jsonb) to carrier_security;
create or replace function public.post_financial_event(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if event_kind='ADVANCE_APPLICATION' and payload->>'payer_id' is distinct from payload->>'payee_id' then raise exception 'INVALID_PARTIES' using errcode='22023'; end if;
 if event_kind in ('OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','FUNDING_RECOVERY','ADVANCE_APPLICATION') or (event_kind='CUSTOMER_RECEIPT' and not(payload ? 'credits')) then
  return private.post_claim_event(event_kind,request_id,expected_version,payload);
 elsif event_kind in ('CUSTOMER_RECEIPT','ADVANCE','CUSTODY_TRANSFER','PERSONAL_FUNDING','REFUND') then
  return private.post_money_movement(event_kind,request_id,expected_version,payload);
 end if;
 raise exception 'WORKFLOW_NOT_AVAILABLE' using errcode='22023';
end $$;
revoke create on schema private from carrier_finance;
revoke carrier_finance,carrier_security from postgres;

-- Existing operational guards predate bulk event headers. Keep funded draft
-- identities and cancellation evidence intact until T10's correction plans.
create function private.protect_funded_draft() returns trigger
language plpgsql security definer set search_path='' as $$
declare affected uuid;
begin
 if tg_table_name='trips' then affected:=old.id; else affected:=old.trip_id; end if;
 if exists(select 1 from public.allocations a where a.trip_id=affected) then
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
revoke all on function private.protect_funded_draft() from public,anon,authenticated;
create trigger funded_trip_identity before update on public.trips for each row execute function private.protect_funded_draft();
create trigger funded_consignment_identity before update or delete on public.consignments for each row execute function private.protect_funded_draft();
