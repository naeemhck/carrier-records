-- T11: scoped, exact, server-side facts and paginated reports. No cached totals.
grant carrier_security to postgres;
grant create on schema private,public to carrier_security;
create index if not exists report_event_date on public.financial_events(business_id,effective_date,id);
create index if not exists report_expense_date on public.expenses(business_id,expense_date,vehicle_id);
create index if not exists report_line_event on public.journal_lines(business_id,event_id);
create index if not exists report_trip_date on public.trips(business_id,dispatch_date,vehicle_id);

create index if not exists report_event_expense on public.financial_events(expense_id);
create index if not exists report_journal_event on public.journal_lines(event_id);
create index if not exists report_expense_replacement on public.expenses(replaces_expense_id);
create index if not exists report_consignment_trip on public.consignments(trip_id);
create index if not exists report_trip_recent on public.trips(business_id,created_at desc,id);
create index if not exists report_return_link on public.trips(business_id,return_of_trip_id);
create index if not exists report_line_trip on public.journal_lines(business_id,trip_id);
create index if not exists report_expense_trip on public.expenses(business_id,trip_id);
create index if not exists report_allocation_trip on public.allocations(business_id,trip_id);
create index if not exists report_event_consignment on public.financial_events(business_id,consignment_id);
create index if not exists report_line_consignment on public.journal_lines(business_id,consignment_id);

