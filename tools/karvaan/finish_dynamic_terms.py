"""Append controlled report/date-basis terminology; preserve existing entries."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tools/karvaan/extra_phrases.json';extra=json.loads(path.read_text(encoding='utf-8'))
known={x['en']:x['ur'] for x in json.loads((ROOT/'tools/karvaan/phrases.json').read_text(encoding='utf-8'))}
add=[('earningsBasisKey','earnings','آمدنی'),('expensesBasisKey','expenses','اخراجات'),('paymentsBasisKey','payments','ادائیگیاں'),('receiptsBasisKey','receipts','وصولیاں'),('claimsBasisKey','claims','واجب الادا رقوم'),
 ('dispatchAdjustmentBasis','Dispatch / explicit adjustment date','روانگی یا واضح ترمیم کی تاریخ'),('paymentDateBasis','Payment date','ادائیگی کی تاریخ'),('expenseDateBasis','Expense date','خرچ کی تاریخ'),
 ('currentLifetimeBasis','Current lifetime','موجودہ مکمل مدت'),('periodEndBasis','Period end','مدت کا اختتام'),('currentLifetimeBalanceBasis','Current lifetime balance','موجودہ مکمل مدت کا بیلنس'),('asOfPeriodEndBasis','As of period end','مدت کے اختتام تک'),
 ('completeBusinessRecordsScope','Complete business records','کاروبار کے مکمل ریکارڈز'),('assignedOfficeRecordsScope','Assigned-office records — not a complete business balance','مقررہ دفتر کے ریکارڈز — کاروبار کا مکمل بیلنس نہیں'),('selectedOfficeRecordsScope','Selected-office records — not a complete business balance','منتخب دفتر کے ریکارڈز — کاروبار کا مکمل بیلنس نہیں')]
source=(ROOT/'app/lib/features/reports/report_repository.dart').read_text(encoding='utf-8')
for i,en in enumerate(re.findall(r"'[^']+': '([^']+)'",source)):
 changed=en.replace('period end','current lifetime').replace('period costs','all linked costs').replace('expense date','all linked expense dates')
 if changed!=en and en in known:
  ur=known[en].replace('مدت کے اختتام','موجودہ مکمل مدت').replace('مدت کی لاگت','تمام منسلک لاگت').replace('خرچ کی تاریخ','تمام منسلک اخراجات کی تاریخیں')
  add.append(('lifetimeReportLabel'+str(i),changed,ur))
keys={x[0] for x in extra};english={x[1] for x in extra}|set(known)
for key,en,ur in add:
 if key not in keys and en not in english:extra.append([key,en,ur]);keys.add(key);english.add(en)
path.write_text(json.dumps(extra,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Appended controlled provisional dynamic terms; original catalogue untouched.')
