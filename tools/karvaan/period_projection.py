"""Measured report projection rewrite; old/new SQL parity runs before applying."""
import json
from local_environment import sql,require

PERIOD_KEYS=""" cross join lateral(
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
 ) m where m.key is not null and l.signed_amount<>0"""
PERIOD_AMOUNT="case when m.key in('owner_earnings','brokerage','credit_created') then -l.signed_amount else l.signed_amount end"

def rewrite(source):
 start=source.index(" cross join lateral(values\n  ('customer_fare'")
 end=source.index(' ) m(key,amount) where m.amount<>0',start)+len(' ) m(key,amount) where m.amount<>0')
 old=source[start:end]
 result=source[:start]+PERIOD_KEYS+source[end:]
 result=result.replace('select m.key,m.amount,l.vehicle_id,l.historical_owner','select m.key,'+PERIOD_AMOUNT+',l.vehicle_id,l.historical_owner',1)
 previous=""" costs as (
  select x.* from public.expenses x left join trips h on h.id=x.trip_id
  where x.business_id=b and x.state='CONFIRMED' and (lifetime and x.trip_id=t or not lifetime and x.expense_date between f and d)
"""
 replacement=""" cost_candidates as materialized (
  -- Bound the month before trip-index/anti-reversal probes (12,000 -> 1,000).
  select x.* from public.expenses x where x.business_id=b and x.state='CONFIRMED'
   and (lifetime and x.trip_id=t or not lifetime and x.expense_date between f and d)
 ), costs as (
  select x.* from cost_candidates x left join trips h on h.id=x.trip_id
  where true
"""
 require(result.count(previous)==1,'Expected measured expense-query shape absent.')
 result=result.replace(previous,replacement)
 result=result.replace("where e.expense_id=x.id and e.kind in('EXPENSE','REPLACEMENT')", "where e.business_id=b and r.business_id=b and e.expense_id=x.id and e.kind in('EXPENSE','REPLACEMENT')")
 require(result!=source,'No rewrite produced.')
 return result,old

def parity_query(old):
 roots=['DISPATCH','ADJUSTMENT','CUSTOMER_RECEIPT','ADVANCE','REFUND','OWNER_SETTLEMENT','PERSONAL_FUNDING','COMMISSION_SETTLEMENT','ADVANCE_APPLICATION','EXPENSE','REVERSAL','REPLACEMENT','UNKNOWN']
 purposes=['CUSTOMER_RECEIVABLE','CUSTOMER_ADVANCE_CREDIT','OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE','CUSTODY_RECEIVABLE','TRIP_FUNDING_PAYABLE','EXPENSE_REIMBURSEMENT_PAYABLE','PARTY_COST_RECOVERY','UNKNOWN']
 quote=lambda values:','.join("('"+v+"')" for v in values)
 query="""with scenarios as(select root_kind,account_purpose,signed_amount from(values %s)r(root_kind) cross join(values %s)p(account_purpose) cross join(values(-9999999999999999.99::numeric),(-1.01::numeric),(0::numeric),(1.01::numeric),(9999999999999999.99::numeric))n(signed_amount)),old as(select l.*,m.key,m.amount from scenarios l %s),new as(select l.*,m.key,%s amount from scenarios l %s),differences as((select * from old except all select * from new) union all(select * from new except all select * from old)) select jsonb_build_object('scenarios',(select count(*) from scenarios),'differences',(select count(*) from differences),'old_rows',(select count(*) from old),'new_rows',(select count(*) from new));"""%(quote(roots),quote(purposes),old,PERIOD_AMOUNT,PERIOD_KEYS)
 return query

def parity(old):
 result=json.loads(sql(parity_query(old)));require(result['differences']==0 and result['scenarios']==585,'Exact period metric parity failed.');return result
