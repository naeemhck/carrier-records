begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('authenticated','private.report_facts(jsonb,boolean)','EXECUTE'),'No raw unredacted facts endpoint');
select ok(not has_function_privilege('anon','public.get_scoped_report(text,jsonb,integer)','EXECUTE'),'Anonymous report denied');
select ok(not has_table_privilege('authenticated','public.financial_events','SELECT'),'Reports do not open event metadata');
select ok(not has_table_privilege('carrier_security','public.journal_lines','INSERT,UPDATE,DELETE'),'Report owner has no financial writes');
select ok(not pg_has_role('postgres','carrier_security','SET'),'Migration access revoked');
select ok((select prosecdef and proconfig @> array['search_path=""'] from pg_proc where oid='public.get_scoped_report(text,jsonb,integer)'::regprocedure),'Report definer search path pinned');
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.get_scoped_report('MONTHLY_VEHICLE','{"from":"2026-01-01","to":"2026-01-31"}',0)$$,'42501','FORBIDDEN','Reports require current live staff');
reset role;
with samples as (select purpose account_purpose,amount::numeric amount from unnest(array['CUSTOMER_RECEIVABLE','CUSTOMER_ADVANCE_CREDIT','CUSTODY_RECEIVABLE','OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE','TRIP_FUNDING_PAYABLE','EXPENSE_REIMBURSEMENT_PAYABLE','PARTY_COST_RECOVERY','UNKNOWN']) purpose cross join unnest(array['-9999999999999999.99','-100.01','-0.01','0','0.01','100.01','9999999999999999.99'])amount), old_projection as (select m.key,m.amount from samples z cross join lateral(values
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
), new_projection as (select m.key,m.amount from samples z cross join lateral(select
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
), missing as(select * from old_projection except all select * from new_projection), added as(select * from new_projection except all select * from old_projection) select is((select count(*) from missing)+(select count(*) from added),0::bigint,'Claim projection exact across every purpose, signs, zero and numeric boundary');
select * from finish();
rollback;
