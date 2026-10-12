-- T13: append-only issued snapshots; sequence updates and retries commit atomically.
create role carrier_documents nologin noinherit nobypassrls;
grant carrier_documents to postgres;
grant carrier_security to postgres;
grant usage on schema public,private,extensions to carrier_documents;
grant create on schema public,private to carrier_documents;
grant select on public.issued_documents,public.document_sequences,public.trips,
 public.journal_lines,public.financial_events,public.offices to carrier_documents;
grant insert on public.issued_documents,public.document_sequences,public.audit_events to carrier_documents;
grant update on public.document_sequences to carrier_documents;
grant execute on function private.current_staff(boolean),private.office_access(uuid,uuid),private.trip_access(uuid,uuid),
 public.prepare_output(text,text,uuid,jsonb,text[],jsonb,uuid,uuid,integer),public.require_document_setup() to carrier_documents;
grant execute on function extensions.digest(text,text) to carrier_documents;
do $$ declare n text;begin
 foreach n in array array['issued_documents','document_sequences','trips','journal_lines','financial_events','offices','audit_events'] loop
  execute format('create policy trusted_documents on public.%I to carrier_documents using(true) with check(true)',n);
 end loop;
end $$;
create table private.document_sources(
 document_id uuid primary key references public.issued_documents(id),
 business_id uuid not null references public.businesses(id),
 trip_ids uuid[] not null,office_ids uuid[] not null,event_id uuid,
 command jsonb not null
);
create table private.document_requests(
 business_id uuid not null references public.businesses(id),request_id uuid not null,
 actor_id uuid not null references public.staff_profiles(id),command jsonb not null,document_id uuid not null references public.issued_documents(id),result jsonb not null,
 primary key(business_id,request_id)
);
alter table private.document_sources enable row level security;
alter table private.document_requests enable row level security;
create policy trusted_documents on private.document_sources to carrier_documents using(true) with check(true);
create policy trusted_documents on private.document_requests to carrier_documents using(true) with check(true);
grant select,insert on private.document_sources,private.document_requests to carrier_documents;
create trigger immutable_history before update or delete on private.document_sources for each row execute function public.reject_history_change();
create trigger immutable_history before update or delete on private.document_requests for each row execute function public.reject_history_change();
revoke all on private.document_sources,private.document_requests,public.issued_documents,public.document_sequences from public,anon,authenticated;
create index documents_trip_issue on public.issued_documents(business_id,trip_id,issued_at desc,id);

