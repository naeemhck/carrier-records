-- T10: append-only corrections, explicit dependency review and cancellation.
grant carrier_finance,carrier_security,carrier_earnings to postgres;
grant create on schema public,private to carrier_finance;
grant create on schema private to carrier_earnings;
grant select on public.audit_events,public.staff_profiles to carrier_finance;
create policy correction_staff_read on public.staff_profiles for select to carrier_finance using(true);
create policy correction_audit_read on public.audit_events for select to carrier_finance using(true);
grant select,update on public.trips,public.consignments to carrier_finance;

create policy correction_trip_update on public.trips for update to carrier_finance using(true) with check(true);
create policy correction_load_update on public.consignments for update to carrier_finance using(true) with check(true);
grant execute on function public.calculate_quote(text,text,text,text,boolean),public.post_financial_event(text,uuid,integer,jsonb) to carrier_finance;

alter table public.idempotency_records add column command_payload jsonb;

-- This capability is transaction-local and unreachable from client roles. A
-- caller-controlled GUC is deliberately not used as an authorization bypass.
create table private.correction_context (
 transaction_id bigint primary key, business_id uuid not null references public.businesses(id),
 source_event_id uuid references public.financial_events(id), source_expense_id uuid references public.expenses(id),
 trip_id uuid references public.trips(id), reason text not null
);
grant select,insert,delete on private.correction_context to carrier_finance;
grant select on private.correction_context to carrier_security;

create function private.link_replacement() returns trigger language plpgsql security definer set search_path='' as $$
declare context private.correction_context; original public.expenses;
begin
 select * into context from private.correction_context where transaction_id=txid_current() and business_id=new.business_id;
 if context.source_event_id is not null then
  if tg_table_name='financial_events' then
   if new.kind<>'REVERSAL' then new.kind:='REPLACEMENT';new.replacement_of_id:=context.source_event_id;new.reason:=context.reason;end if;
  elsif tg_table_name='expenses' and context.source_expense_id is not null then
   new.replaces_expense_id:=context.source_expense_id;new.correction_reason:=context.reason;
   select * into original from public.expenses where id=context.source_expense_id;
   if (new.vehicle_id,new.trip_id) is not distinct from (original.vehicle_id,original.trip_id) then new.owner_id:=original.owner_id;end if;
  end if;
 end if;
 return new;
end $$;
create trigger correction_link before insert on public.financial_events for each row execute function private.link_replacement();
create trigger correction_link before insert on public.expenses for each row execute function private.link_replacement();

create function private.can_correct_event(event_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); e public.financial_events; l public.journal_lines; t public.trips;
begin
 select * into e from public.financial_events where id=event_id and business_id=actor.business_id;
 if actor.id is null or e.id is null or (actor.role<>'ADMIN' and e.actor_id<>actor.id) or not private.office_access(actor.business_id,e.office_id) then return false;end if;
 for l in select * from public.journal_lines where public.journal_lines.event_id=e.id loop
  if not(case when l.trip_id is null then private.office_access(actor.business_id,l.office_id) else private.trip_access(actor.business_id,l.trip_id) end) then return false;end if;
 end loop;
 if e.trip_id is not null and not private.trip_access(actor.business_id,e.trip_id) then return false;end if;
 if e.kind='DISPATCH' or (e.kind='REPLACEMENT' and exists(select 1 from public.financial_events f where f.id=e.replacement_of_id and f.kind='DISPATCH')) then
  select * into t from public.trips where id=e.trip_id;
  if not private.office_access(actor.business_id,t.origin_office_id) then return false;end if;
 end if;
 return true;
end $$;

create function private.event_dependents(event_id uuid) returns uuid[] language sql stable security definer set search_path='' as $$
 with recursive graph(id) as (
  select event_id union
  select a.event_id from graph g join public.journal_lines l on l.event_id=g.id
   join public.allocations a on a.source_line_id=l.id or a.target_line_id=l.id
   where a.event_id<>g.id and a.reversal_of_id is null
   and not exists(select 1 from public.allocations r where r.reversal_of_id=a.id)
   and not exists(select 1 from public.financial_events r where r.reversal_of_id=a.event_id)
 ) select array_agg(id order by id) from graph
$$;

create function public.review_financial_correction(event_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare ids uuid[]; i uuid; state jsonb; events jsonb;
begin
 ids:=private.event_dependents(event_id);
 foreach i in array ids loop
  if not private.can_correct_event(i) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 end loop;
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'kind',e.kind,'effective_date',e.effective_date,'amount',e.amount::text,'reversed',exists(select 1 from public.financial_events r where r.reversal_of_id=e.id)) order by e.id),'[]') into events from public.financial_events e where e.id=any(ids);
 select coalesce(jsonb_agg(jsonb_build_object('line_id',l.id,'state',private.claim_state(l.id)) order by l.id),'[]') into state from public.journal_lines l where l.event_id=any(ids) or l.id in(select a.source_line_id from public.allocations a where a.event_id=any(ids)) or l.id in(select a.target_line_id from public.allocations a where a.event_id=any(ids));
 return jsonb_build_object('events',events,'claims',state,'review_token',encode(sha256(convert_to(jsonb_build_object('events',events,'claims',state)::text,'UTF8')),'hex'));
end $$;

