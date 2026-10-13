"""Reproducible local-only v2 presentation migration; no connection or secrets."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
frames={
 'offices':('Offices','دفاتر'), 'date_bases':('Date bases','تاریخ کی بنیادیں'),
 'currency':('Currency','کرنسی'), 'records':('Records','ریکارڈز'),
 'supersedes':('Supersedes','پچھلی دستاویز کی جگہ'), 'row':('Row','قطار'),
 'summary':('Authoritative summary','مصدقہ خلاصہ'),
 'no_records':('No records in this period/scope.','اس مدت یا دائرے میں کوئی ریکارڈ نہیں۔'),
 'selected':('Selected attributes {0}-{1} of {2}','منتخب خانے {0}-{1} از {2}'),
 'page':('Page {0} of {1}','صفحہ {0} از {1}'),
 'issued':('Issued snapshot','جاری کردہ محفوظ دستاویز'),
 'live':('Current authorized records','موجودہ مجاز ریکارڈز'),
 'continuation':('Long text continues in visible rows; amounts appear once per source record.','طویل متن اگلی قطاروں میں جاری ہے؛ رقم ہر اصل ریکارڈ کے لیے صرف ایک بار ہے۔'),
 'precision':('Amounts exceeding Excel numeric precision remain exact decimal text; PKR is the currency.','Excel کی عددی حد سے بڑی رقم درست اعشاری متن کے طور پر محفوظ ہے؛ کرنسی PKR ہے۔'),
 'totals':('Totals are server-calculated for all {0} authorized records.','تمام {0} مجاز ریکارڈز کے کل سرور سے مصدقہ ہیں۔'),
}
bases={'earnings':'آمدنی','expenses':'اخراجات','payments':'ادائیگیاں','claims':'واجب الادا رقوم',
 'Dispatch / explicit adjustment date':'روانگی یا واضح ترمیم کی تاریخ',
 'Payment date':'ادائیگی کی تاریخ','Expense date':'خرچ کی تاریخ',
 'Current lifetime':'موجودہ مکمل مدت','Period end':'مدت کا اختتام'}
def main():
 target=next((ROOT/'supabase/migrations').glob('*_karvaan_bilingual_documents.sql'))
 translations={x['en']:x['ur'] for x in json.loads((ROOT/'tools/karvaan/phrases.json').read_text(encoding='utf-8'))}
 # Include every report title explicitly, independent of UI wording.
 translations.update({'Vehicle monthly report':'گاڑی کی ماہانہ رپورٹ','Owner statement':'مالک کا گوشوارہ','Broker monthly statement':'بروکر کا ماہانہ گوشوارہ','Customer statement':'گاہک کا گوشوارہ','Lifetime trip profit':'ٹرپ کی مکمل مدت کا منافع','Customer invoice':'گاہک کا بل','Payment receipt':'ادائیگی کی رسید','Document number':'دستاویز نمبر'})
 labels=json.dumps(translations,ensure_ascii=False).replace("'","''")
 frame_json=json.dumps({k:dict(en=en,ur=ur) for k,(en,ur) in frames.items()},ensure_ascii=False).replace("'","''")
 bases_json=json.dumps(bases,ensure_ascii=False).replace("'","''")
 helper=f"""-- Karvaan v2: presentation only. Legacy requests/snapshots remain v1.
-- Frozen labels enter the digest in the existing issuance transaction.
grant carrier_documents,carrier_security to postgres;
create or replace function private.karvaan_output_v2(source jsonb) returns jsonb
language plpgsql immutable security invoker set search_path='' as $$
declare dictionary jsonb:='{labels}'::jsonb;
 frames jsonb:='{frame_json}'::jsonb; bases jsonb:='{bases_json}'::jsonb;
 fields jsonb:='{{}}'; summaries jsonb:='{{}}'; dates jsonb:='{{}}'; f jsonb; entry record; english text; urdu text; title text;
