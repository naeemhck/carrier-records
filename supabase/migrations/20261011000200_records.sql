-- T02 schema contracts. No staff-facing write/read policies exist until T03.
-- All links between business records include business_id to prevent mixed scope.
create table public.businesses (
  id uuid primary key default gen_random_uuid(),
name text not null check (length(btrim(name)) > 0),
  currency text not null default 'PKR' check (currency = 'PKR'),
  date_zone text not null default 'Asia/Karachi' check (date_zone = 'Asia/Karachi'),
  contact_details jsonb not null default '{}' check (jsonb_typeof(contact_details) = 'object'),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0)
);

create table public.offices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
code text not null, name text not null, archived_at timestamptz,
  unique (business_id, code),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.staff_profiles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
auth_user_id uuid not null unique references auth.users(id),
  username text not null check (username = lower(btrim(username)) and username <> ''),
  display_name text not null, role text not null check (role in ('ADMIN','STAFF')),
  active boolean not null default true, must_change_password boolean not null default true,
  unique (business_id, username),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.staff_offices (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
staff_id uuid not null, office_id uuid not null,
  unique (business_id, staff_id, office_id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, staff_id) references public.staff_profiles(business_id, id),
  foreign key (business_id, office_id) references public.offices(business_id, id)
);

create table public.parties (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
code text not null, display_name text not null, contact_details jsonb not null default '{}',
  archived_at timestamptz, unique (business_id, code),
  check (jsonb_typeof(contact_details) = 'object'),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.party_roles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
party_id uuid not null, role text not null check (role in ('OWNER','CUSTOMER','BROKER','DRIVER','BUSINESS','OTHER')),
  unique (business_id, party_id, role),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, party_id) references public.parties(business_id, id)
);

create table public.vehicles (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
registration text not null, current_owner_id uuid not null, default_driver_id uuid,
  archived_at timestamptz, unique (business_id, registration),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, current_owner_id) references public.parties(business_id, id),
  foreign key (business_id, default_driver_id) references public.parties(business_id, id)
);

create table public.routes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
code text not null, origin_label text not null, destination_label text not null,
  suggested_fare numeric(18,2) check (suggested_fare between 0 and 9999999999999999.99),
  archived_at timestamptz, unique (business_id, code),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
name text not null, archived_at timestamptz, unique (business_id, name),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
trip_number text not null, vehicle_id uuid not null, driver_id uuid,
  origin_office_id uuid not null, destination_office_id uuid not null, route_id uuid,
  owner_id uuid not null, owner_snapshot jsonb not null,
  route_snapshot jsonb not null default '{}',
  load_kind text not null check (load_kind in ('LOADED','EMPTY')),
  state text not null default 'DRAFT' check (state in ('DRAFT','DISPATCHED','ARRIVED','CANCELLED')),
  planned_dispatch_date date, dispatch_date date, arrival_date date, return_of_trip_id uuid,
  overlap_confirmed boolean not null default false, overlap_reason text, notes text not null default '',
  unique (business_id, trip_number),
  check (origin_office_id <> destination_office_id),
  check (return_of_trip_id is null or return_of_trip_id <> id),
  check (jsonb_typeof(owner_snapshot) = 'object' and owner_snapshot <> '{}'),
  check (jsonb_typeof(route_snapshot) = 'object'),
  check (arrival_date is null or (dispatch_date is not null and arrival_date >= dispatch_date)),
  check (state not in ('DISPATCHED','ARRIVED') or dispatch_date is not null),
  check (state <> 'ARRIVED' or arrival_date is not null),
  check (not overlap_confirmed or length(btrim(overlap_reason)) > 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, vehicle_id) references public.vehicles(business_id, id),
  foreign key (business_id, driver_id) references public.parties(business_id, id),
  foreign key (business_id, origin_office_id) references public.offices(business_id, id),
  foreign key (business_id, destination_office_id) references public.offices(business_id, id),
  foreign key (business_id, route_id) references public.routes(business_id, id),
  foreign key (business_id, owner_id) references public.parties(business_id, id),
  foreign key (business_id, return_of_trip_id) references public.trips(business_id, id)
);