create function private.reverse_event(event_id uuid,reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); e public.financial_events; r uuid:=gen_random_uuid();
begin
 if not private.can_correct_event(event_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select * into e from public.financial_events where id=event_id;
 if e.kind='REVERSAL' or exists(select 1 from public.financial_events f where f.reversal_of_id=e.id) then raise exception 'ALREADY_REVERSED' using errcode='PT409';end if;
 if exists(select 1 from public.allocations a join public.journal_lines l on l.id=a.source_line_id or l.id=a.target_line_id where l.event_id=e.id and a.event_id<>e.id and a.reversal_of_id is null and not exists(select 1 from public.allocations z where z.reversal_of_id=a.id)) then raise exception 'DEPENDENT_SETTLEMENTS' using errcode='22023';end if;
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,payer_id,payee_id,amount,request_id,reversal_of_id,reason,created_by)
 values(r,e.business_id,'REVERSAL',e.effective_date,actor.id,e.office_id,e.vehicle_id,e.trip_id,e.consignment_id,e.expense_id,e.payer_id,e.payee_id,e.amount,gen_random_uuid(),e.id,reason,actor.auth_user_id);
 insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,account_purpose,signed_amount,created_by)
 select business_id,r,party_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,account_purpose,-signed_amount,actor.auth_user_id from public.journal_lines where public.journal_lines.event_id=e.id;
 insert into public.allocations(business_id,event_id,source_event_id,source_line_id,target_line_id,trip_id,consignment_id,expense_id,amount,component,reversal_of_id,created_by)
 select business_id,r,source_event_id,source_line_id,target_line_id,trip_id,consignment_id,expense_id,amount,component,id,actor.auth_user_id from public.allocations a where a.event_id=e.id and a.reversal_of_id is null and not exists(select 1 from public.allocations z where z.reversal_of_id=a.id);
 insert into public.audit_events(business_id,actor_id,office_id,trip_id,record_id,record_type,action,reason,before_data,after_data,created_by)
 values(e.business_id,actor.id,e.office_id,e.trip_id,e.id,'FINANCIAL_EVENT','REVERSE',reason,jsonb_build_object('event_id',e.id,'effective_date',e.effective_date),jsonb_build_object('reversal_id',r),actor.auth_user_id);
 return r;
end $$;

