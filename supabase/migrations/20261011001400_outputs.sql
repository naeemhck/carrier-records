-- T12 presentation only. Issuance and files remain T13/T14.
grant carrier_security to postgres;
grant create on schema private,public to carrier_security;
grant insert,update,delete on public.output_presets to carrier_security;
create table private.output_requests(business_id uuid not null references public.businesses(id),request_id uuid not null,actor_id uuid not null references public.staff_profiles(id),command jsonb not null,result jsonb not null,primary key(business_id,request_id));
grant select,insert on private.output_requests to carrier_security;

create function private.output_fields(report text,recipient text)
returns table(field_key text,label text,field_group text,value_type text,required boolean,default_position integer,header boolean)
language plpgsql immutable set search_path='' as $$
begin
 if report is null or recipient is null or report not in('MONTHLY_VEHICLE','OWNER_STATEMENT','BROKER_MONTHLY','CUSTOMER_STATEMENT','TRIP_PROFIT','CUSTOMER_INVOICE','PAYMENT_RECEIPT') or recipient not in('INTERNAL','CUSTOMER','OWNER','BROKER')
 or report='OWNER_STATEMENT' and recipient not in('INTERNAL','OWNER') or report='BROKER_MONTHLY' and recipient not in('INTERNAL','BROKER') or report='CUSTOMER_STATEMENT' and recipient not in('INTERNAL','CUSTOMER') or report='CUSTOMER_INVOICE' and recipient<>'CUSTOMER' or report='MONTHLY_VEHICLE' and recipient not in('INTERNAL','OWNER') then raise exception 'INVALID_OUTPUT_TYPE' using errcode='22023';end if;
 return query select z.k,z.l,z.g,z.t,z.r,case when z.pos>=50 and not(z.k=any(case recipient when 'OWNER' then array['owner_earnings','owner_cost','owner_profit','owner_due'] when 'CUSTOMER' then array['customer_fare','receipts','customer_outstanding','customer_credit'] when 'BROKER' then array['brokerage','commission_settled','brokerage_due','custody'] else array['customer_fare','owner_earnings','brokerage','vehicle_cost','operating_profit','customer_outstanding','owner_due','custody'] end)) then null else z.pos end,z.h from(values
 ('period','Report period','Identity','TEXT',true,1,true,'ALL','ALL'),('scope','Office scope','Identity','TEXT',true,2,true,'ALL','ALL'),('generated_at','Generated at','Identity','TEXT',true,3,true,'ALL','ALL'),('recipient_name','Recipient','Identity','TEXT',true,4,true,'ALL','ALL'),
 ('company_name','Company','Identity','TEXT',true,5,true,'ALL','DOCUMENT'),('issuer_name','Issuing user','Identity','TEXT',true,6,true,'ALL','DOCUMENT'),('document_number','Document number (not issued in preview)','Identity','TEXT',true,7,true,'ALL','DOCUMENT'),('document_date','Document date','Identity','DATE',true,8,true,'ALL','DOCUMENT'),('invoice_total','Authoritative invoice total','Charges','MONEY',true,9,true,'INTERNAL,CUSTOMER','CUSTOMER_INVOICE'),('receipt_amount','Actual receipt amount','Payments','MONEY',true,9,true,'ALL','PAYMENT_RECEIPT'),
 ('record_name','Record','Identity','TEXT',true,20,false,'ALL','ALL'),('vehicle_registration','Vehicle','Journey','TEXT',false,30,false,'ALL','ALL'),('trip_number','Trip number','Journey','TEXT',false,31,false,'ALL','DETAIL'),('dispatch_date','Dispatch date','Journey','DATE',false,32,false,'ALL','DETAIL'),('arrival_date','Arrival date','Journey','DATE',false,null,false,'ALL','DETAIL'),('origin','Origin office','Journey','TEXT',false,null,false,'ALL','DETAIL'),('destination','Destination office','Journey','TEXT',false,null,false,'ALL','DETAIL'),('car_count','Cars','Cars','INTEGER',false,33,false,'ALL','DETAIL'),('car_identifiers','Car identifiers','Cars','TEXT',false,null,false,'ALL','DETAIL'),('pickup_drop','Pickup / drop stops','Journey','TEXT',false,null,false,'ALL','DETAIL'),('notes','Notes','Notes','TEXT',false,null,false,'INTERNAL,CUSTOMER','DETAIL'),
 ('customer_fare','Customer charge','Charges','MONEY',false,50,false,'INTERNAL,CUSTOMER,BROKER','REPORT'),('owner_earnings','Owner fare share','Charges','MONEY',false,51,false,'INTERNAL,OWNER','REPORT'),('brokerage','Brokerage earned','Charges','MONEY',false,52,false,'INTERNAL,BROKER','REPORT'),('vehicle_cost','All vehicle costs','Expenses','MONEY',false,53,false,'INTERNAL','REPORT'),('owner_cost','Owner-borne costs','Expenses','MONEY',false,54,false,'INTERNAL,OWNER','REPORT'),('operating_profit','Vehicle operating profit','Balances','MONEY',false,55,false,'INTERNAL','REPORT'),('owner_profit','Owner profit','Balances','MONEY',false,56,false,'INTERNAL,OWNER','REPORT'),
 ('receipts','Customer receipts','Payments','MONEY',false,57,false,'INTERNAL,CUSTOMER,BROKER','REPORT'),('refunds','Customer refunds','Payments','MONEY',false,null,false,'INTERNAL,CUSTOMER','REPORT'),('owner_settled','Owner cash settlement','Payments','MONEY',false,null,false,'INTERNAL,OWNER,BROKER','REPORT'),('commission_settled','Commission retained / paid','Payments','MONEY',false,58,false,'INTERNAL,BROKER','REPORT'),('credit_created','Customer credits created','Payments','MONEY',false,null,false,'INTERNAL,CUSTOMER','REPORT'),('credit_applied','Customer credits applied','Payments','MONEY',false,null,false,'INTERNAL,CUSTOMER','REPORT'),
 ('customer_outstanding','Customer outstanding','Balances','MONEY',false,60,false,'INTERNAL,CUSTOMER,BROKER','REPORT'),('customer_credit','Customer credit','Balances','MONEY',false,61,false,'INTERNAL,CUSTOMER','REPORT'),('custody','Intermediary-held money','Balances','MONEY',false,62,false,'INTERNAL,BROKER','REPORT'),('owner_due','Owner settlement due','Balances','MONEY',false,63,false,'INTERNAL,OWNER','REPORT'),('owner_recovery','Owner recovery','Balances','MONEY',false,null,false,'INTERNAL,OWNER','REPORT'),('brokerage_due','Brokerage due','Balances','MONEY',false,64,false,'INTERNAL,BROKER','REPORT'),('brokerage_recovery','Broker recovery','Balances','MONEY',false,null,false,'INTERNAL,BROKER','REPORT'),('funding_due','Personal funding due','Balances','MONEY',false,null,false,'INTERNAL,OWNER,BROKER','REPORT'),('reimbursement_due','Expense reimbursement due','Balances','MONEY',false,null,false,'INTERNAL,OWNER,BROKER','REPORT'),('cost_recovery','Cost recovery','Balances','MONEY',false,null,false,'INTERNAL','REPORT'),
 ('dispatched','Dispatched trips','Journey','INTEGER',false,null,false,'INTERNAL','REPORT'),('arrived','Arrived trips','Journey','INTEGER',false,null,false,'INTERNAL','REPORT'),('payer_name','Actual payer','Payments','TEXT',true,34,false,'ALL','PAYMENT_RECEIPT'),('payee_name','Actual recipient','Payments','TEXT',true,35,false,'ALL','PAYMENT_RECEIPT'),('payment_date','Payment date','Payments','DATE',true,36,false,'ALL','PAYMENT_RECEIPT'),('allocation_amount','Allocation amount','Payments','MONEY',false,37,false,'ALL','PAYMENT_RECEIPT')
 )z(k,l,g,t,r,pos,h,rec,kinds)
 where (z.rec='ALL' or recipient=any(string_to_array(z.rec,','))) and (z.kinds='ALL' or z.kinds=report or z.kinds='DOCUMENT' and report in('CUSTOMER_INVOICE','PAYMENT_RECEIPT') or z.kinds='REPORT' and report<>'PAYMENT_RECEIPT' or z.kinds='DETAIL' and report<>'MONTHLY_VEHICLE') order by z.pos nulls last,z.k;
