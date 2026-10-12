-- Keep function-body validation enabled; retain existing owner and ACLs.
begin;
grant carrier_security to postgres;

CREATE OR REPLACE FUNCTION private.report_facts (
  filters  jsonb,
  lifetime boolean DEFAULT false
)
  RETURNS TABLE (
    metric      text,
    value       numeric,
    vehicle_id  uuid,
    owner_id    uuid,
    trip_id     uuid,
    party_id    uuid,
    customer_id uuid,
    broker_id   uuid
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
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
  select e.id,e.id root_id,e.kind root_kind from public.financial_events e where e.business_id=b and e.reversal_of_id is null and e.replacement_of_id is null
  union all select e.id,z.root_id,z.root_kind from public.financial_events e join ancestry z on coalesce(e.reversal_of_id,e.replacement_of_id)=z.id where e.business_id=b
 ), lines as materialized (
  select l.vehicle_id,l.trip_id,l.party_id,l.expense_id,l.account_purpose,l.signed_amount,e.effective_date,z.root_kind,h.owner_id historical_owner,coalesce(c.customer_id,case when z.root_kind in('CUSTOMER_RECEIPT','ADVANCE') then e.payer_id when z.root_kind='REFUND' then e.payee_id end) customer,c.broker_id broker
  from public.journal_lines l join public.financial_events e on e.id=l.event_id join ancestry z on z.id=e.id left join trips h on h.id=l.trip_id left join public.consignments c on c.id=l.consignment_id
  left join public.expenses x on x.id=l.expense_id
  where l.business_id=b and (l.trip_id is not null and h.id is not null or l.trip_id is null and ((q->>'admin')::boolean or l.office_id=any(a)) and (o is null or o=l.office_id) and (v is null or l.vehicle_id=v) and (p is null or x.owner_id=p) and t is null and q->>'search'='')
 ), period_lines as (select * from lines where lifetime or effective_date between f and d),
 costs as (
  select x.* from public.expenses x left join trips h on h.id=x.trip_id
  where x.business_id=b and x.state='CONFIRMED' and (lifetime and x.trip_id=t or not lifetime and x.expense_date between f and d)
  and (x.trip_id is not null and h.id is not null or x.trip_id is null and t is null and ((q->>'admin')::boolean or x.office_id=any(a)) and (o is null or x.office_id=o) and (v is null or x.vehicle_id=v) and (p is null or x.owner_id=p) and q->>'search'='')
  and not exists(select 1 from public.expenses r where r.replaces_expense_id=x.id)
  and not exists(select 1 from public.financial_events e join public.financial_events r on r.reversal_of_id=e.id where e.expense_id=x.id and e.kind in('EXPENSE','REPLACEMENT'))
 ), balances as (
  select l.vehicle_id,coalesce(l.historical_owner,x.owner_id) owner,l.trip_id,l.party_id,l.customer,l.broker,l.account_purpose,sum(l.signed_amount) amount
  from lines l left join public.expenses x on x.id=l.expense_id where lifetime or l.effective_date<=d
  group by l.vehicle_id,coalesce(l.historical_owner,x.owner_id),l.trip_id,l.party_id,l.customer,l.broker,l.account_purpose
 )
 select m.key,m.amount,l.vehicle_id,l.historical_owner,l.trip_id,l.party_id,l.customer,l.broker from period_lines l
 cross join lateral(values
  ('customer_fare',case when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose in('CUSTOMER_RECEIVABLE','CUSTOMER_ADVANCE_CREDIT') then l.signed_amount else 0 end),
  ('owner_earnings',case when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose='OWNER_PAYABLE' then -l.signed_amount else 0 end),
  ('brokerage',case when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose='BROKER_COMMISSION_PAYABLE' then -l.signed_amount else 0 end),
  ('receipts',case when l.root_kind in('CUSTOMER_RECEIPT','ADVANCE') and l.account_purpose='CUSTODY_RECEIVABLE' then l.signed_amount else 0 end),
  ('refunds',case when l.root_kind='REFUND' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then l.signed_amount else 0 end),
  ('owner_settled',case when l.root_kind in('OWNER_SETTLEMENT','PERSONAL_FUNDING') and l.account_purpose='OWNER_PAYABLE' then l.signed_amount else 0 end),
  ('commission_settled',case when l.root_kind='COMMISSION_SETTLEMENT' and l.account_purpose='BROKER_COMMISSION_PAYABLE' then l.signed_amount else 0 end),
  ('credit_created',case when l.root_kind in('ADVANCE','CUSTOMER_RECEIPT','ADJUSTMENT') and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then -l.signed_amount else 0 end),
  ('credit_applied',case when l.root_kind='ADVANCE_APPLICATION' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then l.signed_amount else 0 end)
 ) m(key,amount) where m.amount<>0
 union all select m.key,m.amount,x.vehicle_id,x.owner_id,x.trip_id,x.cost_bearer_id,null::uuid,null::uuid from costs x cross join lateral(values('vehicle_cost',x.amount),('owner_cost',case when x.cost_bearer_id=x.owner_id then x.amount else 0 end)) m(key,amount) where m.amount<>0
 union all select m.key,m.amount,z.vehicle_id,z.owner,z.trip_id,z.party_id,z.customer,z.broker from balances z
 cross join lateral(values
  ('customer_outstanding',case when z.account_purpose='CUSTOMER_RECEIVABLE' then greatest(z.amount,0) else 0 end),
  ('customer_credit',case when z.account_purpose='CUSTOMER_ADVANCE_CREDIT' then -z.amount else 0 end),
  ('custody',case when z.account_purpose='CUSTODY_RECEIVABLE' then z.amount else 0 end),
  ('owner_due',case when z.account_purpose='OWNER_PAYABLE' then greatest(-z.amount,0) else 0 end),
  ('owner_recovery',case when z.account_purpose='OWNER_PAYABLE' then greatest(z.amount,0) else 0 end),
  ('brokerage_due',case when z.account_purpose='BROKER_COMMISSION_PAYABLE' then greatest(-z.amount,0) else 0 end),
  ('brokerage_recovery',case when z.account_purpose='BROKER_COMMISSION_PAYABLE' then greatest(z.amount,0) else 0 end),
  ('funding_due',case when z.account_purpose='TRIP_FUNDING_PAYABLE' then -z.amount else 0 end),
  ('reimbursement_due',case when z.account_purpose='EXPENSE_REIMBURSEMENT_PAYABLE' then -z.amount else 0 end),
  ('cost_recovery',case when z.account_purpose='PARTY_COST_RECOVERY' then z.amount else 0 end)
 )m(key,amount) where m.amount<>0
 union all select m.key,1::numeric,z.vehicle_id,z.owner_id,z.id,null::uuid,null::uuid,null::uuid from trips z cross join lateral(values('dispatched',z.dispatch_date),('arrived',z.arrival_date)) m(key,day) where m.day is not null and (lifetime or m.day between f and d);