create table public.consignments (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
trip_id uuid not null, customer_id uuid not null, broker_id uuid,
  state text not null default 'ACTIVE' check (state in ('ACTIVE','DELIVERED','CANCELLED')),
  car_count integer not null check (car_count > 0),
  quoted_amount numeric(18,2) not null check (quoted_amount between 0 and 9999999999999999.99),
  quote_mode text not null check (quote_mode in ('DEDUCTED','ADDED')),
  commission_method text not null check (commission_method in ('FIXED','PERCENTAGE')),
  commission_value numeric(18,2) not null check (commission_value between 0 and 9999999999999999.99),
  commission numeric(18,2) not null, customer_charge numeric(18,2) not null, owner_entitlement numeric(18,2) not null,
  notes text not null default '',
  unique (business_id, trip_id, id),
  check (customer_charge = owner_entitlement + commission),
  check (commission >= 0 and owner_entitlement >= 0),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, trip_id) references public.trips(business_id, id),
  foreign key (business_id, customer_id) references public.parties(business_id, id),
  foreign key (business_id, broker_id) references public.parties(business_id, id)
);

create table public.stops (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
trip_id uuid not null, position integer not null check (position > 0),
  kind text not null check (kind in ('PICKUP','DROP','OTHER')), address text not null,
  unique (business_id, trip_id, position), unique (business_id, trip_id, id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, trip_id) references public.trips(business_id, id)
);

create table public.consignment_cars (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
trip_id uuid not null, consignment_id uuid not null, identifier text not null,
  pickup_stop_id uuid, drop_stop_id uuid,
  unique (business_id, consignment_id, identifier),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, trip_id, consignment_id) references public.consignments(business_id, trip_id, id),
  foreign key (business_id, trip_id, pickup_stop_id) references public.stops(business_id, trip_id, id),
  foreign key (business_id, trip_id, drop_stop_id) references public.stops(business_id, trip_id, id)
);

create table public.receipt_files (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
office_id uuid not null, trip_id uuid, object_path text not null,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','application/pdf')),
  byte_size integer not null check (byte_size between 1 and 5242880),
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  archived_at timestamptz, unique (business_id, object_path),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, office_id) references public.offices(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
vehicle_id uuid not null, trip_id uuid, office_id uuid not null, category_id uuid not null,
  expense_date date not null, amount numeric(18,2) not null check (amount between 0.01 and 9999999999999999.99),
  payer_id uuid not null, cost_bearer_id uuid not null, funding_source text not null,
  state text not null default 'DRAFT' check (state in ('DRAFT','CONFIRMED')),
  receipt_file_id uuid, notes text not null default '',
  check (funding_source in ('PERSONAL_FUNDS','HELD_TRIP_FUNDS','SELF_FUNDED_COST')),
  check (funding_source <> 'SELF_FUNDED_COST' or payer_id = cost_bearer_id),
  check (funding_source <> 'PERSONAL_FUNDS' or payer_id <> cost_bearer_id),
  check (funding_source <> 'HELD_TRIP_FUNDS' or trip_id is not null),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, vehicle_id) references public.vehicles(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id),
  foreign key (business_id, office_id) references public.offices(business_id, id),
  foreign key (business_id, category_id) references public.expense_categories(business_id, id),
  foreign key (business_id, payer_id) references public.parties(business_id, id),
  foreign key (business_id, cost_bearer_id) references public.parties(business_id, id),
  foreign key (business_id, receipt_file_id) references public.receipt_files(business_id, id)
);

