-- Role eligibility is a relationship constraint, not a client-only dropdown.
alter table public.vehicles add column owner_role text not null default 'OWNER' check (owner_role = 'OWNER');
alter table public.vehicles add column driver_role text not null default 'DRIVER' check (driver_role = 'DRIVER');
alter table public.vehicles add foreign key (business_id, current_owner_id, owner_role)
  references public.party_roles(business_id, party_id, role);
alter table public.vehicles add foreign key (business_id, default_driver_id, driver_role)
  references public.party_roles(business_id, party_id, role);
alter table public.trips add column owner_role text not null default 'OWNER' check (owner_role = 'OWNER');
alter table public.trips add column driver_role text not null default 'DRIVER' check (driver_role = 'DRIVER');
alter table public.trips add foreign key (business_id, owner_id, owner_role)
  references public.party_roles(business_id, party_id, role);
alter table public.trips add foreign key (business_id, driver_id, driver_role)
  references public.party_roles(business_id, party_id, role);
alter table public.consignments add column customer_role text not null default 'CUSTOMER' check (customer_role = 'CUSTOMER');
alter table public.consignments add column broker_role text not null default 'BROKER' check (broker_role = 'BROKER');
alter table public.consignments add foreign key (business_id, customer_id, customer_role)
  references public.party_roles(business_id, party_id, role);
alter table public.consignments add foreign key (business_id, broker_id, broker_role)
  references public.party_roles(business_id, party_id, role);
create index staff_offices_by_office on public.staff_offices(business_id, office_id, staff_id);
create index financial_events_office_date on public.financial_events(business_id, office_id, effective_date);
create index receipt_files_by_office on public.receipt_files(business_id, office_id, trip_id);
