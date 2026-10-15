begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(3);
create temp table period_projection_comparison as select result from (with scenarios as(select root_kind,account_purpose,signed_amount from(values ('DISPATCH'),('ADJUSTMENT'),('CUSTOMER_RECEIPT'),('ADVANCE'),('REFUND'),('OWNER_SETTLEMENT'),('PERSONAL_FUNDING'),('COMMISSION_SETTLEMENT'),('ADVANCE_APPLICATION'),('EXPENSE'),('REVERSAL'),('REPLACEMENT'),('UNKNOWN'))r(root_kind) cross join(values ('CUSTOMER_RECEIVABLE'),('CUSTOMER_ADVANCE_CREDIT'),('OWNER_PAYABLE'),('BROKER_COMMISSION_PAYABLE'),('CUSTODY_RECEIVABLE'),('TRIP_FUNDING_PAYABLE'),('EXPENSE_REIMBURSEMENT_PAYABLE'),('PARTY_COST_RECOVERY'),('UNKNOWN'))p(account_purpose) cross join(values(-9999999999999999.99::numeric),(-1.01::numeric),(0::numeric),(1.01::numeric),(9999999999999999.99::numeric))n(signed_amount)),old as(select l.*,m.key,m.amount from scenarios l  cross join lateral(values
  ('customer_fare',case when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose in('CUSTOMER_RECEIVABLE','CUSTOMER_ADVANCE_CREDIT') then l.signed_amount else 0 end),
  ('owner_earnings',case when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose='OWNER_PAYABLE' then -l.signed_amount else 0 end),
  ('brokerage',case when l.root_kind in('DISPATCH','ADJUSTMENT') and l.account_purpose='BROKER_COMMISSION_PAYABLE' then -l.signed_amount else 0 end),
  ('receipts',case when l.root_kind in('CUSTOMER_RECEIPT','ADVANCE') and l.account_purpose='CUSTODY_RECEIVABLE' then l.signed_amount else 0 end),
  ('refunds',case when l.root_kind='REFUND' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then l.signed_amount else 0 end),
  ('owner_settled',case when l.root_kind in('OWNER_SETTLEMENT','PERSONAL_FUNDING') and l.account_purpose='OWNER_PAYABLE' then l.signed_amount else 0 end),
  ('commission_settled',case when l.root_kind='COMMISSION_SETTLEMENT' and l.account_purpose='BROKER_COMMISSION_PAYABLE' then l.signed_amount else 0 end),
  ('credit_created',case when l.root_kind in('ADVANCE','CUSTOMER_RECEIPT','ADJUSTMENT') and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then -l.signed_amount else 0 end),
  ('credit_applied',case when l.root_kind='ADVANCE_APPLICATION' and l.account_purpose='CUSTOMER_ADVANCE_CREDIT' then l.signed_amount else 0 end)
 ) m(key,amount) where m.amount<>0),new as(select l.*,m.key,case when m.key in('owner_earnings','brokerage','credit_created') then -l.signed_amount else l.signed_amount end amount from scenarios l  cross join lateral(
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
 ) m where m.key is not null and l.signed_amount<>0),differences as((select * from old except all select * from new) union all(select * from new except all select * from old)) select jsonb_build_object('scenarios',(select count(*) from scenarios),'differences',(select count(*) from differences),'old_rows',(select count(*) from old),'new_rows',(select count(*) from new))) c(result);
select is((result->>'scenarios')::integer,585,'All root/purpose/sign/precision scenarios included') from period_projection_comparison;
select is((result->>'differences')::integer,0,'Period metrics preserve exact multiplicity and signs') from period_projection_comparison;
with l as(select 'ADJUSTMENT'::text root_kind,'CUSTOMER_ADVANCE_CREDIT'::text account_purpose,1.01::numeric signed_amount), result as(select m.key,case when m.key in('owner_earnings','brokerage','credit_created') then -l.signed_amount else l.signed_amount end amount from l  cross join lateral(
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
 ) m where m.key is not null and l.signed_amount<>0) select ok((select jsonb_object_agg(key,amount) from result)='{"customer_fare":1.01,"credit_created":-1.01}'::jsonb,'Adjustment advance credit emits both exact metrics');
select * from finish();
rollback;
