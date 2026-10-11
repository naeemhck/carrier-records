-- Synthetic fixtures exist only within this rolled-back test transaction.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select is(public.calculate_quote('100000','DEDUCTED','FIXED','5000',true)->>'customer_charge',
  '100000.00', 'AT-01 customer quote');
select is(public.calculate_quote('100000','DEDUCTED','FIXED','5000',true)->>'owner_entitlement',
  '95000.00', 'AT-01 owner share');
select is(public.calculate_quote('100000','DEDUCTED','FIXED','5000',true)->>'commission',
  '5000.00', 'AT-01 brokerage');
select is(public.calculate_quote('100000','ADDED','FIXED','5000',true)->>'customer_charge',
  '105000.00', 'AT-02 added customer charge');
select is(public.calculate_quote('100000','ADDED','FIXED','5000',true)->>'owner_entitlement',
  '100000.00', 'AT-02 owner quote unchanged');
select is(public.calculate_quote('100000','ADDED','PERCENTAGE','5',true)->>'commission',
  '5000.00', 'AT-03 added percent follows owner quote');
select is(public.calculate_quote('100000','DEDUCTED','PERCENTAGE','5',true)->>'commission',
  '5000.00', 'AT-03 deducted percent follows customer quote');
select is(public.calculate_quote('0.01','ADDED','PERCENTAGE','50',true)->>'commission',
  '0.01', 'AT-03 half paisa rounds up');
select is(public.calculate_quote('0.01','ADDED','PERCENTAGE','49.99',true)->>'commission',
  '0.00', 'AT-03 less than half paisa rounds down');
select is(public.calculate_quote('9999999999999999.99','DEDUCTED','PERCENTAGE','100',true)->>'commission',
  '9999999999999999.99', 'Maximum quote multiplication is exact');
select throws_ok($$select public.calculate_quote('1','DEDUCTED','FIXED','1.01',true)$$,
  '22023','VALIDATION_ERROR: deduction exceeds quote','AT-03 invalid deduction rejected');
select throws_ok($$select public.calculate_quote('1','ADDED','PERCENTAGE','100.01',true)$$,
  '22023','VALIDATION_ERROR: percentage out of range','Invalid percentage rejected');
select throws_ok($$select public.calculate_quote('0','ADDED','PERCENTAGE','1',false)$$,
  '22023','VALIDATION_ERROR: commission requires broker','Broker eligibility checked before rounding');
select throws_ok($$select public.calculate_quote('9999999999999999.99','ADDED','FIXED','0.01',true)$$,
  '22003','VALIDATION_ERROR: quote result out of range','Added quote overflow rejected');
select is(public.parse_money('0.10') + public.parse_money('0.20'), 0.30::numeric,
  'AT-17 exact decimal sum');
select is(public.parse_money('-0.00')::text, '0.00', 'Canonical zero');
select is(public.parse_money('00012.3')::text, '12.30', 'Canonical two-place string');
select throws_ok($$select public.parse_money('1.001')$$,'22023',
  'VALIDATION_ERROR: decimal money string required','AT-17 extra decimals rejected before numeric rounding');
select throws_ok($$select public.parse_money('1.000')$$,'22023',
  'VALIDATION_ERROR: decimal money string required','Extra zero decimals also rejected');
select throws_ok($$select public.parse_money('1e2')$$,'22023',
  'VALIDATION_ERROR: decimal money string required','Scientific notation rejected');
select throws_ok($$select public.parse_money('NaN')$$,'22023',
  'VALIDATION_ERROR: decimal money string required','Nonfinite numeric rejected');
select throws_ok($$select public.parse_money(null)$$,'22023',
  'VALIDATION_ERROR: decimal money string required','Null money rejected');
select throws_ok($$select public.parse_money('10000000000000000')$$,'22003',
  'VALIDATION_ERROR: money out of range','Money overflow rejected');
select is(public.parse_business_date('2024-02-29'), date '2024-02-29', 'Leap date accepted');
select throws_ok($$select public.parse_business_date('2025-02-29')$$,'22008',null,
  'Invalid calendar date rejected');
select throws_ok($$select public.parse_business_date('2026-01-01T00:00:00Z')$$,'22023',
  'VALIDATION_ERROR: ISO business date required','Timestamp is not a business date');

insert into public.businesses (id,name) values
 ('00000000-0000-0000-0000-000000000001','Synthetic business A'),
 ('00000000-0000-0000-0000-000000000002','Synthetic business B');
insert into public.offices (id,business_id,code,name) values
 ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000001','A1','Synthetic origin'),
 ('00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000001','A2','Synthetic destination'),
 ('00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000002','B1','Other business');
insert into public.parties (id,business_id,code,display_name) values
 ('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000001','OWNER','Synthetic owner'),
 ('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000001','CUSTOMER','Synthetic customer'),
 ('00000000-0000-0000-0000-000000000023','00000000-0000-0000-0000-000000000001','BROKER','Synthetic broker');
insert into public.party_roles (business_id,party_id,role) values
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000021','OWNER'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000022','CUSTOMER'),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000023','BROKER');
insert into public.vehicles (id,business_id,registration,current_owner_id) values
 ('00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000001','SYNTHETIC-A','00000000-0000-0000-0000-000000000021');
insert into public.trips (id,business_id,trip_number,vehicle_id,origin_office_id,destination_office_id,
 owner_id,owner_snapshot,load_kind) values
 ('00000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000001','SYNTHETIC-TRIP',
 '00000000-0000-0000-0000-000000000031','00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000021',
 '{"display_name":"Synthetic owner at trip creation"}','LOADED');