-- Validate explicit filters and current scope once, not once for each fact.
create function private.report_filter(filters jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff(); a uuid[]; o uuid; v uuid; p uuid; t uuid; f date; d date; names jsonb;
begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if jsonb_typeof(filters) is distinct from 'object' or length(filters::text)>3000 or exists(select 1 from jsonb_object_keys(filters) k where k not in('from','to','office_id','vehicle_id','owner_id','trip_id','search')) then raise exception 'INVALID_REPORT_FILTERS' using errcode='22023';end if;
 f:=public.parse_business_date(filters->>'from');d:=public.parse_business_date(filters->>'to');
 if f is null or d is null or d<f or d-f>3660 or length(coalesce(filters->>'search',''))>100 then raise exception 'INVALID_REPORT_PERIOD' using errcode='22023';end if;
 select coalesce(array_agg(x.id),'{}') into a from public.offices x where x.business_id=s.business_id and (s.role='ADMIN' or x.archived_at is null and exists(select 1 from public.staff_offices z where z.staff_id=s.id and z.office_id=x.id));
 o:=(filters->>'office_id')::uuid;v:=(filters->>'vehicle_id')::uuid;p:=(filters->>'owner_id')::uuid;t:=(filters->>'trip_id')::uuid;
 if o is not null and not(o=any(a)) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if v is not null and not exists(select 1 from public.vehicles x where x.id=v and x.business_id=s.business_id) or p is not null and not exists(select 1 from public.parties x where x.id=p and x.business_id=s.business_id) or t is not null and not private.trip_access(s.business_id,t) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select coalesce(jsonb_agg(x.name order by x.name),'[]') into names from public.offices x where x.id=any(a) and (o is null or x.id=o);
 return jsonb_build_object('business',s.business_id,'staff',s.id,'admin',s.role='ADMIN','offices',a,'office_id',o,'vehicle_id',v,'owner_id',p,'trip_id',t,'from',f,'to',d,'search',coalesce(filters->>'search',''),'office_names',names,'complete',s.role='ADMIN' and o is null,'label',case when s.role<>'ADMIN' then 'Assigned-office records — not a complete business balance' when o is not null then 'Selected-office records — not a complete business balance' else 'Complete business records' end);
end $$;

-- Facts also carry recipient context for the later server-owned output projection.
create function private.report_facts(filters jsonb,lifetime boolean default false)
returns table(metric text,value numeric,vehicle_id uuid,owner_id uuid,trip_id uuid,party_id uuid,customer_id uuid,broker_id uuid)
language plpgsql stable security definer set search_path='' as $$
declare q jsonb:=private.report_filter(filters); b uuid:=(q->>'business')::uuid; a uuid[]:=array(select x::uuid from jsonb_array_elements_text(q->'offices') x); o uuid:=(q->>'office_id')::uuid; v uuid:=(q->>'vehicle_id')::uuid; p uuid:=(q->>'owner_id')::uuid; t uuid:=(q->>'trip_id')::uuid; f date:=(q->>'from')::date; d date:=(q->>'to')::date;
begin
 if lifetime and t is null then raise exception 'TRIP_REQUIRED' using errcode='22023';end if;
 return query
 with recursive trips as materialized (
  select z.* from public.trips z join public.vehicles w on w.id=z.vehicle_id
  where z.business_id=b and ((q->>'admin')::boolean or z.origin_office_id=any(a) or z.destination_office_id=any(a))
  and (o is null or o in(z.origin_office_id,z.destination_office_id)) and (v is null or z.vehicle_id=v) and (p is null or z.owner_id=p) and (t is null or z.id=t)
  and (q->>'search'='' or z.trip_number ilike '%'||(q->>'search')||'%' or w.registration ilike '%'||(q->>'search')||'%')
 ), ancestry as (
  select e.id,e.id root_id,e.kind root_kind from public.financial_events e where e.business_id=b and e.reversal_of_id is null and e.replacement_of_id is null
  union all select e.id,z.root_id,z.root_kind from public.financial_events e join ancestry z on coalesce(e.reversal_of_id,e.replacement_of_id)=z.id where e.business_id=b
 ), lines as materialized (
  select l.*,e.effective_date,z.root_kind,h.owner_id historical_owner,c.customer_id customer,c.broker_id broker
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
end $$;

create function private.report_totals(facts jsonb) returns jsonb language sql immutable set search_path='' as $$
 with keys as(select unnest(array['customer_fare','owner_earnings','brokerage','vehicle_cost','owner_cost','receipts','refunds','owner_settled','commission_settled','credit_created','credit_applied','customer_outstanding','customer_credit','custody','owner_due','owner_recovery','brokerage_due','brokerage_recovery','funding_due','reimbursement_due','cost_recovery','dispatched','arrived']) key), sums as(select k.key,coalesce((facts->>k.key)::numeric,0) amount from keys k)
 select jsonb_object_agg(key,amount::numeric(38,2)::text)||jsonb_build_object('operating_profit',(coalesce((facts->>'customer_fare')::numeric,0)-coalesce((facts->>'brokerage')::numeric,0)-coalesce((facts->>'vehicle_cost')::numeric,0))::numeric(38,2)::text,'owner_profit',(coalesce((facts->>'owner_earnings')::numeric,0)-coalesce((facts->>'owner_cost')::numeric,0))::numeric(38,2)::text) from sums
$$;

create function public.get_scoped_report(report_kind text,filters jsonb,page_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare q jsonb:=private.report_filter(filters); result jsonb;
begin
 if report_kind is null or report_kind not in('MONTHLY_VEHICLE','MONTHLY_OWNER','CLAIMS','TRIP_PROFIT') or page_offset is null or page_offset<0 or page_offset>1000000 then raise exception 'INVALID_REPORT' using errcode='22023';end if;
 with facts as materialized(select * from private.report_facts(filters,report_kind='TRIP_PROFIT')),
 totals as(select jsonb_object_agg(metric,amount) raw from(select metric,sum(value) amount from facts group by metric) z),
 groups as(select case report_kind when 'MONTHLY_OWNER' then owner_id when 'CLAIMS' then party_id when 'TRIP_PROFIT' then trip_id else vehicle_id end id,metric,sum(value) amount from facts group by 1,2),
 rows as(select g.id,private.report_totals(jsonb_object_agg(g.metric,g.amount)) values from groups g group by g.id),
 named as(select r.id,coalesce(case report_kind when 'MONTHLY_VEHICLE' then v.registration when 'TRIP_PROFIT' then t.trip_number else p.display_name end,'Unattributed') name,r.values from rows r left join public.vehicles v on v.id=r.id left join public.parties p on p.id=r.id left join public.trips t on t.id=r.id),
 page as(select * from named order by name,id nulls last limit 50 offset page_offset)
 select jsonb_build_object('totals',private.report_totals(coalesce((select raw from totals),'{}')),'rows',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'values',values) order by name,id nulls last) from page),'[]'),'row_count',(select count(*) from named),'has_more',(select count(*) from named)>page_offset+50) into result;
 return result||jsonb_build_object('kind',report_kind,'period',jsonb_build_object('from',q->>'from','to',q->>'to'),'lifetime',report_kind='TRIP_PROFIT','scope',q->>'label','complete',q->'complete','offices',q->'office_names','generated_at',statement_timestamp(),'date_bases',jsonb_build_object('earnings','Dispatch / explicit adjustment date','expenses','Expense date','receipts','Payment date','claims',case when report_kind='TRIP_PROFIT' then 'Current lifetime balance' else 'As of period end' end),'page_offset',page_offset,'page_size',50);