end $$;

create function private.output_recipient(recipient text,party uuid) returns text language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();name text;begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if recipient='INTERNAL' and party is null then return 'Internal';end if;
 if recipient='INTERNAL' or party is null then raise exception 'RECIPIENT_REQUIRED' using errcode='22023';end if;
 select p.display_name into name from public.parties p where p.id=party and p.business_id=s.business_id and exists(select 1 from public.party_roles r where r.business_id=s.business_id and r.party_id=p.id and r.role=recipient);
 if name is null then raise exception 'FORBIDDEN' using errcode='42501';end if;return name;
end $$;

create function private.output_receipt(event uuid,recipient text,party uuid,filters jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();q jsonb:=private.report_filter(filters);e public.financial_events;root public.financial_events;amount numeric;begin
 perform private.output_recipient(recipient,party);
 select * into e from public.financial_events x where x.id=event and x.business_id=s.business_id;
 if e.id is null or not private.office_access(s.business_id,e.office_id) and not exists(select 1 from public.journal_lines l where l.event_id=e.id and private.trip_access(s.business_id,l.trip_id)) or exists(select 1 from public.journal_lines l where l.event_id=e.id and not(case when l.trip_id is null then private.office_access(s.business_id,l.office_id) else private.trip_access(s.business_id,l.trip_id) end)) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if e.kind='REVERSAL' or exists(select 1 from public.financial_events r where r.reversal_of_id=e.id) then raise exception 'REVERSED_RECEIPT' using errcode='22023';end if;
 root:=e;while root.replacement_of_id is not null loop select * into root from public.financial_events x where x.id=root.replacement_of_id;end loop;
 if root.kind not in('CUSTOMER_RECEIPT','ADVANCE','OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','PERSONAL_FUNDING','FUNDING_RECOVERY','REIMBURSEMENT','REFUND','CUSTODY_TRANSFER') or e.amount<=0 or e.payer_id is null or e.payee_id is null then raise exception 'NOT_A_PAYMENT_RECEIPT' using errcode='22023';end if;
 if recipient='CUSTOMER' and not(root.kind in('CUSTOMER_RECEIPT','ADVANCE') and e.payer_id=party or root.kind='REFUND' and e.payee_id=party) or recipient='BROKER' and e.payee_id is distinct from party then raise exception 'FORBIDDEN' using errcode='42501';end if;
 amount:=e.amount;
 if recipient='OWNER' then
  select coalesce(sum(l.signed_amount),0) into amount from public.journal_lines l where l.event_id=e.id and l.party_id=party and l.signed_amount>0 and l.account_purpose in('OWNER_PAYABLE','EXPENSE_REIMBURSEMENT_PAYABLE','TRIP_FUNDING_PAYABLE');
  if e.payee_id is distinct from party or amount<=0 or root.kind not in('OWNER_SETTLEMENT','PERSONAL_FUNDING','FUNDING_RECOVERY','REIMBURSEMENT') or amount<>e.amount then raise exception 'FORBIDDEN' using errcode='42501';end if;
 end if;
 if e.effective_date not between (q->>'from')::date and (q->>'to')::date or exists(select 1 from public.journal_lines l left join public.trips t on t.id=l.trip_id left join public.expenses x on x.id=l.expense_id where l.event_id=e.id and ((q->>'trip_id') is not null and l.trip_id is distinct from (q->>'trip_id')::uuid or q->>'vehicle_id' is not null and l.vehicle_id is distinct from (q->>'vehicle_id')::uuid or q->>'owner_id' is not null and coalesce(t.owner_id,x.owner_id) is distinct from (q->>'owner_id')::uuid or q->>'office_id' is not null and not(coalesce((q->>'office_id')::uuid in(t.origin_office_id,t.destination_office_id),l.office_id=(q->>'office_id')::uuid)))) then raise exception 'RECEIPT_FILTER_MISMATCH' using errcode='22023';end if;
 return jsonb_build_object('amount',amount::numeric(18,2)::text,'payment_date',e.effective_date,'payer_name',(select display_name from public.parties where id=e.payer_id),'payee_name',(select display_name from public.parties where id=e.payee_id),'allocations',(select coalesce(jsonb_agg(jsonb_build_object('trip_id',a.trip_id,'amount',a.amount::text) order by a.id),'[]') from public.allocations a where a.event_id=e.id and a.component='CASH'));
end $$;

create function private.output_receipt_choice(event uuid,recipient text,party uuid,filters jsonb) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin return private.output_receipt(event,recipient,party,filters);exception when insufficient_privilege or invalid_parameter_value then return null;end $$;

create function public.list_output_receipts(recipient_kind text,recipient_id uuid,filters jsonb,page_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare q jsonb:=private.report_filter(filters);begin
 perform private.output_recipient(recipient_kind,recipient_id);
 if page_offset is null or page_offset<0 then raise exception 'INVALID_PAGE' using errcode='22023';end if;
 return (with candidates as materialized(select e.id,e.effective_date,private.output_receipt_choice(e.id,recipient_kind,recipient_id,filters) data from public.financial_events e where e.business_id=(q->>'business')::uuid and e.effective_date between (q->>'from')::date and (q->>'to')::date and (recipient_id is null or recipient_id in(e.payer_id,e.payee_id)) and e.kind not in('DISPATCH','ADJUSTMENT','EXPENSE','REVERSAL')),page as(select * from candidates where data is not null order by effective_date desc,id limit 50 offset page_offset) select coalesce(jsonb_agg(jsonb_build_object('id',id,'label',data->>'payment_date'||' · PKR '||(data->>'amount')||' · '||(data->>'payer_name')||' → '||(data->>'payee_name')) order by effective_date desc,id),'[]') from page);
end $$;

create function public.prepare_output(report_kind text,recipient_kind text,recipient_id uuid,filters jsonb,field_order text[] default null,format_options jsonb default '{}',preset_id uuid default null,event_id uuid default null,page_offset integer default 0) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare q jsonb:=private.report_filter(filters);recipient_label text:=private.output_recipient(recipient_kind,recipient_id);p public.output_presets;selected text[]:=field_order;options jsonb:=format_options;catalogue jsonb;totals jsonb;rows jsonb;count_rows bigint;meta jsonb;doc jsonb;receipt jsonb;
begin
 if page_offset is null or page_offset<0 or page_offset>1000000 then raise exception 'INVALID_PAGE' using errcode='22023';end if;
 if preset_id is not null then p:=private.load_output_preset(preset_id);if p.report_kind<>report_kind or p.recipient_kind<>recipient_kind then raise exception 'PRESET_TYPE_MISMATCH' using errcode='22023';end if;if selected is null then selected:=p.field_order;options:=p.format_options;end if;end if;
 perform private.validate_output(report_kind,recipient_kind,selected,options);
 if report_kind in('TRIP_PROFIT','CUSTOMER_INVOICE') and q->>'trip_id' is null then raise exception 'TRIP_REQUIRED' using errcode='22023';end if;
 if report_kind<>'PAYMENT_RECEIPT' and event_id is not null then raise exception 'INVALID_EVENT_FILTER' using errcode='22023';end if;
 select jsonb_agg(to_jsonb(c) order by k.pos) into catalogue from unnest(selected) with ordinality k(key,pos) join private.output_fields(report_kind,recipient_kind)c on c.field_key=k.key;
 meta:=jsonb_build_object('period',case when report_kind in('TRIP_PROFIT','CUSTOMER_INVOICE') then 'Lifetime trip — all linked dates; current balances' else q->>'from'||' to '||(q->>'to') end,'scope',q->>'label','offices',q->'office_names','complete',q->'complete','generated_at',statement_timestamp(),'recipient_name',recipient_label,'date_bases',jsonb_build_object('earnings','Dispatch / explicit adjustment date','payments','Payment date','claims',case when report_kind in('TRIP_PROFIT','CUSTOMER_INVOICE') then 'Current lifetime' else 'Period end' end)||case when recipient_kind in('INTERNAL','OWNER') then jsonb_build_object('expenses','Expense date') else '{}'::jsonb end);
 if report_kind in('CUSTOMER_INVOICE','PAYMENT_RECEIPT') then doc:=public.require_document_setup();meta:=meta||jsonb_build_object('company_name',doc->'company'->>'name','issuer_name',doc->'issuer'->>'display_name','document_number','Not issued — preview','document_date',(statement_timestamp() at time zone 'Asia/Karachi')::date);end if;
 if report_kind='PAYMENT_RECEIPT' then
  if event_id is null then raise exception 'RECEIPT_REQUIRED' using errcode='22023';end if;
  receipt:=private.output_receipt(event_id,recipient_kind,recipient_id,filters);totals:=jsonb_build_object('receipt_amount',receipt->>'amount');meta:=meta||totals;
  with raw as(select jsonb_build_object('record_name',coalesce(t.trip_number,'Standalone payment'),'trip_number',t.trip_number,'vehicle_registration',v.registration,'dispatch_date',t.dispatch_date,'arrival_date',t.arrival_date,'origin',o.name,'destination',d.name,'payer_name',receipt->>'payer_name','payee_name',receipt->>'payee_name','payment_date',receipt->>'payment_date','allocation_amount',a->>'amount') data from jsonb_array_elements(receipt->'allocations')a left join public.trips t on t.id=(a->>'trip_id')::uuid left join public.vehicles v on v.id=t.vehicle_id left join public.offices o on o.id=t.origin_office_id left join public.offices d on d.id=t.destination_office_id),ordered as(select data,row_number()over(order by data->>'record_name') n from raw),page as(select * from ordered order by n limit 50 offset page_offset)
  select (select count(*) from raw),coalesce(jsonb_agg((select coalesce(jsonb_object_agg(k,data->k),'{}') from unnest(selected)k join private.output_fields(report_kind,recipient_kind)c on c.field_key=k where not c.header)),'[]') into count_rows,rows from page;
 else
  with facts as materialized(select f.* from private.report_facts(filters,report_kind in('TRIP_PROFIT','CUSTOMER_INVOICE'))f where recipient_kind='INTERNAL' or recipient_kind='OWNER' and (f.owner_id=recipient_id and f.metric in('owner_earnings','owner_cost','owner_settled','owner_due','owner_recovery') or f.party_id=recipient_id and f.metric in('funding_due','reimbursement_due')) or recipient_kind='CUSTOMER' and (f.customer_id=recipient_id or f.party_id=recipient_id) and f.metric in('customer_fare','receipts','refunds','credit_created','credit_applied','customer_outstanding','customer_credit') or recipient_kind='BROKER' and (f.broker_id=recipient_id and f.metric in('customer_fare','customer_outstanding','brokerage','brokerage_due','brokerage_recovery','owner_settled','receipts') or f.party_id=recipient_id and f.metric in('custody','funding_due','reimbursement_due','commission_settled','receipts'))),
  total_raw as(select jsonb_object_agg(metric,amount) data from(select metric,sum(value) amount from facts group by metric)x),
  grouped as(select case when report_kind='MONTHLY_VEHICLE' then vehicle_id else coalesce(trip_id,vehicle_id) end id,metric,sum(value) amount from facts group by 1,2),
  amounts as(select g.id,private.report_totals(jsonb_object_agg(g.metric,g.amount)) data from grouped g group by g.id),
  named as(select z.id,coalesce(t.trip_number,v.registration,'Standalone') name,z.data||jsonb_build_object('record_name',coalesce(t.trip_number,v.registration,'Standalone'),'vehicle_registration',v.registration,'trip_number',t.trip_number,'dispatch_date',t.dispatch_date,'arrival_date',t.arrival_date,'origin',o.name,'destination',d.name,'car_count',(select coalesce(sum(c.car_count),0) from public.consignments c where c.trip_id=t.id and (recipient_kind in('INTERNAL','OWNER') or recipient_kind='CUSTOMER' and c.customer_id=recipient_id or recipient_kind='BROKER' and c.broker_id=recipient_id)),
  'car_identifiers',(select string_agg(x.identifier,', ' order by x.identifier) from public.consignment_cars x join public.consignments c on c.id=x.consignment_id where x.trip_id=t.id and (recipient_kind in('INTERNAL','OWNER') or recipient_kind='CUSTOMER' and c.customer_id=recipient_id or recipient_kind='BROKER' and c.broker_id=recipient_id)),
  'pickup_drop',(select string_agg(x.kind||': '||x.address,'; ' order by x.position) from public.stops x where x.trip_id=t.id and (recipient_kind in('INTERNAL','OWNER') or exists(select 1 from public.consignment_cars car join public.consignments c on c.id=car.consignment_id where x.id in(car.pickup_stop_id,car.drop_stop_id) and (recipient_kind='CUSTOMER' and c.customer_id=recipient_id or recipient_kind='BROKER' and c.broker_id=recipient_id)))),
  'notes',case when recipient_kind='INTERNAL' then t.notes when recipient_kind='CUSTOMER' then (select string_agg(c.notes,'; ' order by c.id) from public.consignments c where c.trip_id=t.id and c.customer_id=recipient_id) else null end) raw
  from amounts z left join public.trips t on t.id=z.id left join public.vehicles v on v.id=coalesce(t.vehicle_id,z.id) left join public.offices o on o.id=t.origin_office_id left join public.offices d on d.id=t.destination_office_id),
  page as(select * from named order by name,id limit 50 offset page_offset)
  select private.report_totals(coalesce((select data from total_raw),'{}')),(select count(*) from named),coalesce(jsonb_agg((select coalesce(jsonb_object_agg(k,raw->k),'{}') from unnest(selected)k join private.output_fields(report_kind,recipient_kind)c on c.field_key=k where not c.header) order by name,id),'[]') into totals,count_rows,rows from page;
  -- Only eligible summary metrics leave the backend, independently of optional columns.
  select coalesce(jsonb_object_agg(k,v),'{}') into totals from jsonb_each(totals)x(k,v) where exists(select 1 from private.output_fields(report_kind,recipient_kind)c where c.field_key=k and c.value_type in('MONEY','INTEGER'));
  if report_kind='CUSTOMER_INVOICE' then totals:=totals||jsonb_build_object('invoice_total',totals->>'customer_fare');meta:=meta||jsonb_build_object('invoice_total',totals->>'invoice_total');end if;
 end if;
 -- Counts are JSON integers; every money amount stays a two-place decimal string.
 select coalesce(jsonb_object_agg(x.key,case when c.value_type='INTEGER' then to_jsonb((x.value#>>'{}')::numeric::bigint) else x.value end),'{}') into totals from jsonb_each(totals)x join private.output_fields(report_kind,recipient_kind)c on c.field_key=x.key;
 select coalesce(jsonb_agg((select jsonb_object_agg(x.key,case when c.value_type='INTEGER' and x.value<>'null'::jsonb then to_jsonb((x.value#>>'{}')::numeric::bigint) else x.value end) from jsonb_each(r.row)x join private.output_fields(report_kind,recipient_kind)c on c.field_key=x.key) order by r.pos),'[]') into rows from jsonb_array_elements(rows) with ordinality r(row,pos);
 return jsonb_build_object('catalogue_version',1,'report_kind',report_kind,'recipient_kind',recipient_kind,'field_order',selected,'fields',catalogue,'summary_fields',(select coalesce(jsonb_agg(jsonb_build_object('field_key',c.field_key,'label',c.label)),'[]') from private.output_fields(report_kind,recipient_kind)c where totals ? c.field_key),'format_options',jsonb_build_object('orientation','AUTO','sheet_name','Records')||options,'metadata',meta,'totals',totals,'rows',rows,'row_count',count_rows,'page_offset',page_offset,'page_size',50,'has_more',count_rows>page_offset+50,'issued',false);
end $$;

create function public.get_output_catalogue(report_kind text,recipient_kind text) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if (private.current_staff()).id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 return jsonb_build_object('version',1,'report_kind',report_kind,'recipient_kind',recipient_kind,'fields',(select jsonb_agg(to_jsonb(x) order by default_position nulls last,field_key) from private.output_fields(report_kind,recipient_kind)x),'defaults',(select jsonb_agg(field_key order by default_position,field_key) from private.output_fields(report_kind,recipient_kind) where default_position is not null),'format_defaults',jsonb_build_object('orientation','AUTO','sheet_name','Records'));
end $$;

create function private.validate_output(report text,recipient text,fields text[],options jsonb) returns void language plpgsql immutable set search_path='' as $$
begin
 perform * from private.output_fields(report,recipient);
 if fields is null or cardinality(fields) not between 1 and 100 or exists(select 1 from unnest(fields) k where k is null or not exists(select 1 from private.output_fields(report,recipient)c where c.field_key=k)) then raise exception 'FORBIDDEN_FIELD' using errcode='42501';end if;
 if (select count(distinct x) from unnest(fields)x)<>cardinality(fields) then raise exception 'DUPLICATE_FIELDS' using errcode='22023';end if;
 if exists(select 1 from private.output_fields(report,recipient)c where c.required and not(c.field_key=any(fields))) then raise exception 'REQUIRED_FIELDS' using errcode='22023';end if;
 if jsonb_typeof(options) is distinct from 'object' or exists(select 1 from jsonb_object_keys(options)k where k not in('orientation','sheet_name')) or options ? 'orientation' and (jsonb_typeof(options->'orientation') is distinct from 'string' or options->>'orientation' not in('AUTO','PORTRAIT','LANDSCAPE')) or options ? 'sheet_name' and (jsonb_typeof(options->'sheet_name') is distinct from 'string' or length(btrim(options->>'sheet_name')) not between 1 and 31 or options->>'sheet_name' ~ '[\[\]:*?/\\]') then raise exception 'INVALID_FORMAT_OPTIONS' using errcode='22023';end if;
end $$;

create function private.output_preset_display(p public.output_presets,s public.staff_profiles) returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb:=jsonb_build_object('id',p.id,'name',p.name,'shared',p.shared,'version',p.version,'report_kind',p.report_kind,'recipient_kind',p.recipient_kind,'can_manage',p.owner_staff_id=s.id and not p.shared or p.shared and s.role='ADMIN');begin
 perform private.validate_output(p.report_kind,p.recipient_kind,p.field_order,p.format_options);
 return result||jsonb_build_object('valid',true,'field_order',p.field_order,'format_options',p.format_options);
exception when insufficient_privilege or invalid_parameter_value then return result||jsonb_build_object('valid',false,'incompatibility','Review selection under the current catalogue');end $$;

create function public.list_output_presets(report_kind text,recipient_kind text) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform * from private.output_fields(report_kind,recipient_kind);
 return (select coalesce(jsonb_agg(private.output_preset_display(p,s) order by p.shared desc,p.name,p.id),'[]') from public.output_presets p where p.business_id=s.business_id and p.report_kind=list_output_presets.report_kind and p.recipient_kind=list_output_presets.recipient_kind and (p.shared or p.owner_staff_id=s.id));
end $$;

create function private.load_output_preset(preset uuid) returns public.output_presets language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();p public.output_presets;begin
 select * into p from public.output_presets x where x.id=preset and x.business_id=s.business_id and (x.shared or x.owner_staff_id=s.id);
 if s.id is null or p.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform private.validate_output(p.report_kind,p.recipient_kind,p.field_order,p.format_options);return p;
end $$;

create function public.save_output_preset(target_id uuid,request_id uuid,expected_version integer,payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();p public.output_presets;cached private.output_requests;cmd jsonb;result jsonb;shared boolean;fields text[];preset_name text;begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||s.business_id::text,0));s:=private.current_staff();
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if target_id is null or request_id is null or expected_version is null or jsonb_typeof(payload) is distinct from 'object' or length(payload::text)>10000 or exists(select 1 from jsonb_object_keys(payload)k where k not in('name','shared','report_kind','recipient_kind','field_order','format_options')) or jsonb_typeof(payload->'name') is distinct from 'string' or jsonb_typeof(payload->'shared') is distinct from 'boolean' or jsonb_typeof(payload->'field_order') is distinct from 'array' or exists(select 1 from jsonb_array_elements(payload->'field_order')x where jsonb_typeof(x)<>'string') then raise exception 'INVALID_PRESET' using errcode='22023';end if;
 shared:=(payload->>'shared')::boolean;preset_name:=btrim(payload->>'name');if length(preset_name) not between 1 and 80 then raise exception 'INVALID_PRESET_NAME' using errcode='22023';end if;
 if shared and s.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;
 fields:=array(select jsonb_array_elements_text(payload->'field_order'));perform private.validate_output(payload->>'report_kind',payload->>'recipient_kind',fields,payload->'format_options');
 select * into p from public.output_presets x where x.id=target_id;
 if p.id is not null and (p.business_id<>s.business_id or p.shared and s.role<>'ADMIN' or not p.shared and p.owner_staff_id<>s.id or p.shared is distinct from shared) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 cmd:=jsonb_build_object('action','SAVE','target',target_id,'version',expected_version,'payload',payload);
 select * into cached from private.output_requests r where r.business_id=s.business_id and r.request_id=save_output_preset.request_id;
 if found then if cached.actor_id<>s.id or cached.command<>cmd then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;return cached.result;end if;
 if p.id is null and expected_version<>0 or p.id is not null and expected_version<>p.version then raise exception 'VERSION_CONFLICT' using errcode='PT409';end if;
 if p.id is null then
  insert into public.output_presets(id,business_id,owner_staff_id,name,shared,report_kind,recipient_kind,field_order,format_options,created_by) values(target_id,s.business_id,s.id,preset_name,shared,payload->>'report_kind',payload->>'recipient_kind',fields,payload->'format_options',s.auth_user_id);
 else update public.output_presets set name=preset_name,report_kind=payload->>'report_kind',recipient_kind=payload->>'recipient_kind',field_order=fields,format_options=payload->'format_options',version=version+1 where id=p.id;end if;
 select jsonb_build_object('id',x.id,'name',x.name,'shared',x.shared,'version',x.version) into result from public.output_presets x where x.id=target_id;
 insert into public.audit_events(business_id,actor_id,record_type,record_id,action,before_data,after_data,created_by) values(s.business_id,s.id,'OUTPUT_PRESET',target_id,'SAVE_PRESET',case when p.id is null then null else jsonb_build_object('name',p.name,'version',p.version) end,result,s.auth_user_id);
 insert into private.output_requests values(s.business_id,request_id,s.id,cmd,result);return result;
end $$;

create function public.delete_output_preset(target_id uuid,request_id uuid,expected_version integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();p public.output_presets;cached private.output_requests;cmd jsonb;result jsonb;begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||s.business_id::text,0));s:=private.current_staff();
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if target_id is null or request_id is null or expected_version is null then raise exception 'INVALID_PRESET' using errcode='22023';end if;
 cmd:=jsonb_build_object('action','DELETE','target',target_id,'version',expected_version);
 select * into cached from private.output_requests r where r.business_id=s.business_id and r.request_id=delete_output_preset.request_id;
 if found then if cached.actor_id<>s.id or cached.command<>cmd or (cached.result->>'shared')::boolean and s.role<>'ADMIN' then raise exception 'FORBIDDEN' using errcode='42501';end if;return cached.result;end if;
 select * into p from public.output_presets x where x.id=target_id and x.business_id=s.business_id;
 if p.id is null or p.shared and s.role<>'ADMIN' or not p.shared and p.owner_staff_id<>s.id then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if expected_version<>p.version then raise exception 'VERSION_CONFLICT' using errcode='PT409';end if;
 delete from public.output_presets where id=p.id;
 result:=jsonb_build_object('id',p.id,'deleted',true,'shared',p.shared);
 insert into public.audit_events(business_id,actor_id,record_type,record_id,action,before_data,created_by) values(s.business_id,s.id,'OUTPUT_PRESET',p.id,'DELETE_PRESET',jsonb_build_object('name',p.name,'version',p.version),s.auth_user_id);
 insert into private.output_requests values(s.business_id,request_id,s.id,cmd,result);return result;
end $$;

-- Whole-trip advances still belong to their actual customer in recipient reports.
create or replace function private.report_facts(filters jsonb,lifetime boolean default false)
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
  select l.*,e.effective_date,z.root_kind,h.owner_id historical_owner,coalesce(c.customer_id,case when z.root_kind in('CUSTOMER_RECEIPT','ADVANCE') then e.payer_id when z.root_kind='REFUND' then e.payee_id end) customer,c.broker_id broker
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
alter function private.output_fields(text,text) owner to carrier_security;
revoke all on function private.output_fields(text,text) from public,anon,authenticated;
alter function private.output_recipient(text,uuid) owner to carrier_security;
revoke all on function private.output_recipient(text,uuid) from public,anon,authenticated;
alter function private.output_receipt(uuid,text,uuid,jsonb) owner to carrier_security;
revoke all on function private.output_receipt(uuid,text,uuid,jsonb) from public,anon,authenticated;
alter function private.output_receipt_choice(uuid,text,uuid,jsonb) owner to carrier_security;
revoke all on function private.output_receipt_choice(uuid,text,uuid,jsonb) from public,anon,authenticated;
alter function private.validate_output(text,text,text[],jsonb) owner to carrier_security;
revoke all on function private.validate_output(text,text,text[],jsonb) from public,anon,authenticated;
alter function private.load_output_preset(uuid) owner to carrier_security;
alter function private.output_preset_display(public.output_presets,public.staff_profiles) owner to carrier_security;
revoke all on function private.output_preset_display(public.output_presets,public.staff_profiles) from public,anon,authenticated;
revoke all on function private.load_output_preset(uuid) from public,anon,authenticated;
alter function public.get_output_catalogue(text,text) owner to carrier_security;
revoke all on function public.get_output_catalogue(text,text) from public,anon,authenticated;
grant execute on function public.get_output_catalogue(text,text) to authenticated;
alter function public.list_output_presets(text,text) owner to carrier_security;
revoke all on function public.list_output_presets(text,text) from public,anon,authenticated;
grant execute on function public.list_output_presets(text,text) to authenticated;
alter function public.save_output_preset(uuid,uuid,integer,jsonb) owner to carrier_security;
revoke all on function public.save_output_preset(uuid,uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.save_output_preset(uuid,uuid,integer,jsonb) to authenticated;
alter function public.delete_output_preset(uuid,uuid,integer) owner to carrier_security;
revoke all on function public.delete_output_preset(uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.delete_output_preset(uuid,uuid,integer) to authenticated;
alter function public.prepare_output(text,text,uuid,jsonb,text[],jsonb,uuid,uuid,integer) owner to carrier_security;
revoke all on function public.prepare_output(text,text,uuid,jsonb,text[],jsonb,uuid,uuid,integer) from public,anon,authenticated;
grant execute on function public.prepare_output(text,text,uuid,jsonb,text[],jsonb,uuid,uuid,integer) to authenticated;
alter function public.list_output_receipts(text,uuid,jsonb,integer) owner to carrier_security;
revoke all on function public.list_output_receipts(text,uuid,jsonb,integer) from public,anon,authenticated;
grant execute on function public.list_output_receipts(text,uuid,jsonb,integer) to authenticated;
revoke all on public.output_fields,public.output_presets from anon,authenticated;
revoke create on schema private,public from carrier_security;
revoke carrier_security from postgres;