create function private.replace_recognition(source_id uuid,replacement_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); source public.financial_events; replacement public.financial_events;
begin
 select * into source from public.financial_events where id=source_id;
 select * into replacement from public.financial_events where id=replacement_id;
 if actor.id is null or source.business_id is distinct from actor.business_id or replacement.replacement_of_id is distinct from source.id or replacement.kind<>'REPLACEMENT' or replacement.trip_id is distinct from source.trip_id or replacement.consignment_id is distinct from source.consignment_id or not private.office_access(actor.business_id,source.office_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 update private.trip_recognition set event_ids=array_replace(event_ids,source.id,replacement.id),generation=generation+1 where trip_id=source.trip_id and source.id=any(event_ids);
 if not found then raise exception 'RECOGNITION_HISTORY_CONFLICT' using errcode='PT409';end if;
end $$;
alter function private.replace_recognition(uuid,uuid) owner to carrier_earnings;
revoke all on function private.replace_recognition(uuid,uuid) from public,anon,authenticated;
grant execute on function private.replace_recognition(uuid,uuid) to carrier_finance;

create function private.is_cancellation_event(event_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 with recursive originals as(select id,kind,replacement_of_id from public.financial_events where id=event_id union all select f.id,f.kind,f.replacement_of_id from originals o join public.financial_events f on f.id=o.replacement_of_id) select exists(select 1 from originals where kind='ADJUSTMENT')
$$;
alter function private.is_cancellation_event(uuid) owner to carrier_finance;
revoke all on function private.is_cancellation_event(uuid) from public,anon,authenticated;
grant execute on function private.is_cancellation_event(uuid) to carrier_security;

create function private.post_cancellation_adjustment(t public.trips,c public.consignments,quote jsonb,day date,reason text) returns uuid language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); l public.journal_lines; posting uuid; closing uuid; rem numeric; paid numeric; fee numeric; residual numeric; purpose text;
begin
 if actor.id is null or t.business_id is distinct from actor.business_id or c.trip_id is distinct from t.id or not private.office_access(actor.business_id,t.origin_office_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
  posting:=gen_random_uuid();
  insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id,reason,created_by)
  values(posting,t.business_id,'ADJUSTMENT',day,actor.id,t.origin_office_id,t.vehicle_id,t.id,c.id,(quote->>'customer_charge')::numeric,gen_random_uuid(),reason,actor.auth_user_id);
  -- Sum original earnings only, never expense/settlement journal lines. T06
  -- date replacements retain the current recognition IDs.
  for l in select (jsonb_populate_record(null::public.journal_lines,
    coalesce(to_jsonb(j),'{}')||jsonb_build_object('account_purpose',v.purpose,'party_id',v.party,'signed_amount',coalesce(j.signed_amount,0)))).*
   from (values('CUSTOMER_RECEIVABLE',c.customer_id),('OWNER_PAYABLE',t.owner_id),('BROKER_COMMISSION_PAYABLE',c.broker_id)) v(purpose,party)
   left join (public.journal_lines j join private.trip_recognition r on j.event_id=any(r.event_ids) and r.trip_id=t.id)
    on j.consignment_id=c.id and j.account_purpose=v.purpose where v.party is not null loop
   rem:=coalesce((private.claim_state(l.id)->>'remaining')::numeric,0);paid:=abs(l.signed_amount)-rem;
   fee:=(quote->>case l.account_purpose when 'CUSTOMER_RECEIVABLE' then 'customer_charge' when 'OWNER_PAYABLE' then 'owner_entitlement' else 'commission' end)::numeric;
   if rem>0 then
    closing:=gen_random_uuid();
    insert into public.journal_lines(id,business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    values(closing,t.business_id,posting,l.party_id,t.origin_office_id,t.vehicle_id,t.id,c.id,l.account_purpose,case when l.signed_amount>0 then -rem else rem end,actor.auth_user_id);
    insert into public.allocations(business_id,event_id,source_event_id,source_line_id,target_line_id,trip_id,consignment_id,amount,component,created_by)
    values(t.business_id,posting,l.event_id,l.id,closing,t.id,c.id,rem,'OFFSET',actor.auth_user_id);
   end if;
   residual:=fee-paid;
   purpose:=l.account_purpose;
   if purpose='CUSTOMER_RECEIVABLE' and residual<0 then purpose:='CUSTOMER_ADVANCE_CREDIT';end if;
   if residual<>0 then
    insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
    values(t.business_id,posting,l.party_id,t.origin_office_id,t.vehicle_id,t.id,c.id,purpose,case when l.account_purpose='CUSTOMER_RECEIVABLE' then residual else -residual end,actor.auth_user_id);
   end if;
  end loop;

 return posting;
end $$;
alter function private.post_cancellation_adjustment(public.trips,public.consignments,jsonb,date,text) owner to carrier_finance;
revoke all on function private.post_cancellation_adjustment(public.trips,public.consignments,jsonb,date,text) from public,anon,authenticated;

create function public.correct_financial_event(event_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); e public.financial_events; cached public.idempotency_records; ids uuid[]; supplied uuid[]; remaining uuid[]; i uuid; leaf uuid;
 review jsonb; reason text; digest text; result jsonb; replacement jsonb; semantic text; reversal uuid; initial_states jsonb; item jsonb; adjusted jsonb; ref uuid; field text; version_field text; before_version bigint; after_version bigint; cons public.consignments; trip public.trips; quote jsonb; new_event uuid; is_earnings boolean; is_cancellation boolean;
begin
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));actor:=private.current_staff();
 if actor.id is null or not private.can_correct_event(event_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if request_id is null or expected_version is distinct from 1 or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>60000
 or exists(select 1 from jsonb_object_keys(payload) k where k not in('reason','review_token','unwind_event_ids','replacement')) or jsonb_typeof(payload->'reason') is distinct from 'string' or jsonb_typeof(payload->'unwind_event_ids') is distinct from 'array' then raise exception 'INVALID_CORRECTION' using errcode='22023';end if;
 reason:=btrim(payload->>'reason');if coalesce(length(reason),0) not between 1 and 500 then raise exception 'REASON_REQUIRED' using errcode='22023';end if;
 select * into e from public.financial_events where id=event_id;
 select coalesce(array_agg(v::uuid order by v::uuid),array[]::uuid[]) into supplied from jsonb_array_elements_text(payload->'unwind_event_ids') v;
 foreach i in array supplied loop if not private.can_correct_event(i) then raise exception 'FORBIDDEN' using errcode='42501';end if;end loop;
 digest:=encode(sha256(convert_to(jsonb_build_object('event',event_id,'version',expected_version,'payload',payload)::text,'UTF8')),'hex');
 select * into cached from public.idempotency_records r where r.business_id=actor.business_id and r.request_id=correct_financial_event.request_id;
 if found then if cached.actor_id<>actor.id or cached.command<>'CORRECT' or cached.payload_digest<>digest then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;return cached.result;end if;
 review:=public.review_financial_correction(event_id);
 if payload->>'review_token' is distinct from review->>'review_token' then raise exception 'VERSION_CONFLICT' using errcode='PT409';end if;
 ids:=private.event_dependents(event_id);initial_states:=review->'claims';
 if supplied is distinct from array(select v from unnest(ids) v where v<>event_id order by v) then raise exception 'EXPLICIT_DEPENDENCY_PLAN_REQUIRED' using errcode='22023';end if;
 -- Expense money represents an actual incurred cost, not an incidental
 -- settlement that can silently disappear when its source is corrected.
 if exists(select 1 from public.financial_events f where f.id=any(supplied) and (f.expense_id is not null or f.kind in('DISPATCH','ADJUSTMENT','REVERSAL'))) then raise exception 'CORRECT_DEPENDENT_EXPENSE_SEPARATELY' using errcode='22023';end if;
 is_cancellation:=private.is_cancellation_event(e.id);
 if not is_cancellation and exists(select 1 from public.journal_lines j join public.trips t on t.id=j.trip_id where j.event_id=e.id and t.state='CANCELLED') then raise exception 'CANCELLED_TRIP_REQUIRES_REVIEWED_ADJUSTMENT' using errcode='22023';end if;
 if e.kind='REVERSAL' then raise exception 'USE_OPERATIONAL_CORRECTION_OR_CANCELLATION' using errcode='22023';end if;
 remaining:=supplied;
 while cardinality(remaining)>0 loop
  select v into leaf from unnest(remaining) v where cardinality(private.event_dependents(v))=1 order by v limit 1;
  if leaf is null then raise exception 'DEPENDENT_SETTLEMENTS' using errcode='22023';end if;
  perform private.reverse_event(leaf,reason);remaining:=array_remove(remaining,leaf);
 end loop;
 reversal:=private.reverse_event(event_id,reason);
 replacement:=payload->'replacement';is_earnings:=e.kind='DISPATCH' or exists(select 1 from private.trip_recognition b where e.id=any(b.event_ids));
 if (is_earnings or is_cancellation) and (replacement is null or replacement='null'::jsonb) then raise exception 'EARNINGS_REQUIRE_REPLACEMENT' using errcode='22023';end if;
 if replacement is not null and replacement<>'null'::jsonb then
  if jsonb_typeof(replacement) is distinct from 'object' then raise exception 'INVALID_REPLACEMENT' using errcode='22023';end if;
  if is_cancellation then
   if exists(select 1 from jsonb_object_keys(replacement) k where k not in('quoted_amount','quote_mode','commission_method','commission_value','effective_date')) or jsonb_typeof(replacement->'quoted_amount') is distinct from 'string' or jsonb_typeof(replacement->'commission_value') is distinct from 'string' then raise exception 'INVALID_CANCELLATION_FEE' using errcode='22023';end if;
   select * into cons from public.consignments where id=e.consignment_id;
   select * into trip from public.trips where id=e.trip_id;
   quote:=public.calculate_quote(replacement->>'quoted_amount',replacement->>'quote_mode',replacement->>'commission_method',replacement->>'commission_value',cons.broker_id is not null);
   if public.parse_business_date(replacement->>'effective_date')<trip.dispatch_date then raise exception 'CANCELLATION_PRECEDES_DISPATCH' using errcode='22023';end if;
   insert into private.correction_context values(txid_current(),e.business_id,e.id,null,null,reason);
   new_event:=private.post_cancellation_adjustment(trip,cons,quote,public.parse_business_date(replacement->>'effective_date'),reason);
   delete from private.correction_context where transaction_id=txid_current();
   result:=jsonb_build_object('record_id',new_event,'kind','ADJUSTMENT','quote',quote);
  elsif is_earnings then
   if not private.office_access(actor.business_id,e.office_id) or exists(select 1 from jsonb_object_keys(replacement) k where k not in('quoted_amount','quote_mode','commission_method','commission_value','effective_date')) or jsonb_typeof(replacement->'quoted_amount') is distinct from 'string' or jsonb_typeof(replacement->'commission_value') is distinct from 'string' or replacement->>'effective_date' is distinct from e.effective_date::text then raise exception 'INVALID_FARE_CORRECTION' using errcode='22023';end if;
   select * into cons from public.consignments where id=e.consignment_id for update;
   select * into trip from public.trips where id=e.trip_id for update;
   if cons.state='CANCELLED' or not private.office_access(actor.business_id,trip.origin_office_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
   quote:=public.calculate_quote(replacement->>'quoted_amount',replacement->>'quote_mode',replacement->>'commission_method',replacement->>'commission_value',cons.broker_id is not null);
   update public.consignments set quoted_amount=public.parse_money(replacement->>'quoted_amount'),quote_mode=replacement->>'quote_mode',commission_method=replacement->>'commission_method',commission_value=(replacement->>'commission_value')::numeric,version=version+1 where id=cons.id;
   update public.trips set version=version+1 where id=trip.id;
   new_event:=gen_random_uuid();
   insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,vehicle_id,trip_id,consignment_id,amount,request_id,replacement_of_id,reason,created_by)
   values(new_event,e.business_id,'REPLACEMENT',e.effective_date,actor.id,trip.origin_office_id,trip.vehicle_id,trip.id,cons.id,(quote->>'customer_charge')::numeric,gen_random_uuid(),e.id,reason,actor.auth_user_id);
   insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
   select e.business_id,new_event,v.party,trip.origin_office_id,trip.vehicle_id,trip.id,cons.id,v.purpose,v.amount,actor.auth_user_id from (values
    (cons.customer_id,'CUSTOMER_RECEIVABLE',(quote->>'customer_charge')::numeric),
    (trip.owner_id,'OWNER_PAYABLE',-(quote->>'owner_entitlement')::numeric),
    (cons.broker_id,'BROKER_COMMISSION_PAYABLE',-(quote->>'commission')::numeric)) v(party,purpose,amount) where v.amount<>0;
   perform private.replace_recognition(e.id,new_event);
   result:=jsonb_build_object('record_id',new_event,'kind','DISPATCH','quote',quote);
   insert into public.audit_events(business_id,actor_id,office_id,trip_id,record_id,record_type,action,reason,before_data,after_data,created_by)
   values(e.business_id,actor.id,trip.origin_office_id,trip.id,cons.id,'CONSIGNMENT','CORRECT_FARE',reason,jsonb_build_object('quoted_amount',cons.quoted_amount::text,'customer_charge',cons.customer_charge::text,'owner_entitlement',cons.owner_entitlement::text,'commission',cons.commission::text),quote,actor.auth_user_id);
  else
  select z.command into semantic from public.idempotency_records z where z.business_id=e.business_id and z.request_id=e.request_id;
  if semantic is null or semantic='CORRECT' then raise exception 'UNSUPPORTED_REPLACEMENT' using errcode='22023';end if;
  -- The reviewed source claims gain revisions when allocations unwind. Only
  -- those reviewed references are advanced; new references retain client versions.
  adjusted:='[]'::jsonb;
  for item in select * from jsonb_array_elements(replacement->'allocations') loop
   foreach field in array array['target_line_id','source_line_id','line_id'] loop
    if item ? field then
     ref:=(item->>field)::uuid;version_field:=case field when 'line_id' then 'version' when 'target_line_id' then 'target_version' else 'source_version' end;
     select (x->'state'->>'version')::bigint into before_version from jsonb_array_elements(initial_states) x where x->>'line_id'=ref::text;
     if before_version is not null then
      if (item->>version_field)::bigint is distinct from before_version then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409';end if;
      after_version:=(private.claim_state(ref)->>'version')::bigint;
      item:=item||jsonb_build_object(version_field,after_version);
     end if;
    end if;
   end loop;
   adjusted:=adjusted||jsonb_build_array(item);
  end loop;
  replacement:=replacement||jsonb_build_object('allocations',adjusted);
  insert into private.correction_context values(txid_current(),e.business_id,e.id,e.expense_id,null,reason);
  result:=public.post_financial_event(semantic,gen_random_uuid(),0,replacement);
  delete from private.correction_context where transaction_id=txid_current();
  end if;
 else result:='{}'::jsonb;end if;
 result:=jsonb_build_object('record_id',e.id,'new_version',1,'reversal_id',reversal,'replacement',result,'unwound_event_ids',supplied);
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by,command_payload) values(actor.business_id,request_id,actor.id,'CORRECT',digest,result,actor.auth_user_id,payload);
 return result;