end $$;

-- Annual benchmark: evaluate live office membership once, then paginate.
create or replace function public.list_trips(search_text text default '',page_offset integer default 0,
 office_id uuid default null,vehicle_id uuid default null,trip_state text default null,
 date_from text default null,date_to text default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor public.staff_profiles; start_date date; end_date date; result jsonb; assigned uuid[];
begin
 actor:=private.current_staff();
 if actor.id is null then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if page_offset is null or page_offset<0 or search_text is null or length(search_text)>100
  or (trip_state is not null and trip_state not in ('DRAFT','DISPATCHED','ARRIVED','CANCELLED')) then raise exception 'INVALID_QUERY' using errcode='22023'; end if;
 if office_id is not null and not private.office_access(actor.business_id,office_id) then raise exception 'FORBIDDEN' using errcode='42501'; end if;
 if date_from is not null then start_date:=public.parse_business_date(date_from); end if;
 if date_to is not null then end_date:=public.parse_business_date(date_to); end if;
 if start_date>end_date then raise exception 'INVALID_DATE_RANGE' using errcode='22023'; end if;
 select coalesce(array_agg(o.id),'{}') into assigned from public.offices o join public.staff_offices a on a.office_id=o.id where a.staff_id=actor.id and o.archived_at is null;
 select coalesce(jsonb_agg(x.row_data order by x.created_at desc,x.id),'[]') into result from (
  select t.id,t.created_at,jsonb_build_object('id',t.id,'trip_number',t.trip_number,'state',t.state,'load_kind',t.load_kind,
   'registration',v.registration,'owner_name',t.owner_snapshot->>'display_name',
   'origin_name',o.name,'destination_name',d.name,'planned_dispatch_date',t.planned_dispatch_date,
   'dispatch_date',t.dispatch_date,'arrival_date',t.arrival_date,'return_of_trip_id',t.return_of_trip_id,
   'car_count',(select coalesce(sum(car_count),0) from public.consignments where trip_id=t.id and state<>'CANCELLED')) row_data
  from public.trips t join public.vehicles v on v.id=t.vehicle_id join public.offices o on o.id=t.origin_office_id join public.offices d on d.id=t.destination_office_id
  where t.business_id=actor.business_id and (actor.role='ADMIN' or t.origin_office_id=any(assigned) or t.destination_office_id=any(assigned))
   and (office_id is null or office_id in(t.origin_office_id,t.destination_office_id))
   and (list_trips.vehicle_id is null or t.vehicle_id=list_trips.vehicle_id) and (trip_state is null or t.state=trip_state)
   and (start_date is null or coalesce(t.dispatch_date,t.planned_dispatch_date)>=start_date)
   and (end_date is null or coalesce(t.dispatch_date,t.planned_dispatch_date)<=end_date)
   and (search_text='' or concat_ws(' ',t.trip_number,v.registration,t.owner_snapshot->>'display_name') ilike '%'||search_text||'%'
    or exists(select 1 from public.consignments c join public.parties p on p.id=c.customer_id left join public.parties b on b.id=c.broker_id
     where c.trip_id=t.id and concat_ws(' ',p.display_name,p.code,b.display_name,b.code) ilike '%'||search_text||'%'))
   order by t.created_at desc,t.id limit 50 offset page_offset) x;
 return jsonb_build_object('scope',case when actor.role='ADMIN' then 'ALL_OFFICES' else 'ASSIGNED_OFFICES' end,'rows',result);
end $$;

alter function private.report_filter(jsonb) owner to carrier_security;
alter function private.report_facts(jsonb,boolean) owner to carrier_security;
alter function private.report_totals(jsonb) owner to carrier_security;
alter function public.get_scoped_report(text,jsonb,integer) owner to carrier_security;
revoke all on function private.report_filter(jsonb),private.report_facts(jsonb,boolean),private.report_totals(jsonb),public.get_scoped_report(text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.get_scoped_report(text,jsonb,integer) to authenticated;
revoke create on schema public,private from carrier_security;
revoke carrier_security from postgres;
