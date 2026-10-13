"""Apply reviewed source translations with exact placeholder/digit validation."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def main():
    phrases=ROOT/'tools/karvaan/phrases.json'
    entries=json.loads(phrases.read_text(encoding='utf-8'))
    translations=json.loads((ROOT/'tools/karvaan/translations.json').read_text(encoding='utf-8'))
    keys={entry['key'] for entry in entries}
    unknown=set(translations)-keys
    if unknown:raise RuntimeError(f'Unknown translation keys: {sorted(unknown)}')
    for entry in entries:
        if entry['key'] in translations:entry['ur']=translations[entry['key']]
        if entry['ur'] is None:continue
        if sorted(re.findall(r'\{[0-9]+\}',entry['en']))!=sorted(re.findall(r'\{[0-9]+\}',entry['ur'])):
            raise RuntimeError('Placeholder mismatch: '+entry['key'])
        if re.search('[۰-۹٠-٩]',entry['ur']):raise RuntimeError('Non-Latin digits: '+entry['key'])
    phrases.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Translated {sum(x["ur"] is not None for x in entries)}/{len(entries)} owned messages.')
if __name__=='__main__':main()