create table public.financial_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
kind text not null check (kind in ('DISPATCH','CUSTOMER_RECEIPT','ADVANCE','ADVANCE_APPLICATION','CUSTODY_TRANSFER','OWNER_SETTLEMENT','COMMISSION_SETTLEMENT','PERSONAL_FUNDING','FUNDING_RECOVERY','EXPENSE','REIMBURSEMENT','REFUND','ADJUSTMENT','REVERSAL','REPLACEMENT')),
  effective_date date not null, recorded_at timestamptz not null default now(),
  actor_id uuid not null, office_id uuid not null, vehicle_id uuid, trip_id uuid, consignment_id uuid, expense_id uuid,
  payer_id uuid, payee_id uuid, amount numeric(18,2) not null check (amount between 0 and 9999999999999999.99),
  request_id uuid not null, reversal_of_id uuid, replacement_of_id uuid, reason text,
  unique (business_id, request_id), unique (business_id, reversal_of_id), unique (business_id, replacement_of_id),
  check (reversal_of_id is null or (kind = 'REVERSAL' and reversal_of_id <> id and length(btrim(reason)) > 0)),
  check (kind <> 'REVERSAL' or reversal_of_id is not null),
  check (replacement_of_id is null or (kind = 'REPLACEMENT' and replacement_of_id <> id and length(btrim(reason)) > 0)),
  check (kind <> 'REPLACEMENT' or replacement_of_id is not null),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, actor_id) references public.staff_profiles(business_id, id),
  foreign key (business_id, office_id) references public.offices(business_id, id),
  foreign key (business_id, vehicle_id) references public.vehicles(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id),
  foreign key (business_id, consignment_id) references public.consignments(business_id, id),
  foreign key (business_id, expense_id) references public.expenses(business_id, id),
  foreign key (business_id, payer_id) references public.parties(business_id, id),
  foreign key (business_id, payee_id) references public.parties(business_id, id),
  foreign key (business_id, reversal_of_id) references public.financial_events(business_id, id),
  foreign key (business_id, replacement_of_id) references public.financial_events(business_id, id)
);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
event_id uuid not null, party_id uuid not null, office_id uuid not null,
  vehicle_id uuid, trip_id uuid, consignment_id uuid, expense_id uuid,
  account_purpose text not null check (account_purpose in ('CUSTOMER_RECEIVABLE','CUSTODY_RECEIVABLE','OWNER_PAYABLE','BROKER_COMMISSION_PAYABLE','CUSTOMER_ADVANCE_CREDIT','EXPENSE_REIMBURSEMENT_PAYABLE','TRIP_FUNDING_PAYABLE','PARTY_COST_RECOVERY')),
  signed_amount numeric(18,2) not null check (signed_amount <> 0 and abs(signed_amount) <= 9999999999999999.99),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, event_id) references public.financial_events(business_id, id),
  foreign key (business_id, party_id) references public.parties(business_id, id),
  foreign key (business_id, office_id) references public.offices(business_id, id),
  foreign key (business_id, vehicle_id) references public.vehicles(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id),
  foreign key (business_id, consignment_id) references public.consignments(business_id, id),
  foreign key (business_id, expense_id) references public.expenses(business_id, id)
);

create table public.allocations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
event_id uuid not null, source_event_id uuid, source_line_id uuid, target_line_id uuid,
  trip_id uuid not null, consignment_id uuid, expense_id uuid,
  amount numeric(18,2) not null check (amount between 0.01 and 9999999999999999.99),
  component text not null check (component in ('CASH','OFFSET','CREDIT_APPLICATION')),
  reversal_of_id uuid, unique (business_id, reversal_of_id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, event_id) references public.financial_events(business_id, id),
  foreign key (business_id, source_event_id) references public.financial_events(business_id, id),
  foreign key (business_id, source_line_id) references public.journal_lines(business_id, id),
  foreign key (business_id, target_line_id) references public.journal_lines(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id),
  foreign key (business_id, consignment_id) references public.consignments(business_id, id),
  foreign key (business_id, expense_id) references public.expenses(business_id, id),
  foreign key (business_id, reversal_of_id) references public.allocations(business_id, id)
);

create table public.idempotency_records (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
request_id uuid not null, actor_id uuid not null, command text not null,
  payload_digest text not null check (payload_digest ~ '^[0-9a-f]{64}$'),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  unique (business_id, request_id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, actor_id) references public.staff_profiles(business_id, id)
);

create table public.output_fields (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
field_key text not null, report_kind text not null, recipient_kind text not null,
  label text not null, field_group text not null, value_type text not null,
  required boolean not null default false, default_position integer check (default_position > 0),
  unique (business_id, report_kind, recipient_kind, field_key),
  check (recipient_kind in ('INTERNAL','CUSTOMER','OWNER','BROKER')),
  check (value_type in ('TEXT','MONEY','DATE','INTEGER','BOOLEAN')),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.output_presets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
owner_staff_id uuid not null, name text not null, shared boolean not null default false,
  report_kind text not null, recipient_kind text not null,
  field_order text[] not null, format_options jsonb not null default '{}',
  check (recipient_kind in ('INTERNAL','CUSTOMER','OWNER','BROKER')),
  check (jsonb_typeof(format_options) = 'object'),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, owner_staff_id) references public.staff_profiles(business_id, id)
);

