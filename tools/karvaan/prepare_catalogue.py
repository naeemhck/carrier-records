"""Prepare stable source-owned message keys; never translates user records."""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def slug(text):
    words=re.findall(r'[A-Za-z][A-Za-z0-9]*',text)
    short=words[:9]
    return (short[0].lower()+''.join(w[0].upper()+w[1:] for w in short[1:])) if short else 'labelValues'

def main():
    data=json.loads((ROOT/'tools/.local/karvaan-ast-inventory.json').read_text(encoding='utf-8'))
    candidates={}
    for item in data['known']:
        candidates.setdefault(item['en'],[]).append(item.get('symbol','owned'))
    for item in data['surfaces']:
        message=item.get('message')
        if message is None:continue
        # A record, name, identifier, date or money-only cell remains plain data.
        words=re.findall(r'[A-Za-z]+',re.sub(r'\{[0-9]+\}','',message['en']))
        owned=any('Strings.' in value or 'Label(' in value or "['state']" in value or "['role']" in value for value in message['args'])
        if not any(w not in ('PKR','UTC') for w in words) and not owned:continue
        candidates.setdefault(message['en'],[]).append(item['file']+':'+str(item['line']))
    existing={}
    text=(ROOT/'app/lib/app/bilingual.dart').read_text(encoding='utf-8')
    for name,key,en,ur in re.findall(r"static const (\w+)=Bilingual\('([^']*)','([^']*)','([^']*)'\);",text):
        existing[en]={'key':name,'semantic_key':key,'ur':ur}
        candidates.setdefault(en,[]).append('foundation')
    keys=set();entries=[]
    for en,origins in candidates.items():
        entry=existing.get(en,{})
        key=entry.get('key',slug(en))
        if key in keys:key+=hashlib.sha256(en.encode()).hexdigest()[:6]
        keys.add(key)
        entries.append({'key':key,'semantic_key':entry.get('semantic_key','ui.'+key),'en':en,'ur':entry.get('ur'),'origins':origins})
    path=ROOT/'tools/karvaan/phrases.json'
    if path.exists():raise RuntimeError('Existing stable catalogue must be preserved, not regenerated.')
    path.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Prepared {len(entries)} stable owned messages; {sum(x["ur"] is None for x in entries)} translations pending.')
if __name__=='__main__':main()