begin
 if source is null or source->>'template_version' is distinct from '1' or source->>'schema_version' is distinct from '1' then raise exception 'INVALID_PRESENTATION_VERSION' using errcode='22023';end if;
 for f in select value from jsonb_array_elements(source->'fields') loop
  english:=f->>'label';urdu:=dictionary->>english;
  if urdu is null then raise exception 'UNTRANSLATED_OUTPUT_FIELD' using errcode='22023';end if;
  fields:=fields||jsonb_build_object(f->>'field_key',jsonb_build_object('en',english,'ur',urdu));
 end loop;
 for f in select value from jsonb_array_elements(source->'summary_fields') loop
  english:=f->>'label';urdu:=dictionary->>english;
  if urdu is null then raise exception 'UNTRANSLATED_OUTPUT_FIELD' using errcode='22023';end if;
  summaries:=summaries||jsonb_build_object(f->>'field_key',jsonb_build_object('en',english,'ur',urdu));
 end loop;
 for entry in select * from jsonb_each_text(source->'metadata'->'date_bases') loop
  if bases->>entry.key is null or bases->>entry.value is null then raise exception 'UNTRANSLATED_DATE_BASIS' using errcode='22023';end if;
  dates:=dates||jsonb_build_object(entry.key,jsonb_build_object('en',entry.key||': '||entry.value,'ur',(bases->>entry.key)||': '||(bases->>entry.value)));
 end loop;
 title:=case source->>'report_kind' when 'MONTHLY_VEHICLE' then 'Vehicle monthly report' when 'OWNER_STATEMENT' then 'Owner statement' when 'BROKER_MONTHLY' then 'Broker monthly statement' when 'CUSTOMER_STATEMENT' then 'Customer statement' when 'TRIP_PROFIT' then 'Lifetime trip profit' when 'CUSTOMER_INVOICE' then 'Customer invoice' when 'PAYMENT_RECEIPT' then 'Payment receipt' end;
 if title is null then raise exception 'INVALID_OUTPUT' using errcode='22023';end if;
 return source||jsonb_build_object('template_version',2,'presentation',jsonb_build_object(
  'version',2,'font_set','noto-karvaan-20261013','brand',jsonb_build_object('en','Karvaan','ur','کارواں'),
  'title',jsonb_build_object('en',title||case when (source->>'issued')::boolean then '' else ' - not issued' end,
   'ur',(dictionary->>title)||case when (source->>'issued')::boolean then '' else ' - غیر جاری شدہ' end),
  'fields',fields,'summaries',summaries,'frames',frames,'date_bases',dates));
end $$;
revoke all on function private.karvaan_output_v2(jsonb) from public,anon,authenticated;
grant execute on function private.karvaan_output_v2(jsonb) to carrier_documents,carrier_security;
"""
 original=(ROOT/'supabase/migrations/20261012044220_immutable_documents.sql').read_text(encoding='utf-8')
 issue=original[original.index('create function public.issue_document('):original.index('\nalter function private.document_access')]
 issue=issue.replace('create function','create or replace function',1)
 issue=issue.replace("'supersedes_id','reason'))", "'supersedes_id','reason','presentation_version'))")
 issue=issue.replace(' select * into cached'," if payload ? 'presentation_version' and payload->'presentation_version' is distinct from '2'::jsonb then raise exception 'INVALID_PRESENTATION_VERSION' using errcode='22023';end if;\n select * into cached",1)
 issue=issue.replace('\n selected:=array',"\n if payload->'presentation_version'='2'::jsonb then snap:=private.karvaan_output_v2(snap);end if;\n selected:=array",1)
 issue=issue.replace("snap->'format_options',1,1,encode", "snap->'format_options',1,(snap->>'template_version')::integer,encode")
 export=(ROOT/'supabase/migrations/20261012051630_export_payloads.sql').read_text(encoding='utf-8')
 export=export[export.index('create function public.prepare_output_export'):export.index('\nalter function public.prepare_output_export')].replace('create function','create or replace function',1)
 export=export.replace("'preset_id','event_id'))", "'preset_id','event_id','presentation_version'))")
 export=export.replace(" if command->'field_order'", " if command ? 'presentation_version' and command->'presentation_version' is distinct from '2'::jsonb then raise exception 'INVALID_PRESENTATION_VERSION' using errcode='22023';end if;\n if command->'field_order'",1)
 export=export.replace(' return result||',' result:=result||').replace("'template_version',1);\nend", "'template_version',1);\n if command->'presentation_version'='2'::jsonb then result:=private.karvaan_output_v2(result);end if;\n return result;\nend")
 for required in ['presentation_version','private.karvaan_output_v2(snap)',"(snap->>'template_version')::integer"]:
  if required not in issue:raise RuntimeError('Issuance rewrite failed')
 target.write_text(helper+'\n'+issue+'\n'+export+"\nrevoke carrier_documents,carrier_security from postgres;\nnotify pgrst,'reload schema';\n",encoding='utf-8')
 print('Generated presentation-only migration; existing locks, permissions, retries and v1 defaults retained.')
if __name__=='__main__':main()