insert into public.consignments (id,business_id,trip_id,customer_id,broker_id,car_count,
 quoted_amount,quote_mode,commission_method,commission_value,commission,customer_charge,owner_entitlement) values
 ('00000000-0000-0000-0000-000000000051','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000041','00000000-0000-0000-0000-000000000022',
 '00000000-0000-0000-0000-000000000023',2,100000,'DEDUCTED','FIXED',5000,1,2,1);
select is((select owner_entitlement from public.consignments where id = '00000000-0000-0000-0000-000000000051'),
  95000::numeric, 'Backend replaces forged client pricing snapshot');
select throws_ok($$update public.vehicles set current_owner_id = '00000000-0000-0000-0000-000000000022',
  version = 2 where id = '00000000-0000-0000-0000-000000000031'$$,'23503',null,
  'Customer-only party cannot become vehicle owner');
select throws_ok($$update public.trips set origin_office_id = '00000000-0000-0000-0000-000000000013',
  version = 2 where id = '00000000-0000-0000-0000-000000000041'$$,'23503',null,
  'Composite office FK rejects another business');
select throws_ok($$update public.parties set display_name = 'Changed without version'
  where id = '00000000-0000-0000-0000-000000000021'$$,'40001','VERSION_CONFLICT',
  'Operational stale version rejected');
update public.parties set display_name = 'Changed master', version = 2
  where id = '00000000-0000-0000-0000-000000000021';
select is((select owner_snapshot->>'display_name' from public.trips where id = '00000000-0000-0000-0000-000000000041'),
  'Synthetic owner at trip creation', 'Trip owner snapshot independent of master changes');
select throws_ok($$update public.trips set load_kind = 'EMPTY', version = 2
  where id = '00000000-0000-0000-0000-000000000041'$$,'22023',
  'VALIDATION_ERROR: loaded trip cannot become empty','Empty return cannot retain loads');
select ok(not has_table_privilege('anon','public.trips','SELECT'),'Anonymous has no trip grant');
select ok(has_table_privilege('authenticated','public.trips','SELECT'),'T03 grants trip reads subject to RLS');
select ok(not has_table_privilege('authenticated','public.financial_events','INSERT'),'Direct financial writes revoked');
select ok(not has_function_privilege('authenticated','public.calculate_quote(text,text,text,text,boolean)','EXECUTE'),
  'RPC grants remain closed until T03');
select is((select count(*)::integer from pg_tables where schemaname = 'public' and rowsecurity),
  27, 'All 27 application tables have default-deny RLS');

-- Historical output snapshot is append-only, not a mutable report cache.
insert into auth.users (id) values ('00000000-0000-0000-0000-000000000061');
insert into public.staff_profiles (id,business_id,auth_user_id,username,display_name,role) values
 ('00000000-0000-0000-0000-000000000062','00000000-0000-0000-0000-000000000001',
 '00000000-0000-0000-0000-000000000061','synthetic.admin','Synthetic admin','ADMIN');
insert into public.issued_documents (id,business_id,document_type,permanent_number,issue_year,issuer_staff_id,
 office_id,recipient_id,recipient_kind,snapshot,field_order,format_options,schema_version,template_version,content_digest) values
 ('00000000-0000-0000-0000-000000000071','00000000-0000-0000-0000-000000000001','INVOICE','SYNTHETIC-INV',2026,
 '00000000-0000-0000-0000-000000000062','00000000-0000-0000-0000-000000000011',
 '00000000-0000-0000-0000-000000000022','CUSTOMER','{"issuer":"Synthetic original issuer"}',
 array['identity'],'{}',1,1,repeat('a',64));
select throws_ok($$update public.issued_documents set snapshot = '{}' where id = '00000000-0000-0000-0000-000000000071'$$,
 '55000','IMMUTABLE_HISTORY: append a linked correction','Issued snapshot cannot be overwritten');
select throws_ok($$delete from public.issued_documents where id = '00000000-0000-0000-0000-000000000071'$$,
 '55000','IMMUTABLE_HISTORY: append a linked correction','Issued number cannot be deleted/reused');

insert into public.financial_events (id,business_id,kind,effective_date,actor_id,office_id,amount,request_id) values
 ('00000000-0000-0000-0000-000000000081','00000000-0000-0000-0000-000000000001','DISPATCH',date '2026-01-01',
 '00000000-0000-0000-0000-000000000062','00000000-0000-0000-0000-000000000011',100000,
 '00000000-0000-0000-0000-000000000082');
insert into public.journal_lines (business_id,event_id,party_id,office_id,account_purpose,signed_amount) values
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000081',
 '00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000011','CUSTOMER_RECEIVABLE',100000),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000081',
 '00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000011','OWNER_PAYABLE',-95000),
 ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000081',
 '00000000-0000-0000-0000-000000000023','00000000-0000-0000-0000-000000000011','BROKER_COMMISSION_PAYABLE',-5000);
select lives_ok('set constraints all immediate','Balanced synthetic dispatch lines pass deferred constraint');
select throws_ok($$update public.financial_events set amount = 0 where id = '00000000-0000-0000-0000-000000000081'$$,
 '55000','IMMUTABLE_HISTORY: append a linked correction','Financial event cannot be edited');
select throws_ok($$delete from public.journal_lines where event_id = '00000000-0000-0000-0000-000000000081'$$,
 '55000','IMMUTABLE_HISTORY: append a linked correction','Journal cannot be deleted');
select throws_ok($$insert into public.journal_lines (business_id,event_id,party_id,office_id,account_purpose,signed_amount)
 values ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000081',
 '00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000011','CUSTOMER_RECEIVABLE',0.01)$$,
 '23514','UNBALANCED_JOURNAL','Unbalanced insertion rejected at transaction constraint');
select * from finish();
rollback;
