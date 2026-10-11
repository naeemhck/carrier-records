-- Text interfaces reject extra decimals before NUMERIC(18,2) can round them.
create function public.parse_money(value text) returns numeric
language plpgsql immutable set search_path = '' as $$
declare result numeric;
begin
  if value is null or value !~ '^-?[0-9]+([.][0-9]{1,2})?$' then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: decimal money string required';
  end if;
  result := value::numeric;
  if abs(result) > 9999999999999999.99 then
    raise exception using errcode = '22003', message = 'VALIDATION_ERROR: money out of range';
  end if;
  return result::numeric(18,2);
end;
$$;

create function public.parse_business_date(value text) returns date
language plpgsql immutable set search_path = '' as $$
declare result date;
begin
  if value is null or value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: ISO business date required';
  end if;
  result := make_date(substring(value,1,4)::integer,
    substring(value,6,2)::integer, substring(value,9,2)::integer);
  if result < date '0001-01-01' or result > date '9999-12-31' then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: business date out of range';
  end if;
  return result;
end;
$$;

create function public.calculate_quote(
  quoted_amount text, mode text, method text, commission_value text, has_broker boolean
) returns jsonb language plpgsql stable set search_path = '' as $$
declare
  q numeric := public.parse_money(quoted_amount);
  v numeric := public.parse_money(commission_value);
  c numeric; customer numeric; owner_fare numeric;
begin
  if q < 0 or v < 0 or mode is null or mode not in ('DEDUCTED','ADDED')
      or method is null or method not in ('FIXED','PERCENTAGE') or has_broker is null then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: invalid quote';
  end if;
  if method = 'PERCENTAGE' and v > 100 then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: percentage out of range';
  end if;
  if not has_broker and v <> 0 then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: commission requires broker';
  end if;
  c := case when method = 'FIXED' then v else round(q * v / 100, 2) end;
  if mode = 'DEDUCTED' and c > q then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: deduction exceeds quote';
  end if;
  customer := case when mode = 'ADDED' then q + c else q end;
  owner_fare := case when mode = 'DEDUCTED' then q - c else q end;
  if customer > 9999999999999999.99 then
    raise exception using errcode = '22003', message = 'VALIDATION_ERROR: quote result out of range';
  end if;
  return jsonb_build_object('quoted_amount', q::numeric(18,2)::text,
    'mode', mode, 'method', method, 'commission_value', v::numeric(18,2)::text,
    'has_broker', has_broker, 'commission', c::numeric(18,2)::text,
    'customer_charge', customer::numeric(18,2)::text,
    'owner_entitlement', owner_fare::numeric(18,2)::text);
end;
$$;

-- Pure functions expose no stored business data. RPC grants wait for T03.
revoke all on function public.parse_money(text) from public, anon, authenticated;
revoke all on function public.parse_business_date(text) from public, anon, authenticated;
revoke all on function public.calculate_quote(text,text,text,text,boolean) from public, anon, authenticated;