end $$;

create function private.expense_effective(expense_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); x public.expenses;
begin
 select * into x from public.expenses where id=expense_id and business_id=actor.business_id;
 if actor.id is null or x.id is null or not(case when x.trip_id is null then private.office_access(x.business_id,x.office_id) else private.trip_access(x.business_id,x.trip_id) end) then return false;end if;
 return not exists(select 1 from public.expenses replacement where replacement.replaces_expense_id=x.id) and not exists(select 1 from public.financial_events e join public.financial_events r on r.reversal_of_id=e.id where e.expense_id=x.id and e.kind in('EXPENSE','REPLACEMENT'));
end $$;
alter function private.expense_effective(uuid) owner to carrier_finance;
revoke all on function private.expense_effective(uuid) from public,anon;
grant execute on function private.expense_effective(uuid) to authenticated;

-- Effective expense totals exclude independently voided/replaced expenses,
-- without deleting their source rows or evidence links.
create or replace function public.get_expense_totals(vehicle_id uuid,from_date date,to_date date,trip_id uuid default null) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('scope','PERMITTED_RECORDS','date_basis',case when get_expense_totals.trip_id is null then 'EXPENSE_DATE' else 'LIFETIME_TRIP' end,'vehicle_cost',coalesce(sum(x.amount),0)::numeric(38,2)::text,'owner_cost',coalesce(sum(x.amount) filter(where x.cost_bearer_id=x.owner_id),0)::numeric(38,2)::text)
 from public.expenses x where x.state='CONFIRMED' and x.vehicle_id=get_expense_totals.vehicle_id and (case when get_expense_totals.trip_id is not null then x.trip_id=get_expense_totals.trip_id else x.expense_date between from_date and to_date end)
 and not exists(select 1 from public.expenses r where r.replaces_expense_id=x.id)
 and private.expense_effective(x.id)
$$;