end $function$;

CREATE OR REPLACE FUNCTION public.get_scoped_report (
  report_kind text,
  filters     jsonb,
  page_offset integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
declare q jsonb:=private.report_filter(filters); result jsonb;
begin
 if report_kind is null or report_kind not in('MONTHLY_VEHICLE','MONTHLY_OWNER','CLAIMS','TRIP_PROFIT') or page_offset is null or page_offset<0 or page_offset>1000000 then raise exception 'INVALID_REPORT' using errcode='22023';end if;
 with groups as materialized(select case report_kind when 'MONTHLY_OWNER' then owner_id when 'CLAIMS' then party_id when 'TRIP_PROFIT' then trip_id else vehicle_id end id,metric,sum(value) amount from private.report_facts(filters,report_kind='TRIP_PROFIT') group by 1,2),
 totals as(select jsonb_object_agg(metric,amount) raw from(select metric,sum(amount) amount from groups group by metric) z),
 rows as(select g.id,private.report_totals(jsonb_object_agg(g.metric,g.amount)) values from groups g group by g.id),
 named as(select r.id,coalesce(case report_kind when 'MONTHLY_VEHICLE' then v.registration when 'TRIP_PROFIT' then t.trip_number else p.display_name end,'Unattributed') name,r.values from rows r left join public.vehicles v on v.id=r.id left join public.parties p on p.id=r.id left join public.trips t on t.id=r.id),
 page as(select * from named order by name,id nulls last limit 50 offset page_offset)
 select jsonb_build_object('totals',private.report_totals(coalesce((select raw from totals),'{}')),'rows',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'values',values) order by name,id nulls last) from page),'[]'),'row_count',(select count(*) from named),'has_more',(select count(*) from named)>page_offset+50) into result;
 return result||jsonb_build_object('kind',report_kind,'period',jsonb_build_object('from',q->>'from','to',q->>'to'),'lifetime',report_kind='TRIP_PROFIT','scope',q->>'label','complete',q->'complete','offices',q->'office_names','generated_at',statement_timestamp(),'date_bases',jsonb_build_object('earnings','Dispatch / explicit adjustment date','expenses','Expense date','receipts','Payment date','claims',case when report_kind='TRIP_PROFIT' then 'Current lifetime balance' else 'As of period end' end),'page_offset',page_offset,'page_size',50);
end $function$;


revoke carrier_security from postgres;
commit;
