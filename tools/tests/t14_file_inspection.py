"""Read actual application files with independent PDF/OOXML libraries. No authoring."""
import re,json,sys,zipfile,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
from decimal import Decimal
from pypdf import PdfReader
import openpyxl

def inspect(directory):
    directory=Path(directory);results=[]
    root=Path(__file__).resolve().parents[2]
    status=subprocess.run(['powershell','-NoProfile','-File',str(root/'tools/supabase.ps1'),'status','-o','json'],capture_output=True,text=True,check=True)
    config=json.loads(status.stdout)
    needles=[config[k].encode(encoding) for k in ('SERVICE_ROLE_KEY','SECRET_KEY','JWT_SECRET','S3_PROTOCOL_ACCESS_KEY_SECRET') if config.get(k) for encoding in ('utf-8','utf-16-le')]
    def no_keys(data):
        assert not any(value in data for value in needles), 'Privileged material found; value withheld'
    for source in sorted(directory.glob('*.json')):
        if source.stem in ('printing-info','inspection'):continue
        payload=json.loads(source.read_text(encoding='utf-8'));pdf=source.with_suffix('.pdf');xlsx=source.with_suffix('.xlsx')
        if not pdf.exists() or not xlsx.exists():continue
        fields=payload['fields'];order=payload['field_order'];columns=[next(f for f in fields if f['field_key']==k) for k in order if not next(f for f in fields if f['field_key']==k)['header']]
        reader=PdfReader(pdf);text='\n'.join(p.extract_text() or '' for p in reader.pages);metadata=str(reader.metadata)
        no_keys(pdf.read_bytes());no_keys((text+metadata).encode())
        font_sizes=[];english_pages=[]
        for page in reader.pages:
            english_chunks=[]
            no_keys(page.get_contents().get_data())
            def visit(value,cm,tm,font,size):
                if value.strip():font_sizes.append(size)
                if font is not None and 'Arabic' not in str(font.get('/BaseFont','')):english_chunks.append(value)
            page.extract_text(visitor_text=visit)
            english_pages.append(''.join(english_chunks))
        assert min(font_sizes)>=9, 'Document text below 9 pt'
        # Selected columns appear in contiguous ordered sections, with repeated table headings.
        compact=lambda value: ''.join(value.split())
        v2=payload['template_version']==2
        if v2:
            assert not re.search(r'[\u0660-\u0669\u06f0-\u06f9]',text), 'Non-Latin document digits'
            presentation=payload['presentation'];assert presentation['version']==2
            for f in fields:assert presentation['fields'][f['field_key']]['en']==f['label']
        pages=[compact(value) for value in english_pages] if v2 else [compact(page.extract_text() or '') for page in reader.pages]
        size=4 if float(reader.pages[0].mediabox.width)>float(reader.pages[0].mediabox.height) else 3
        cursor=0
        for start in range(0,len(columns),size):
            labels=[compact(f['label']) for f in columns[start:start+size]]
            matching=[i for i in range(cursor,len(pages)) if all(label in pages[i] for label in labels) and 'Row' in pages[i]]
            assert matching, 'Selected PDF column section missing'
            page=pages[matching[0]]
            assert 'Row'+''.join(labels) in page, 'PDF selected order changed'
            cursor=matching[0]
        assert reader.pages and '/EmbeddedFiles' not in str(reader.trailer) and '/JavaScript' not in str(reader.trailer)
        assert all(not p.get('/Annots') for p in reader.pages), 'Unexpected annotations/links'
        assert all(abs(float(p.mediabox.width)-595.276)<1 or abs(float(p.mediabox.width)-841.89)<1 for p in reader.pages)
        assert 'FORBIDDEN-T14-PRIVATE' not in text+metadata
        # PDF line wrapping may split the scope; retain every non-whitespace
        # character, rather than requiring one unwrapped extraction line.
        assert compact(payload['metadata']['scope'].replace('\u2014','-')) in compact(text.replace('\u2014','-')), 'Authoritative scope missing'
        for value in payload['totals'].values():
            if isinstance(value,str):
                integer,fraction=value.lstrip('-').split('.');formatted=f'{int(integer):,}.{fraction}'
                assert formatted in text.replace('\n',''), 'Canonical summary not found'
        with zipfile.ZipFile(xlsx) as archive:
            parts={n:archive.read(n) for n in archive.namelist()};allxml='\n'.join(v.decode() for n,v in parts.items() if n.endswith(('.xml','.rels')))
            for part in parts.values():no_keys(part)
            assert 'FORBIDDEN-T14-PRIVATE' not in allxml
            assert not any(n.startswith(('xl/externalLinks','xl/connections','xl/comments','xl/embeddings')) for n in parts)
            ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
            workbook=ET.fromstring(parts['xl/workbook.xml']);sheets=workbook.findall('m:sheets/m:sheet',ns)
            assert len(sheets)==1 and all(s.get('state','visible')=='visible' for s in sheets)
            sheet=ET.fromstring(parts['xl/worksheets/sheet1.xml'])
            assert not sheet.findall('.//m:f',ns) and not sheet.findall('.//m:hyperlink',ns)
            assert all(n.get('hidden','0') not in('1','true') for n in sheet.findall('.//m:row',ns)+sheet.findall('.//m:col',ns))
            assert sheet.find('m:sheetViews/m:sheetView/m:pane',ns).get('state')=='frozen'
            row_nodes=sheet.findall('m:sheetData/m:row',ns)
            def values(row):return [c.find('m:is/m:t',ns).text or '' if c.find('m:is/m:t',ns) is not None else c.find('m:v',ns).text if c.find('m:v',ns) is not None else None for c in row.findall('m:c',ns)]
            expected=[f['label']+'\n\u2067'+presentation['fields'][f['field_key']]['ur']+'\u2069' if v2 else f['label'] for f in columns];heading=next(r for r in row_nodes if values(r)==expected)
            assert expected==values(heading)
            for row in row_nodes:
                for cell in row.findall('m:c',ns):
                    value=cell.find('m:v',ns)
                    if value is not None and cell.get('s')=='3':assert Decimal(value.text).as_tuple().exponent==-2
        book=openpyxl.load_workbook(xlsx,data_only=False);ws=book.active
        assert ws.sheet_state=='visible' and ws.freeze_panes and len(book.worksheets)==1
        assert all(c.data_type!='f' for row in ws for c in row)
        if any('=HYPERLINK' in str(row.get(key,'')) for row in payload['rows'] for key in order):
            assert any(c.data_type=='s' and '=HYPERLINK' in str(c.value) for row in ws for c in row), 'Untrusted formula text was lost or interpreted'
        forbidden={'OWNER':['Customer charge','Brokerage earned','Vehicle operating profit','Customer outstanding','Intermediary-held money'],'BROKER':['Owner profit','Owner-borne costs','All vehicle costs'],'CUSTOMER':['Owner fare share','Owner profit','Owner-borne costs','Brokerage earned','All vehicle costs']}.get(payload['recipient_kind'],[])
        for label in forbidden:assert label not in text+allxml,'Forbidden financial field in contents/metadata'
        if payload['recipient_kind']=='CUSTOMER':assert 'FORBIDDEN-T14-CUSTOMER' not in text+allxml and 'FORBIDDEN-T14-CAR' not in text+allxml and 'FORBIDDEN-T14-STOP' not in text+allxml and 'FORBIDDEN-T14-NOTE' not in text+allxml
        results.append({'case':source.stem,'pdf_pages':len(reader.pages),'pdf_orientation':'landscape' if float(reader.pages[0].mediabox.width)>float(reader.pages[0].mediabox.height) else 'portrait','xlsx_sheets':len(book.worksheets),'rows':payload['row_count'],'selected_columns':len(columns),'formula_cells':0,'hidden_rows_columns_sheets':0,'forbidden_findings':0})
    assert results,'No application files inspected'
    (directory/'inspection.json').write_text(json.dumps(results),encoding='utf-8')
    print(json.dumps(results))
if __name__=='__main__':inspect(sys.argv[1])