-- Cancellation is a price adjustment, never a reversal of actual collection,
-- settlement or diesel. Closing allocations consume old outstanding claims;
-- residual overpayments become identified credit or recovery claims.
create function public.review_cancellation(trip_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); t public.trips; state jsonb;
begin
 select * into t from public.trips where id=trip_id and business_id=actor.business_id;
 if actor.id is null or t.id is null or not private.office_access(actor.business_id,t.origin_office_id) or (actor.role<>'ADMIN' and t.created_by<>actor.auth_user_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object('line_id',l.id,'state',private.claim_state(l.id)) order by l.id),'[]') into state from public.journal_lines l where l.trip_id=t.id;
 return jsonb_build_object('version',t.version,'claims',state,'review_token',encode(sha256(convert_to(jsonb_build_object('version',t.version,'claims',state)::text,'UTF8')),'hex'));
end $$;

create function public.cancel_and_adjust(trip_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); t public.trips; c public.consignments; l public.journal_lines; cached public.idempotency_records;
 item jsonb; quote jsonb; review jsonb; reason text; digest text; result jsonb; day date; posting uuid; closing uuid; rem numeric; paid numeric; fee numeric; residual numeric; purpose text;
begin
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));actor:=private.current_staff();
 review:=public.review_cancellation(trip_id);
 select * into t from public.trips where id=trip_id for update;
 perform pg_advisory_xact_lock(hashtextextended('trip-vehicle:'||t.vehicle_id::text,0));
 if request_id is null or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>60000 or exists(select 1 from jsonb_object_keys(payload) k where k not in('reason','review_token','effective_date','consignments')) or jsonb_typeof(payload->'reason') is distinct from 'string' or jsonb_typeof(payload->'consignments') is distinct from 'array' then raise exception 'INVALID_CANCELLATION' using errcode='22023';end if;
 reason:=btrim(payload->>'reason');if coalesce(length(reason),0) not between 1 and 500 then raise exception 'REASON_REQUIRED' using errcode='22023';end if;
 day:=public.parse_business_date(payload->>'effective_date');
 digest:=encode(sha256(convert_to(jsonb_build_object('trip',trip_id,'version',expected_version,'payload',payload)::text,'UTF8')),'hex');
 select * into cached from public.idempotency_records r where r.business_id=actor.business_id and r.request_id=cancel_and_adjust.request_id;
 if found then if cached.actor_id<>actor.id or cached.command<>'CANCEL' or cached.payload_digest<>digest then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;return cached.result;end if;
 if expected_version is distinct from t.version or payload->>'review_token' is distinct from review->>'review_token' or t.state='CANCELLED' then raise exception 'VERSION_CONFLICT' using errcode='PT409';end if;
 if t.dispatch_date is not null and day<t.dispatch_date then raise exception 'CANCELLATION_PRECEDES_DISPATCH' using errcode='22023';end if;
 if jsonb_array_length(payload->'consignments')<>(select count(*) from public.consignments where public.consignments.trip_id=t.id and state<>'CANCELLED') or exists(select 1 from jsonb_array_elements(payload->'consignments') x group by x->>'id' having count(*)>1) then raise exception 'EXPLICIT_CONSIGNMENT_PLAN_REQUIRED' using errcode='22023';end if;
 insert into private.correction_context values(txid_current(),actor.business_id,null,null,t.id,reason);
 for item in select * from jsonb_array_elements(payload->'consignments') loop
  if exists(select 1 from jsonb_object_keys(item) k where k not in('id','quoted_amount','quote_mode','commission_method','commission_value')) or jsonb_typeof(item->'quoted_amount') is distinct from 'string' or jsonb_typeof(item->'commission_value') is distinct from 'string' then raise exception 'INVALID_CANCELLATION_FEE' using errcode='22023';end if;
  select * into c from public.consignments where id=(item->>'id')::uuid and public.consignments.trip_id=t.id and state<>'CANCELLED';
  if c.id is null then raise exception 'INVALID_CONSIGNMENT' using errcode='22023';end if;
  quote:=public.calculate_quote(item->>'quoted_amount',item->>'quote_mode',item->>'commission_method',item->>'commission_value',c.broker_id is not null);
  if t.state='DRAFT' and (quote->>'customer_charge')::numeric<>0 then raise exception 'UNDISPATCHED_FEE_REQUIRES_DISPATCH' using errcode='22023';end if;
  posting:=private.post_cancellation_adjustment(t,c,quote,day,reason);
  update public.consignments set state='CANCELLED',version=version+1 where id=c.id;
 end loop;
 update public.trips set state='CANCELLED',version=version+1 where id=t.id;
 delete from private.correction_context where transaction_id=txid_current();
 result:=jsonb_build_object('record_id',t.id,'new_version',t.version+1,'state','CANCELLED','effective_date',day,'refund_status','NOT_POSTED','expenses','PRESERVED');
 insert into public.audit_events(business_id,actor_id,office_id,trip_id,record_id,record_type,action,reason,before_data,after_data,created_by)
 values(t.business_id,actor.id,t.origin_office_id,t.id,t.id,'TRIP','CANCEL_ADJUST',reason,jsonb_build_object('state',t.state,'version',t.version,'consignments',payload->'consignments'),result,actor.auth_user_id);
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by,command_payload) values(t.business_id,request_id,actor.id,'CANCEL',digest,result,actor.auth_user_id,payload);
 return result;
end $$;