create table public.issued_documents (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
document_type text not null check (document_type in ('INVOICE','RECEIPT')),
  permanent_number text not null, issued_at timestamptz not null default now(), issue_year integer not null,
  issuer_staff_id uuid not null, office_id uuid not null, trip_id uuid, recipient_id uuid not null,
  recipient_kind text not null check (recipient_kind in ('CUSTOMER','OWNER','BROKER')),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object' and snapshot <> '{}'),
  field_order text[] not null, format_options jsonb not null,
  schema_version integer not null check (schema_version > 0), template_version integer not null check (template_version > 0),
  content_digest text not null check (content_digest ~ '^[0-9a-f]{64}$'),
  supersedes_id uuid, unique (business_id, permanent_number), unique (business_id, supersedes_id),
  check (issue_year between 1 and 9999), check (supersedes_id is null or supersedes_id <> id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, issuer_staff_id) references public.staff_profiles(business_id, id),
  foreign key (business_id, office_id) references public.offices(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id),
  foreign key (business_id, recipient_id) references public.parties(business_id, id),
  foreign key (business_id, supersedes_id) references public.issued_documents(business_id, id)
);

create table public.document_sequences (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
document_type text not null check (document_type in ('INVOICE','RECEIPT')),
  issue_year integer not null check (issue_year between 1 and 9999),
  last_number bigint not null check (last_number > 0), unique (business_id, document_type, issue_year),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id)
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
actor_id uuid not null, office_id uuid, trip_id uuid, record_id uuid not null,
  record_type text not null, action text not null, reason text,
  before_data jsonb, after_data jsonb, recorded_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, actor_id) references public.staff_profiles(business_id, id),
  foreign key (business_id, office_id) references public.offices(business_id, id),
  foreign key (business_id, trip_id) references public.trips(business_id, id)
);

create table public.import_batches (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
client_batch_id uuid not null, template_version integer not null check (template_version > 0),
  office_id uuid not null, state text not null default 'DRAFT' check (state in ('DRAFT','COMMITTED','REJECTED')),
  payload_digest text not null check (payload_digest ~ '^[0-9a-f]{64}$'),
  committed_at timestamptz, unique (business_id, client_batch_id),
  check ((state = 'COMMITTED') = (committed_at is not null)),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, office_id) references public.offices(business_id, id)
);

create table public.import_rows (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
batch_id uuid not null, client_row_id uuid not null, row_number integer not null check (row_number > 0),
  record_kind text not null check (record_kind in ('PARTY','VEHICLE','ROUTE','TRIP_DRAFT','CONSIGNMENT_DRAFT','STOP','CAR','EXPENSE_DRAFT')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'), validation_errors jsonb not null default '[]',
  result_record_id uuid, unique (business_id, batch_id, client_row_id), unique (business_id, batch_id, row_number),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, batch_id) references public.import_batches(business_id, id)
);

create table public.backup_status (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
admin_staff_id uuid not null, last_verified_success_at timestamptz, last_attempt_at timestamptz,
  outcome text not null check (outcome in ('NEVER_RUN','SUCCESS','FAILED')),
  pending_receipt_count integer not null default 0 check (pending_receipt_count >= 0),
  safe_error_code text, off_pc_copy_at timestamptz, unique (business_id, admin_staff_id),
  check (outcome <> 'SUCCESS' or last_verified_success_at is not null),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1 check (version > 0),
  unique (business_id, id),
foreign key (business_id, admin_staff_id) references public.staff_profiles(business_id, id)
);

create index trips_origin_date on public.trips (business_id, origin_office_id, dispatch_date desc);
create index trips_destination_state on public.trips (business_id, destination_office_id, state);
create index trips_vehicle_state on public.trips (business_id, vehicle_id, state, dispatch_date);
create index consignments_customer_trip on public.consignments (business_id, customer_id, trip_id);
create index expenses_office_date on public.expenses (business_id, office_id, expense_date);
create index expenses_vehicle_date on public.expenses (business_id, vehicle_id, expense_date);
create index events_trip_date on public.financial_events (business_id, trip_id, effective_date);
create index journal_claim_context on public.journal_lines (business_id, party_id, account_purpose, trip_id);
create index allocations_source on public.allocations (business_id, source_line_id);
create index allocations_target on public.allocations (business_id, target_line_id);
create index audit_record on public.audit_events (business_id, record_type, record_id, recorded_at);
create index documents_recipient on public.issued_documents (business_id, recipient_id, issued_at);
