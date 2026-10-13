"""Copy the proven exact OOXML writer into an explicit new template, retaining v1."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 source=(ROOT/'app/lib/features/reports/output_xlsx.dart').read_text(encoding='utf-8')
 source=source.replace("import 'authorized_output.dart';","import 'authorized_output.dart';\nimport 'bilingual_output.dart';")
 source=source.replace('renderOutputXlsx(', 'renderOutputXlsxV2(').replace('AuthorizedOutput.fromPayload(payload)','BilingualOutput(payload)')
 source=source.replace('output.summaries[e.key]', 'output.summaries[e.key]!.combined')
 for en,key in [('Authoritative summary','summary'),('Long text continues in visible rows; amounts appear once per source record.','continuation'),('No records in this period/scope.','no_records'),('Amounts exceeding Excel numeric precision remain exact decimal text; PKR is the currency.','precision')]:
  source=source.replace("'"+en+"'", "output.frames['"+key+"']!.combined")
 source=source.replace("?? 'Carrier Records'",'?? output.brand.en').replace('<Application>Carrier Records</Application>','<Application>Karvaan</Application>')
 source=source.replace('height: 42,','height: 88,').replace('height: 46','height: 80').replace('height: 30','height: 60').replace('height: 36','height: 70')
 source=source.replace('vertical="top" wrapText="1"','vertical="top" wrapText="1" readingOrder="1"').replace('vertical="center" wrapText="1"','vertical="center" wrapText="1" readingOrder="1"')
 source=source.replace('/// OOXML writes decimal tokens directly.', '/// Template 2 uses frozen bilingual labels; v1 is unchanged.\n/// OOXML writes decimal tokens directly.')
 (ROOT/'app/lib/features/reports/output_xlsx_v2.dart').write_text(source,encoding='utf-8')
 print('Generated separate exact-decimal, formula-safe template 2 writer.')
if __name__=='__main__':main()