create or replace function private.protect_funded_draft() returns trigger
language plpgsql security definer set search_path='' as $$
declare affected uuid;
begin
 if tg_table_name='trips' then affected:=old.id; else affected:=old.trip_id; end if;
 if tg_op='UPDATE' and new.state='CANCELLED' and exists(select 1 from private.correction_context q where q.transaction_id=txid_current() and q.trip_id=affected and q.source_event_id is null) then
  if tg_table_name='trips' and (to_jsonb(new)-'state'-'version'-'updated_at')=(to_jsonb(old)-'state'-'version'-'updated_at') then return new;end if;
  if tg_table_name='consignments' and (to_jsonb(new)-'state'-'version'-'updated_at')=(to_jsonb(old)-'state'-'version'-'updated_at') then return new;end if;
 end if;
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
 if event_kind is null or event_kind not in ('CUSTOMER_RECEIPT','OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','FUNDING_RECOVERY','REIMBURSEMENT','EXPENSE_RECOVERY','EXPENSE_OFFSET','ADVANCE_APPLICATION','RECOVERY_RECEIPT')
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
 target_party:=case when event_kind in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY','RECOVERY_RECEIPT','EXPENSE_OFFSET','ADVANCE_APPLICATION','RECOVERY_RECEIPT') then payer else payee end;
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
  if event_kind='RECOVERY_RECEIPT' then
   target_purpose:=target.account_purpose;
   if target_purpose not in('OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE') or target.signed_amount<=0 or not private.is_cancellation_event(target.event_id) then raise exception 'INVALID_RECOVERY_CLAIM' using errcode='22023';end if;
  end if;
  if target.account_purpose<>target_purpose or target.party_id<>target_party
   or (target_purpose in ('CUSTOMER_RECEIVABLE','PARTY_COST_RECOVERY') and target.signed_amount<=0)
   or (event_kind<>'RECOVERY_RECEIPT' and target_purpose not in ('CUSTOMER_RECEIVABLE','PARTY_COST_RECOVERY') and target.signed_amount>=0)
   then raise exception 'INVALID_CLAIM' using errcode='22023'; end if;
  if event_kind in ('EXPENSE_RECOVERY','EXPENSE_OFFSET') and (target.expense_id is null or not exists(select 1 from public.expenses x where x.id=target.expense_id and x.cost_bearer_id=payer and x.state='CONFIRMED' and x.business_id=actor.business_id)) then raise exception 'EXPENSE_CLAIM_REQUIRED' using errcode='22023'; end if;
  if event_kind='REIMBURSEMENT' and (target.expense_id is null or not exists(select 1 from public.expenses x where x.id=target.expense_id and x.business_id=actor.business_id and x.trip_id is not distinct from target.trip_id and x.payer_id=target.party_id and x.state='CONFIRMED')) then raise exception 'EXPENSE_CLAIM_REQUIRED' using errcode='22023'; end if;
  if business_date<(select effective_date from public.financial_events where id=target.event_id) then raise exception 'PAYMENT_PRECEDES_CLAIM' using errcode='22023'; end if;
  refs:=array_append(refs,target.id);
  if event_kind in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY','RECOVERY_RECEIPT') then
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
  if event_kind not in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY','RECOVERY_RECEIPT') then
   state:=private.claim_state((item->>'source_line_id')::uuid);
   if (state->>'version')::bigint<>(item->>'source_version')::bigint then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409'; end if;
   select sum(public.parse_money(x->>'amount')) into allocated from jsonb_array_elements(payload->'allocations') x where x->>'source_line_id'=item->>'source_line_id';
   if (state->>'remaining')::numeric<allocated then raise exception 'INSUFFICIENT_SOURCE' using errcode='22023'; end if;
  end if;
 end loop;
 posting_id:=gen_random_uuid();
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,payer_id,payee_id,amount,request_id,reason,created_by)
 values(posting_id,actor.business_id,case when event_kind in ('EXPENSE_RECOVERY','EXPENSE_OFFSET','RECOVERY_RECEIPT') then 'REIMBURSEMENT' else event_kind end,business_date,actor.id,office,payer,payee,total,request_id,reason,actor.auth_user_id);
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid;
  if event_kind='RECOVERY_RECEIPT' then target_purpose:=target.account_purpose;end if;
  amount:=public.parse_money(item->>'amount'); debit_id:=gen_random_uuid();credit_id:=gen_random_uuid();
  if event_kind in ('CUSTOMER_RECEIPT','EXPENSE_RECOVERY','RECOVERY_RECEIPT') then
   insert into public.journal_lines(id,business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,expense_id,account_purpose,signed_amount,created_by)
    values(debit_id,actor.business_id,posting_id,payee,office,target.vehicle_id,target.trip_id,target.consignment_id,target.expense_id,'CUSTODY_RECEIVABLE',amount,actor.auth_user_id),
    (credit_id,actor.business_id,posting_id,payer,office,target.vehicle_id,target.trip_id,target.consignment_id,target.expense_id,target_purpose,-amount,actor.auth_user_id);
   insert into public.allocations(business_id,event_id,trip_id,consignment_id,expense_id,source_line_id,target_line_id,amount,component,created_by)
    values(actor.business_id,posting_id,target.trip_id,target.consignment_id,target.expense_id,case when event_kind='RECOVERY_RECEIPT' then credit_id end,target.id,amount,'CASH',actor.auth_user_id);
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
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by,command_payload) values(actor.business_id,request_id,actor.id,event_kind,digest,result,actor.auth_user_id,payload);
 return result;
end $$;



create or replace function public.post_financial_event(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if event_kind='REFUND_FUNDING' then return private.post_refund_funding(request_id,expected_version,payload);end if;
 if event_kind='EXPENSE' then return private.post_expense(request_id,expected_version,payload); end if;
 if event_kind='ADVANCE_APPLICATION' and payload->>'payer_id' is distinct from payload->>'payee_id' then raise exception 'INVALID_PARTIES' using errcode='22023'; end if;
 if event_kind in ('OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','FUNDING_RECOVERY','ADVANCE_APPLICATION','REIMBURSEMENT','EXPENSE_RECOVERY','EXPENSE_OFFSET','RECOVERY_RECEIPT') or (event_kind='CUSTOMER_RECEIPT' and not(payload ? 'credits')) then
  return private.post_claim_event(event_kind,request_id,expected_version,payload);
 elsif event_kind in ('CUSTOMER_RECEIPT','ADVANCE','CUSTODY_TRANSFER','PERSONAL_FUNDING','REFUND') then
  return private.post_money_movement(event_kind,request_id,expected_version,payload);
 end if;
 raise exception 'WORKFLOW_NOT_AVAILABLE' using errcode='22023';
end $$;
create or replace function public.get_trip_financials(trip_id uuid) returns jsonb
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
  'direction',case when l.account_purpose in('OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE') and l.signed_amount>0 then 'RECOVERY' else 'NORMAL' end,'remaining',s.v->>'remaining','version',(s.v->>'version')::bigint) order by l.id),'[]') into claims
 from public.journal_lines l join public.financial_events e on e.id=l.event_id
 cross join lateral(select private.claim_state(l.id) v) s
 where l.business_id=actor.business_id and l.trip_id=get_trip_financials.trip_id and (s.v->>'remaining')::numeric>0
  and ((l.account_purpose in('OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE') and l.signed_amount>0 and private.is_cancellation_event(l.event_id)) or (l.account_purpose in ('CUSTOMER_RECEIVABLE','CUSTODY_RECEIVABLE','PARTY_COST_RECOVERY') and l.signed_amount>0)
    or (l.account_purpose in ('OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE','CUSTOMER_ADVANCE_CREDIT','EXPENSE_REIMBURSEMENT_PAYABLE','TRIP_FUNDING_PAYABLE') and l.signed_amount<0));
 return jsonb_build_object('scope','TRIP','complete',true,'label','This permitted trip only; not a complete party or business balance',
  'balances',balances,'claims',claims);