create function private.document_access(document uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();x private.document_sources;begin
 if s.id is null then return false;end if;
 select * into x from private.document_sources where document_id=document and business_id=s.business_id;
 if x.document_id is null then return false;end if;
 return not exists(select 1 from unnest(x.trip_ids)t where not private.trip_access(s.business_id,t))
 and not exists(select 1 from unnest(x.office_ids)o where not private.office_access(s.business_id,o));
end $$;

create function public.get_issued_document(document_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare d public.issued_documents;s public.staff_profiles:=private.current_staff();context jsonb;begin
 if not private.document_access(document_id) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 select * into d from public.issued_documents where id=document_id and business_id=s.business_id;
 if encode(extensions.digest(d.snapshot::text,'sha256'),'hex')<>d.content_digest then raise exception 'DOCUMENT_INTEGRITY_FAILURE' using errcode='22023';end if;
 select command-'preset_id'-'supersedes_id'-'reason' into context from private.document_sources where private.document_sources.document_id=d.id;
 return jsonb_build_object('id',d.id,'permanent_number',d.permanent_number,'document_type',d.document_type,'issued_at',d.issued_at,
  'snapshot',d.snapshot,'canonical_content',d.snapshot::text,'content_digest',d.content_digest,'schema_version',d.schema_version,'template_version',d.template_version,
  'supersedes_number',(select permanent_number from public.issued_documents where id=d.supersedes_id),
  'superseded_by_number',(select permanent_number from public.issued_documents where supersedes_id=d.id),
  'can_supersede',(s.role='ADMIN' or s.id=d.issuer_staff_id) and not exists(select 1 from public.issued_documents where supersedes_id=d.id),
  'reissue_context',context);
end $$;

create function public.list_issued_documents(filters jsonb default '{}',page_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();t uuid;recipient uuid;k text;q text;begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if filters is null or jsonb_typeof(filters)<>'object' or exists(select 1 from jsonb_object_keys(filters)x where x not in('trip_id','recipient_id','document_type','search')) or page_offset is null or page_offset<0 then raise exception 'INVALID_FILTER' using errcode='22023';end if;
 t:=(filters->>'trip_id')::uuid;recipient:=(filters->>'recipient_id')::uuid;k:=filters->>'document_type';q:=coalesce(filters->>'search','');
 if t is not null and not private.trip_access(s.business_id,t) then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if length(q)>100 or k is not null and k not in('INVOICE','RECEIPT') then raise exception 'INVALID_FILTER' using errcode='22023';end if;
 return (with visible as materialized(select d.* from public.issued_documents d where d.business_id=s.business_id and (t is null or d.trip_id=t) and (recipient is null or d.recipient_id=recipient) and (k is null or d.document_type=k) and (q='' or d.permanent_number ilike '%'||q||'%' or d.snapshot->'metadata'->>'recipient_name' ilike '%'||q||'%') and private.document_access(d.id)),page as(select * from visible order by issued_at desc,id limit 50 offset page_offset)
 select jsonb_build_object('rows',coalesce(jsonb_agg(jsonb_build_object('id',id,'permanent_number',permanent_number,'document_type',document_type,'recipient',snapshot->'metadata'->>'recipient_name','issued_at',issued_at,'issuer',snapshot->'metadata'->>'issuer_name','superseded',exists(select 1 from public.issued_documents n where n.supersedes_id=page.id)) order by issued_at desc,id),'[]'),'has_more',(select count(*) from visible)>page_offset+50,'page_size',50,'page_offset',page_offset) from page);
end $$;

create function public.issue_document(request_id uuid,expected_version integer,payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();cached private.document_requests;d public.issued_documents;old public.issued_documents;
 q jsonb;setup jsonb;part jsonb;snap jsonb;all_rows jsonb:='[]';cmd jsonb:=payload;
 report text;recipient text;party uuid;event uuid;supersedes uuid;source_old private.document_sources;
 selected text[];options jsonb;filters jsonb;preset uuid;trips uuid[]:='{}';offices uuid[]:='{}';recording_office uuid;
 response jsonb;doc_id uuid:=gen_random_uuid();kind text;n bigint;year integer;number text;now_utc timestamptz;date_pk date;offset_rows integer:=0;root uuid;old_root uuid;
begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 -- All account/master/financial commands share this lock, giving one coherent snapshot.
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||s.business_id::text,0));s:=private.current_staff();
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if request_id is null or expected_version is distinct from 0 or payload is null or jsonb_typeof(payload)<>'object' or exists(select 1 from jsonb_object_keys(payload)x where x not in('report_kind','recipient_kind','recipient_id','filters','field_order','format_options','preset_id','event_id','supersedes_id','reason')) then raise exception 'INVALID_DOCUMENT' using errcode='22023';end if;
 select * into cached from private.document_requests r where r.business_id=s.business_id and r.request_id=issue_document.request_id;
 if found then
  if cached.actor_id<>s.id or cached.command<>cmd then raise exception 'IDEMPOTENCY_MISMATCH' using errcode='PT409';end if;
  perform public.get_issued_document(cached.document_id);return cached.result;
 end if;
 report:=payload->>'report_kind';recipient:=payload->>'recipient_kind';party:=(payload->>'recipient_id')::uuid;event:=(payload->>'event_id')::uuid;supersedes:=(payload->>'supersedes_id')::uuid;preset:=(payload->>'preset_id')::uuid;
 filters:=payload->'filters';options:=coalesce(payload->'format_options','{}');
 if report not in('CUSTOMER_INVOICE','PAYMENT_RECEIPT') or report is null or recipient not in('CUSTOMER','OWNER','BROKER') or recipient is null or party is null then raise exception 'INVALID_DOCUMENT' using errcode='22023';end if;
 if payload->'field_order' is not null and payload->'field_order'<>'null' then selected:=array(select jsonb_array_elements_text(payload->'field_order'));end if;
 -- The current company and current issuer must be explicitly configured inside this transaction.
 setup:=public.require_document_setup();
 part:=public.prepare_output(report,recipient,party,filters,selected,options,preset,event,0);snap:=part;
 loop
  all_rows:=all_rows||(part->'rows');exit when not(part->>'has_more')::boolean;
  offset_rows:=offset_rows+50;if offset_rows>100000 then raise exception 'DOCUMENT_TOO_LARGE' using errcode='22023';end if;
  part:=public.prepare_output(report,recipient,party,filters,selected,options,preset,event,offset_rows);
  if part->'totals'<>snap->'totals' or part->'field_order'<>snap->'field_order' then raise exception 'SOURCE_CHANGED' using errcode='PT409';end if;
 end loop;
 if jsonb_array_length(all_rows)=0 then raise exception 'NO_DOCUMENT_RECORDS' using errcode='22023';end if;
 kind:=case report when 'CUSTOMER_INVOICE' then 'INVOICE' else 'RECEIPT' end;
 if kind='INVOICE' then trips:=array[(filters->>'trip_id')::uuid];
 else
  select coalesce(array_agg(distinct l.trip_id)filter(where l.trip_id is not null),'{}'),coalesce(array_agg(distinct l.office_id)filter(where l.trip_id is null),'{}') into trips,offices from public.journal_lines l where l.event_id=event and l.business_id=s.business_id;
 end if;
 if supersedes is not null then
  if not private.document_access(supersedes) then raise exception 'FORBIDDEN' using errcode='42501';end if;
  select * into old from public.issued_documents where id=supersedes;
  if s.role<>'ADMIN' and old.issuer_staff_id<>s.id then raise exception 'FORBIDDEN' using errcode='42501';end if;
  if old.document_type<>kind or old.recipient_kind<>recipient or old.recipient_id<>party or kind='INVOICE' and old.trip_id is distinct from trips[1] or coalesce(length(btrim(payload->>'reason')),0) not between 1 and 1000 then raise exception 'INVALID_SUPERSESSION' using errcode='22023';end if;
  if exists(select 1 from public.issued_documents where supersedes_id=old.id) then raise exception 'DOCUMENT_ALREADY_SUPERSEDED' using errcode='PT409';end if;
  if kind='RECEIPT' then
   select * into source_old from private.document_sources where document_id=old.id;
   root:=event;loop select replacement_of_id into old_root from public.financial_events where id=root;exit when old_root is null;root:=old_root;end loop;
   old_root:=source_old.event_id;loop select replacement_of_id into supersedes from public.financial_events where id=old_root;exit when supersedes is null;old_root:=supersedes;end loop;
   if root<>old_root then raise exception 'INVALID_SUPERSESSION' using errcode='22023';end if;
  end if;
 elsif coalesce(payload->>'reason','')<>'' then raise exception 'INVALID_SUPERSESSION' using errcode='22023';end if;
 select o.id into recording_office from public.offices o where o.business_id=s.business_id and private.office_access(s.business_id,o.id) and (o.id=any(offices) or exists(select 1 from public.trips t where t.id=any(trips) and o.id in(t.origin_office_id,t.destination_office_id))) order by o.id limit 1;
 if recording_office is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 now_utc:=clock_timestamp();date_pk:=(now_utc at time zone 'Asia/Karachi')::date;year:=extract(year from date_pk)::integer;
 insert into public.document_sequences(business_id,document_type,issue_year,last_number,created_by) values(s.business_id,kind,year,1,s.auth_user_id)
 on conflict(business_id,document_type,issue_year) do update set last_number=public.document_sequences.last_number+1,version=public.document_sequences.version+1 returning last_number into n;
 number:=(case kind when 'INVOICE' then 'INV-' else 'RCP-' end)||year::text||'-'||lpad(n::text,greatest(6,length(n::text)),'0');
 snap:=snap||jsonb_build_object('rows',all_rows,'row_count',jsonb_array_length(all_rows),'page_offset',0,'has_more',false,'issued',true,'schema_version',1,'template_version',1);
 select jsonb_agg(case when f->>'field_key'='document_number' then f||jsonb_build_object('label','Document number') else f end order by pos) into part from jsonb_array_elements(snap->'fields') with ordinality x(f,pos);
 snap:=jsonb_set(snap,'{fields}',part);
 snap:=jsonb_set(snap,'{metadata}',snap->'metadata'||jsonb_build_object('document_number',number,'document_date',date_pk,'issued_at',now_utc,'company_name',setup->'company'->>'name','issuer_name',setup->'issuer'->>'display_name','supersedes_number',old.permanent_number));
 -- Explicit display snapshots only: no Auth IDs, contacts blobs, filters or cached source data.
 snap:=snap||jsonb_build_object('company_snapshot',jsonb_build_object('name',setup->'company'->>'name'),
 'issuer_snapshot',jsonb_build_object('display_name',setup->'issuer'->>'display_name'),
 'recipient_snapshot',jsonb_build_object('display_name',snap->'metadata'->>'recipient_name','kind',recipient));
 selected:=array(select jsonb_array_elements_text(snap->'field_order'));
 insert into public.issued_documents(id,business_id,document_type,permanent_number,issued_at,issue_year,issuer_staff_id,office_id,trip_id,recipient_id,recipient_kind,snapshot,field_order,format_options,schema_version,template_version,content_digest,supersedes_id,created_by)
 values(doc_id,s.business_id,kind,number,now_utc,year,s.id,recording_office,case when cardinality(trips)=1 then trips[1] end,party,recipient,snap,selected,snap->'format_options',1,1,encode(extensions.digest(snap::text,'sha256'),'hex'),old.id,s.auth_user_id);
 insert into private.document_sources values(doc_id,s.business_id,trips,offices,event,cmd);
 insert into public.audit_events(business_id,actor_id,office_id,trip_id,record_id,record_type,action,reason,after_data,created_by)
 values(s.business_id,s.id,recording_office,case when cardinality(trips)=1 then trips[1] end,doc_id,'DOCUMENT',case when old.id is null then 'ISSUE' else 'SUPERSEDE' end,payload->>'reason',jsonb_build_object('number',number,'supersedes',old.permanent_number),s.auth_user_id);
 response:=public.get_issued_document(doc_id);
 insert into private.document_requests values(s.business_id,request_id,s.id,cmd,doc_id,response);
 return response;
end $$;

alter function private.document_access(uuid) owner to carrier_documents;
alter function public.get_issued_document(uuid) owner to carrier_documents;
alter function public.list_issued_documents(jsonb,integer) owner to carrier_documents;
alter function public.issue_document(uuid,integer,jsonb) owner to carrier_documents;
revoke all on function private.document_access(uuid),public.get_issued_document(uuid),public.list_issued_documents(jsonb,integer),public.issue_document(uuid,integer,jsonb) from public,anon,authenticated;
grant execute on function public.get_issued_document(uuid),public.list_issued_documents(jsonb,integer),public.issue_document(uuid,integer,jsonb) to authenticated;
revoke create on schema public,private from carrier_documents;
revoke carrier_documents from postgres;
revoke carrier_security from postgres;
