"""Read actual synthetic PDF/OOXML files; no authoring, data or key logging."""
import hashlib,json,sys,zipfile,subprocess
from pathlib import Path
from xml.etree import ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/.local/python_packages'))
from pypdf import PdfReader
from openpyxl import load_workbook
folder=(ROOT/sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT/'tools/.local/karvaan-documents'
if not folder.is_relative_to((ROOT/'tools/.local').resolve()) or folder.is_relative_to((ROOT/'tools/.local/candidates').resolve()) or not folder.is_dir():raise RuntimeError('Only existing ignored synthetic evidence folders allowed')
poppler=Path('C:/Users/Naeem/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/Library/bin/pdftoppm.exe')
report=[]
for path in sorted(folder.glob('*.pdf')):
 reader=PdfReader(path);text='\n'.join(p.extract_text() or '' for p in reader.pages)
 safe=str(reader.metadata)+'\n'+text
 if 'FORBIDDEN' in safe:raise RuntimeError('PDF privacy failure: '+path.name)
 fonts=set()
 for page in reader.pages:
  for ref in page['/Resources'].get('/Font',{}).values():
   font=ref.get_object();name=str(font.get('/BaseFont',''))
   for child in font.get('/DescendantFonts',[font]):
    desc=child.get_object().get('/FontDescriptor')
    if desc:
     if not any(k in desc.get_object() for k in ('/FontFile','/FontFile2','/FontFile3')):raise RuntimeError('Unembedded font')
     fonts.add(name)
 if not any('Arabic' in name for name in fonts):raise RuntimeError('Urdu font not embedded: '+path.name)
 pages={1,len(reader.pages),max(1,len(reader.pages)//2)}
 for page in sorted(pages):
  subprocess.run([str(poppler),'-f',str(page),'-l',str(page),'-scale-to','1600','-png','-singlefile',str(path),str(path.with_suffix(''))+f'-page{page}'],check=True,capture_output=True)
 report.append({'file':path.name,'bytes':path.stat().st_size,'pages':len(reader.pages),'embedded_fonts':sorted(fonts),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
for path in sorted(folder.glob('*.xlsx')):
 with zipfile.ZipFile(path) as archive:
  xml='\n'.join(archive.read(n).decode('utf-8') for n in archive.namelist() if n.endswith('.xml'))
  if 'FORBIDDEN' in xml or '<f>' in xml or 'hidden="' in xml or 'state="hidden"' in xml:raise RuntimeError('Workbook privacy/formula/hidden content failure: '+path.name)
 workbook=load_workbook(path,data_only=False)
 if len(workbook.worksheets)!=1:raise RuntimeError('Unexpected hidden/raw sheet')
 sheet=workbook.active
 if sheet.sheet_state!='visible' or any(d.hidden for d in sheet.column_dimensions.values()):raise RuntimeError('Hidden workbook content')
 if any(c.data_type=='f' for row in sheet for c in row):raise RuntimeError('Formula injection')
 if not any('مالک' in str(c.value) or 'کارواں' in str(c.value) for row in sheet for c in row):raise RuntimeError('Missing Urdu workbook text')
 report.append({'file':path.name,'bytes':path.stat().st_size,'rows':sheet.max_row,'columns':sheet.max_column,'visible_sheets':1,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
(folder/'inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
