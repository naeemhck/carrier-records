"""Independent inspection of actual Dart-generated XLSX import templates."""
import json,sys,zipfile
from pathlib import Path
import openpyxl

folder=Path(sys.argv[1]);fields=json.loads((Path(__file__).resolve().parents[1]/'import_fields.json').read_text())
for name in ['template.xlsx','input.xlsx']:
    p=folder/name
    w=openpyxl.load_workbook(p,data_only=False)
    assert set(w.sheetnames)==set(fields)
    for s in w:
        assert s.sheet_state=='visible' and s['A1'].value=='Carrier Records import v1'
        assert [s.cell(2,c+1).value for c in range(len(fields[s.title]))]==fields[s.title]
        assert not any(c.data_type=='f' for row in s for c in row)
        assert not any(d.hidden for d in s.column_dimensions.values())
        assert not any(d.hidden for d in s.row_dimensions.values())
        assert all(c.number_format=='@' for row in s.iter_rows(min_row=3) for c in row)
    if name=='input.xlsx':
        assert w['TRIP_DRAFT']['A3'].value=='native-trip'
        assert w['TRIP_DRAFT']['H3'].value=='2026-10-15'
    with zipfile.ZipFile(p) as z:
        assert not any('vba' in n.lower() or 'externalLinks' in n for n in z.namelist())
    print('PASS actual '+name+' version headers text dates/money and no formulas/hidden content')
