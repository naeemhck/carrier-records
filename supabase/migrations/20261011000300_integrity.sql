create function public.guard_operational_version() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.id <> old.id or new.created_at <> old.created_at
      or new.created_by is distinct from old.created_by
      or (to_jsonb(new)->'business_id') is distinct from (to_jsonb(old)->'business_id') then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: record identity is immutable';
  end if;
  if new.version <> old.version + 1 then
    raise exception using errcode = '40001', message = 'VERSION_CONFLICT';
  end if;
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

create function public.reject_history_change() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception using errcode = '55000', message = 'IMMUTABLE_HISTORY: append a linked correction';
end;
$$;

create function public.compute_consignment_quote() returns trigger
language plpgsql set search_path = '' as $$
declare calculated jsonb; journey_kind text;
begin
  select load_kind into journey_kind from public.trips
    where business_id = new.business_id and id = new.trip_id;
  if journey_kind = 'EMPTY' then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: empty trip cannot carry consignments';
  end if;
  calculated := public.calculate_quote(new.quoted_amount::text, new.quote_mode,
    new.commission_method, new.commission_value::text, new.broker_id is not null);
  new.commission := (calculated->>'commission')::numeric;
  new.customer_charge := (calculated->>'customer_charge')::numeric;
  new.owner_entitlement := (calculated->>'owner_entitlement')::numeric;
  return new;
end;
$$;
create trigger consignment_quote before insert or update on public.consignments
for each row execute function public.compute_consignment_quote();

-- Do not allow changing an empty/load classification around existing loads.
create function public.check_trip_load() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.load_kind = 'EMPTY' and exists (select 1 from public.consignments
      where business_id = new.business_id and trip_id = new.id) then
    raise exception using errcode = '22023', message = 'VALIDATION_ERROR: loaded trip cannot become empty';
  end if;
  return new;
end;
$$;
create trigger trip_load before update on public.trips
for each row execute function public.check_trip_load();

alter table public.trips add unique (business_id, vehicle_id, id);
alter table public.expenses add constraint expense_trip_vehicle
  foreign key (business_id, vehicle_id, trip_id) references public.trips(business_id, vehicle_id, id);
alter table public.financial_events add constraint event_consignment_trip
  foreign key (business_id, trip_id, consignment_id) references public.consignments(business_id, trip_id, id);
alter table public.financial_events add check (consignment_id is null or trip_id is not null);
alter table public.journal_lines add constraint line_consignment_trip
  foreign key (business_id, trip_id, consignment_id) references public.consignments(business_id, trip_id, id);
alter table public.journal_lines add check (consignment_id is null or trip_id is not null);
alter table public.allocations add constraint allocation_consignment_trip
  foreign key (business_id, trip_id, consignment_id) references public.consignments(business_id, trip_id, id);

-- Checks reject NULL reasons as well as blank reasons (CHECK normally accepts NULL).
alter table public.trips add check (not overlap_confirmed or coalesce(length(btrim(overlap_reason)),0) > 0);
alter table public.financial_events add check ((reversal_of_id is null and replacement_of_id is null)
  or coalesce(length(btrim(reason)),0) > 0);

create function public.check_journal_balance() returns trigger
language plpgsql set search_path = '' as $$
declare event_uuid uuid; total numeric;
begin
  if tg_table_name = 'financial_events' then
    event_uuid := new.id;
  else
    event_uuid := new.event_id;
  end if;
  select coalesce(sum(signed_amount),0) into total from public.journal_lines
    where business_id = new.business_id and event_id = event_uuid;
  if total <> 0 then
    raise exception using errcode = '23514', message = 'UNBALANCED_JOURNAL';
  end if;
  return null;
end;
$$;
create constraint trigger event_balance after insert on public.financial_events
deferrable initially deferred for each row execute function public.check_journal_balance();
create constraint trigger line_balance after insert on public.journal_lines
deferrable initially deferred for each row execute function public.check_journal_balance();

do $$
declare record_table record; history_tables text[] := array[
  'financial_events','journal_lines','allocations','idempotency_records','issued_documents','audit_events'];
begin
  for record_table in select tablename from pg_tables where schemaname = 'public'
      and tablename in ('businesses','offices','staff_profiles','staff_offices','parties','party_roles',
      'vehicles','routes','expense_categories','trips','consignments','stops','consignment_cars',
      'receipt_files','expenses','financial_events','journal_lines','allocations','idempotency_records',
      'output_fields','output_presets','issued_documents','document_sequences','audit_events',
      'import_batches','import_rows','backup_status') loop
    execute format('alter table public.%I enable row level security', record_table.tablename);
    execute format('revoke all on table public.%I from public, anon, authenticated', record_table.tablename);
    if record_table.tablename = any(history_tables) then
      execute format('create trigger immutable_history before update or delete on public.%I
        for each row execute function public.reject_history_change()', record_table.tablename);
    else
      execute format('create trigger operational_version before update on public.%I
        for each row execute function public.guard_operational_version()', record_table.tablename);
    end if;
  end loop;
end;
$$;

-- Future migrations must grant access deliberately. T03 supplies scoped policies.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
revoke all on function public.guard_operational_version() from public, anon, authenticated;
revoke all on function public.reject_history_change() from public, anon, authenticated;
revoke all on function public.compute_consignment_quote() from public, anon, authenticated;
revoke all on function public.check_trip_load() from public, anon, authenticated;
revoke all on function public.check_journal_balance() from public, anon, authenticated;

alter table public.expenses add column replaces_expense_id uuid;
alter table public.expenses add column correction_reason text;
alter table public.expenses add unique (business_id, replaces_expense_id);
alter table public.expenses add foreign key (business_id, replaces_expense_id)
  references public.expenses(business_id, id);
alter table public.expenses add check (replaces_expense_id is null or
  (replaces_expense_id <> id and coalesce(length(btrim(correction_reason)),0) > 0));

create function public.guard_confirmed_expense() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.state = 'CONFIRMED' then
    raise exception using errcode = '55000', message = 'IMMUTABLE_HISTORY: append a linked expense correction';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;
create trigger confirmed_expense before update or delete on public.expenses
for each row execute function public.guard_confirmed_expense();
revoke all on function public.guard_confirmed_expense() from public, anon, authenticated;