end $$;


create or replace function private.post_expense(request_id uuid,expected_version integer,payload jsonb) returns jsonb
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
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by,command_payload) values(actor.business_id,request_id,actor.id,'EXPENSE',digest,result,actor.auth_user_id,payload);
 return result;
end $$;

create or replace function private.post_money_movement(event_kind text,request_id uuid,expected_version integer,payload jsonb) returns jsonb
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
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by,command_payload) values(actor.business_id,request_id,actor.id,event_kind,digest,result,actor.auth_user_id,payload);
 return result;
end $$;
create function private.post_refund_funding(request_id uuid,expected_version integer,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); cached public.idempotency_records; item jsonb; target public.journal_lines; state jsonb;
 payer uuid; customer uuid; office uuid; day date; total numeric; n numeric; digest text; reason text; posting uuid:=gen_random_uuid(); result jsonb;
begin
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||actor.business_id::text,0));actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if request_id is null or expected_version is distinct from 0 or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>50000 or exists(select 1 from jsonb_object_keys(payload) k where k not in('payer_id','payee_id','office_id','effective_date','amount','reason','allocations')) or jsonb_typeof(payload->'amount') is distinct from 'string' or jsonb_typeof(payload->'reason') is distinct from 'string' or jsonb_typeof(payload->'allocations') is distinct from 'array' then raise exception 'INVALID_REFUND_FUNDING' using errcode='22023';end if;
 payer:=(payload->>'payer_id')::uuid;customer:=(payload->>'payee_id')::uuid;office:=(payload->>'office_id')::uuid;
 day:=public.parse_business_date(payload->>'effective_date');total:=public.parse_money(payload->>'amount');reason:=btrim(payload->>'reason');
 if total<=0 or length(reason) not between 1 and 500 or jsonb_array_length(payload->'allocations') not between 1 and 100 then raise exception 'INVALID_REFUND_FUNDING' using errcode='22023';end if;
 if not private.office_access(actor.business_id,office) or not exists(select 1 from public.parties p where p.id=payer and p.business_id=actor.business_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  if jsonb_typeof(item->'amount') is distinct from 'string' or exists(select 1 from jsonb_object_keys(item) k where k not in('target_line_id','target_version','amount')) or coalesce(item->>'target_version','') !~ '^[1-9][0-9]*$' then raise exception 'INVALID_ALLOCATIONS' using errcode='22023';end if;
  select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid and business_id=actor.business_id;
  if target.id is null or not private.trip_access(actor.business_id,target.trip_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
  if target.account_purpose<>'CUSTOMER_ADVANCE_CREDIT' or target.signed_amount>=0 or target.party_id is distinct from customer or day<(select effective_date from public.financial_events where id=target.event_id) or public.parse_money(item->>'amount')<=0 then raise exception 'IDENTIFIED_REFUND_CREDIT_REQUIRED' using errcode='22023';end if;
 end loop;
 select sum(public.parse_money(x->>'amount')) into n from jsonb_array_elements(payload->'allocations') x;
 if n<>total then raise exception 'ALLOCATION_MISMATCH' using errcode='22023';end if;
 digest:=encode(sha256(convert_to(payload::text,'UTF8')),'hex');
 select * into cached from public.idempotency_records r where r.business_id=actor.business_id and r.request_id=post_refund_funding.request_id;
 if found then if cached.actor_id<>actor.id or cached.command<>'REFUND_FUNDING' or cached.payload_digest<>digest then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;return cached.result;end if;
 if not exists(select 1 from public.parties p where p.id=payer and p.business_id=actor.business_id and p.archived_at is null) or not exists(select 1 from public.offices o where o.id=office and o.business_id=actor.business_id and o.archived_at is null) then raise exception 'ACTIVE_RECIPIENT_OR_OFFICE_REQUIRED' using errcode='22023';end if;
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  state:=private.claim_state((item->>'target_line_id')::uuid);
  if (state->>'version')::bigint is distinct from (item->>'target_version')::bigint then raise exception 'CLAIM_VERSION_CONFLICT' using errcode='PT409';end if;
  select sum(public.parse_money(x->>'amount')) into n from jsonb_array_elements(payload->'allocations') x where x->>'target_line_id'=item->>'target_line_id';
  if n>(state->>'remaining')::numeric then raise exception 'CLAIM_EXHAUSTED' using errcode='22023';end if;
 end loop;
 insert into public.financial_events(id,business_id,kind,effective_date,actor_id,office_id,payer_id,amount,request_id,reason,created_by)
 values(posting,actor.business_id,'PERSONAL_FUNDING',day,actor.id,office,payer,total,request_id,reason,actor.auth_user_id);
 for item in select * from jsonb_array_elements(payload->'allocations') loop
  select * into target from public.journal_lines where id=(item->>'target_line_id')::uuid;n:=public.parse_money(item->>'amount');
  insert into public.journal_lines(business_id,event_id,party_id,office_id,vehicle_id,trip_id,consignment_id,account_purpose,signed_amount,created_by)
  values(actor.business_id,posting,payer,office,target.vehicle_id,target.trip_id,target.consignment_id,'CUSTODY_RECEIVABLE',n,actor.auth_user_id),
   (actor.business_id,posting,payer,office,target.vehicle_id,target.trip_id,target.consignment_id,'TRIP_FUNDING_PAYABLE',-n,actor.auth_user_id);
 end loop;
 -- Financing does not consume the customer's refund credit or discharge debt.
 result:=jsonb_build_object('record_id',posting,'new_version',1,'kind','REFUND_FUNDING','amount',total::numeric(18,2)::text,'effective_date',day,'refund_status','NOT_POSTED');
 insert into public.audit_events(business_id,actor_id,office_id,record_id,record_type,action,reason,after_data,created_by) values(actor.business_id,actor.id,office,posting,'FINANCIAL_EVENT','REFUND_FUNDING',reason,result,actor.auth_user_id);
 insert into public.idempotency_records(business_id,request_id,actor_id,command,payload_digest,result,created_by,command_payload) values(actor.business_id,request_id,actor.id,'REFUND_FUNDING',digest,result,actor.auth_user_id,payload);
 return result;
end $$;
alter function private.post_refund_funding(uuid,integer,jsonb) owner to carrier_finance;
revoke all on function private.post_refund_funding(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function private.post_refund_funding(uuid,integer,jsonb) to carrier_security;

create function public.list_financial_history(trip_id uuid default null,offset_rows integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles:=private.current_staff(); result jsonb;
begin
 if actor.id is null or offset_rows<0 or (trip_id is not null and not private.trip_access(actor.business_id,trip_id)) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select coalesce(jsonb_agg(q.data),'[]') into result from (
  select jsonb_build_object('id',e.id,'kind',coalesce(i.command,case when exists(select 1 from private.trip_recognition r where e.id=any(r.event_ids)) then 'DISPATCH' when private.is_cancellation_event(e.id) then 'ADJUSTMENT' else e.kind end),
   'effective_date',e.effective_date,'recorded_at',e.recorded_at,'amount',e.amount::text,'reason',e.reason,'actor',s.display_name,
   'payer',payer.display_name,'payee',payee.display_name,'reversal_of_id',e.reversal_of_id,'replacement_of_id',e.replacement_of_id,
   'reversed',exists(select 1 from public.financial_events r where r.reversal_of_id=e.id),
   'can_correct',private.can_correct_event(e.id) and e.kind<>'REVERSAL' and not exists(select 1 from public.financial_events r where r.reversal_of_id=e.id),
   'payload',case when private.can_correct_event(e.id) then coalesce(i.command_payload,
    case when e.kind='ADJUSTMENT' or private.is_cancellation_event(e.id) then
     (select jsonb_build_object('quoted_amount',e.amount::text,'quote_mode','DEDUCTED','commission_method','FIXED','commission_value',(c.commission-coalesce((select sum(j.signed_amount) from public.journal_lines j where j.event_id=e.id and j.account_purpose='BROKER_COMMISSION_PAYABLE'),0))::numeric(18,2)::text,'effective_date',e.effective_date) from public.consignments c where c.id=e.consignment_id)
    when e.consignment_id is not null and exists(select 1 from private.trip_recognition r where e.id=any(r.event_ids)) then
     (select jsonb_build_object('quoted_amount',c.quoted_amount::text,'quote_mode',c.quote_mode,'commission_method',c.commission_method,'commission_value',c.commission_value::text,'effective_date',e.effective_date) from public.consignments c where c.id=e.consignment_id) end) end) data
  from public.financial_events e left join public.idempotency_records i on i.business_id=e.business_id and i.request_id=e.request_id
   join public.staff_profiles s on s.id=e.actor_id left join public.parties payer on payer.id=e.payer_id left join public.parties payee on payee.id=e.payee_id
  where e.business_id=actor.business_id and private.office_access(actor.business_id,e.office_id)
   and (case when list_financial_history.trip_id is null then e.expense_id is not null and e.trip_id is null else e.trip_id=list_financial_history.trip_id or exists(select 1 from public.journal_lines l where l.event_id=e.id and l.trip_id=list_financial_history.trip_id) end)
   and not exists(select 1 from public.journal_lines l where l.event_id=e.id and not(case when l.trip_id is null then private.office_access(actor.business_id,l.office_id) else private.trip_access(actor.business_id,l.trip_id) end))
  order by e.recorded_at desc,e.id limit 50 offset offset_rows
 ) q;
 return result;
end $$;
alter function public.list_financial_history(uuid,integer) owner to carrier_finance;
revoke all on function public.list_financial_history(uuid,integer) from public,anon;
grant execute on function public.list_financial_history(uuid,integer) to authenticated;

create or replace function public.list_expenses(vehicle_id uuid default null,trip_id uuid default null,offset_rows integer default 0) returns jsonb language sql stable set search_path='' as $$
 select coalesce(jsonb_agg(q.data),'[]') from (select jsonb_build_object('id',x.id,'vehicle_id',x.vehicle_id,'trip_id',x.trip_id,'office_id',x.office_id,'category_id',x.category_id,'expense_date',x.expense_date,'amount',x.amount::text,'payer_id',x.payer_id,'cost_bearer_id',x.cost_bearer_id,'funding_source',x.funding_source,'notes',x.notes,'version',x.version,'effective',private.expense_effective(x.id),'replaces_expense_id',x.replaces_expense_id,'correction_reason',x.correction_reason) data from public.expenses x where x.state='CONFIRMED' and (list_expenses.vehicle_id is null or x.vehicle_id=list_expenses.vehicle_id) and (list_expenses.trip_id is null or x.trip_id=list_expenses.trip_id) order by x.expense_date desc,x.id limit 50 offset greatest(0,least(offset_rows,100000))) q
$$;

-- Grant only vetted routines; the correction capability is never client data.
alter function private.link_replacement() owner to carrier_finance;
alter function private.can_correct_event(uuid) owner to carrier_finance;
alter function private.event_dependents(uuid) owner to carrier_finance;
alter function private.reverse_event(uuid,text) owner to carrier_finance;
alter function public.review_financial_correction(uuid) owner to carrier_finance;
alter function public.correct_financial_event(uuid,uuid,integer,jsonb) owner to carrier_finance;
alter function public.review_cancellation(uuid) owner to carrier_finance;
alter function public.cancel_and_adjust(uuid,uuid,integer,jsonb) owner to carrier_finance;
revoke all on function private.link_replacement(),private.can_correct_event(uuid),private.event_dependents(uuid),private.reverse_event(uuid,text),public.review_financial_correction(uuid),public.correct_financial_event(uuid,uuid,integer,jsonb),public.review_cancellation(uuid),public.cancel_and_adjust(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.review_financial_correction(uuid),public.correct_financial_event(uuid,uuid,integer,jsonb),public.review_cancellation(uuid),public.cancel_and_adjust(uuid,uuid,integer,jsonb) to authenticated;
revoke create on schema public,private from carrier_finance;
revoke create on schema private from carrier_earnings;
revoke carrier_finance,carrier_security,carrier_earnings from postgres;
