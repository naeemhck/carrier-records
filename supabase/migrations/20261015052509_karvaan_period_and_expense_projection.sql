-- Profiled period projection and business/date-bounded expense lookups.
-- Exact facts, source-level office scope and immutable history are unchanged.
begin;
grant carrier_security to postgres;
CREATE OR REPLACE FUNCTION private.report_facts(filters jsonb, lifetime boolean DEFAULT false)
 RETURNS TABLE(metric text, value numeric, vehicle_id uuid, owner_id uuid, trip_id uuid, party_id uuid, customer_id uuid, broker_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET work_mem TO '16MB'
AS $function$
declare q jsonb:=private.report_filter(filters); b uuid:=(q->>'business')::uuid; a uuid[]:=array(select x::uuid from jsonb_array_elements_text(q->'offices') x); o uuid:=(q->>'office_id')::uuid; v uuid:=(q->>'vehicle_id')::uuid; p uuid:=(q->>'owner_id')::uuid; t uuid:=(q->>'trip_id')::uuid; f date:=(q->>'from')::date; d date:=(q->>'to')::date;
begin
 if lifetime and t is null then raise exception 'TRIP_REQUIRED' using errcode='22023';end if;
 return query
 with recursive trips as materialized (
  select z.id,z.vehicle_id,z.owner_id,z.dispatch_date,z.arrival_date from public.trips z join public.vehicles w on w.id=z.vehicle_id
  where z.business_id=b and ((q->>'admin')::boolean or z.origin_office_id=any(a) or z.destination_office_id=any(a))
  and (o is null or o in(z.origin_office_id,z.destination_office_id)) and (v is null or z.vehicle_id=v) and (p is null or z.owner_id=p) and (t is null or z.id=t)
  and (q->>'search'='' or z.trip_number ilike '%'||(q->>'search')||'%' or w.registration ilike '%'||(q->>'search')||'%')
 ), ancestry as (
  -- Walk only linked events toward their original root; ordinary events need no walk.
  select e.id leaf_id,p.id,p.kind root_kind,p.reversal_of_id,p.replacement_of_id
  from public.financial_events e join public.financial_events p on p.id=coalesce(e.reversal_of_id,e.replacement_of_id)
  where e.business_id=b and p.business_id=b and (e.reversal_of_id is not null or e.replacement_of_id is not null)
  union all select z.leaf_id,p.id,p.kind,p.reversal_of_id,p.replacement_of_id
  from ancestry z join public.financial_events p on p.id=coalesce(z.reversal_of_id,z.replacement_of_id) where p.business_id=b
 ), roots as (
  select leaf_id id,root_kind from ancestry where reversal_of_id is null and replacement_of_id is null
 ), raw_lines as materialized (
  -- Join business/date-bounded immutable journal metadata once. The measured
  -- search estimate (38 vs 12,000 trips) otherwise repeats PK fetches 36,000 times.
  -- This private intermediate is never returned; office predicates apply below.
  select l.vehicle_id,l.trip_id,l.party_id,l.expense_id,l.account_purpose,l.signed_amount,l.office_id,e.effective_date,coalesce(z.root_kind,e.kind) root_kind,
   coalesce(c.customer_id,case when coalesce(z.root_kind,e.kind) in('CUSTOMER_RECEIPT','ADVANCE') then e.payer_id when coalesce(z.root_kind,e.kind)='REFUND' then e.payee_id end) customer,c.broker_id broker,x.owner_id expense_owner
  from public.journal_lines l join public.financial_events e on e.id=l.event_id
  left join roots z on z.id=e.id left join public.consignments c on c.id=l.consignment_id
  left join public.expenses x on x.id=l.expense_id
  where l.business_id=b and (lifetime or e.effective_date<=d)
 ), lines as materialized (
  select l.vehicle_id,l.trip_id,l.party_id,l.expense_id,l.account_purpose,l.signed_amount,l.effective_date,l.root_kind,h.owner_id historical_owner,l.customer,l.broker
  from raw_lines l left join trips h on h.id=l.trip_id
  where (l.trip_id is not null and h.id is not null or l.trip_id is null and ((q->>'admin')::boolean or l.office_id=any(a)) and (o is null or o=l.office_id) and (v is null or l.vehicle_id=v) and (p is null or l.expense_owner=p) and t is null and q->>'search'='')
 ), period_lines as (select * from lines where lifetime or effective_date between f and d),
 cost_candidates as materialized (
  -- Bound the month before trip-index/anti-reversal probes (12,000 -> 1,000).
  select x.* from public.expenses x where x.business_id=b and x.state='CONFIRMED'
   and (lifetime and x.trip_id=t or not lifetime and x.expense_date between f and d)
 ), costs as (
  select x.* from cost_candidates x left join trips h on h.id=x.trip_id
  where true
  and (x.trip_id is not null and h.id is not null or x.trip_id is null and t is null and ((q->>'admin')::boolean or x.office_id=any(a)) and (o is null or x.office_id=o) and (v is null or x.vehicle_id=v) and (p is null or x.owner_id=p) and q->>'search'='')
  and not exists(select 1 from public.expenses r where r.replaces_expense_id=x.id)
  and not exists(select 1 from public.financial_events e join public.financial_events r on r.reversal_of_id=e.id where e.business_id=b and r.business_id=b and e.expense_id=x.id and e.kind in('EXPENSE','REPLACEMENT'))
 ), balances as (
  select l.vehicle_id,coalesce(l.historical_owner,x.owner_id) owner,l.trip_id,l.party_id,l.customer,l.broker,l.account_purpose,sum(l.signed_amount) amount
  from lines l left join public.expenses x on x.id=l.expense_id where lifetime or l.effective_date<=d
  group by l.vehicle_id,coalesce(l.historical_owner,x.owner_id),l.trip_id,l.party_id,l.customer,l.broker,l.account_purpose
 )
 select m.key,case when m.key in('owner_earnings','brokerage','credit_created') then -l.signed_amount else l.signed_amount end,l.vehicle_id,l.historical_owner,l.trip_id,l.party_id,l.customer,l.broker from period_lines l
 cross join lateral(
  select case
   when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose in('CUSTOMER_RECEIVABLE','CUSTOMER_ADVANCE_CREDIT') then 'customer_fare'
   when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose='OWNER_PAYABLE' then 'owner_earnings'
   when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose='BROKER_COMMISSION_PAYABLE' then 'brokerage'
   when l.root_kind in('CUSTOMER_RECEIPT','ADVANCE') and l.account_purpose='CUSTODY_RECEIVABLE' then 'receipts'
   when l.root_kind='REFUND' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then 'refunds'
   when l.root_kind in('OWNER_SETTLEMENT','PERSONAL_FUNDING') and l.account_purpose='OWNER_PAYABLE' then 'owner_settled'
   when l.root_kind='COMMISSION_SETTLEMENT' and l.account_purpose='BROKER_COMMISSION_PAYABLE' then 'commission_settled'
   when l.root_kind in('ADVANCE','CUSTOMER_RECEIPT','ADJUSTMENT') and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then 'credit_created'
   when l.root_kind='ADVANCE_APPLICATION' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then 'credit_applied' end key
  union all select 'credit_created' where l.root_kind='ADJUSTMENT' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT'
 ) m where m.key is not null and l.signed_amount<>0
 union all select m.key,m.amount,x.vehicle_id,x.owner_id,x.trip_id,x.cost_bearer_id,null::uuid,null::uuid from costs x cross join lateral(values('vehicle_cost',x.amount),('owner_cost',case when x.cost_bearer_id=x.owner_id then x.amount else 0 end)) m(key,amount) where m.amount<>0
 union all select m.key,m.amount,z.vehicle_id,z.owner,z.trip_id,z.party_id,z.customer,z.broker from balances z
 cross join lateral(select
  case z.account_purpose
   when 'CUSTOMER_RECEIVABLE' then 'customer_outstanding'
   when 'CUSTOMER_ADVANCE_CREDIT' then 'customer_credit'
   when 'CUSTODY_RECEIVABLE' then 'custody'
   when 'OWNER_PAYABLE' then case when z.amount<0 then 'owner_due' else 'owner_recovery' end
   when 'BROKER_COMMISSION_PAYABLE' then case when z.amount<0 then 'brokerage_due' else 'brokerage_recovery' end
   when 'TRIP_FUNDING_PAYABLE' then 'funding_due'
   when 'EXPENSE_REIMBURSEMENT_PAYABLE' then 'reimbursement_due'
   when 'PARTY_COST_RECOVERY' then 'cost_recovery' end key,
  case z.account_purpose
   when 'CUSTOMER_RECEIVABLE' then greatest(z.amount,0)
   when 'CUSTOMER_ADVANCE_CREDIT' then -z.amount
   when 'OWNER_PAYABLE' then abs(z.amount)
   when 'BROKER_COMMISSION_PAYABLE' then abs(z.amount)
   when 'TRIP_FUNDING_PAYABLE' then -z.amount
   when 'EXPENSE_REIMBURSEMENT_PAYABLE' then -z.amount
   else z.amount end amount
 )m where m.key is not null and m.amount<>0
 union all select m.key,1::numeric,z.vehicle_id,z.owner_id,z.id,null::uuid,null::uuid,null::uuid from trips z cross join lateral(values('dispatched',z.dispatch_date),('arrived',z.arrival_date)) m(key,day) where m.day is not null and (lifetime or m.day between f and d);
end $function$;
revoke carrier_security from postgres;
commit;
