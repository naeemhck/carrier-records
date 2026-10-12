-- Complete, coherent export payloads; no raw or hidden source data leaves the backend.
grant carrier_security to postgres;
grant create on schema public to carrier_security;
create function public.prepare_output_export(command jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare s public.staff_profiles:=private.current_staff();selected text[];part jsonb;result jsonb;rows jsonb:='[]';offset_rows integer:=0;begin
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('staff-admin:'||s.business_id::text,0));s:=private.current_staff();
 if s.id is null then raise exception 'FORBIDDEN' using errcode='42501';end if;
 if command is null or jsonb_typeof(command)<>'object' or exists(select 1 from jsonb_object_keys(command)x where x not in('report_kind','recipient_kind','recipient_id','filters','field_order','format_options','preset_id','event_id')) then raise exception 'INVALID_EXPORT' using errcode='22023';end if;
 if command->'field_order' is not null and command->'field_order'<>'null' then selected:=array(select jsonb_array_elements_text(command->'field_order'));end if;
 loop
  part:=public.prepare_output(command->>'report_kind',command->>'recipient_kind',(command->>'recipient_id')::uuid,command->'filters',selected,coalesce(command->'format_options','{}'),(command->>'preset_id')::uuid,(command->>'event_id')::uuid,offset_rows);
  if result is null then result:=part;end if;
  if part->'totals'<>result->'totals' or part->'field_order'<>result->'field_order' then raise exception 'SOURCE_CHANGED' using errcode='PT409';end if;
  rows:=rows||(part->'rows');exit when not(part->>'has_more')::boolean;
  offset_rows:=offset_rows+50;if offset_rows>100000 then raise exception 'EXPORT_TOO_LARGE' using errcode='22023';end if;
 end loop;
 return result||jsonb_build_object('rows',rows,'row_count',jsonb_array_length(rows),'page_offset',0,'has_more',false,'schema_version',1,'template_version',1);
end $$;
alter function public.prepare_output_export(jsonb) owner to carrier_security;
revoke all on function public.prepare_output_export(jsonb) from public,anon,authenticated;
grant execute on function public.prepare_output_export(jsonb) to authenticated;
revoke create on schema public from carrier_security;
revoke carrier_security from postgres;
