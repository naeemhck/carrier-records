"""Append newly classified owned branches without renumbering existing keys."""
import hashlib
import json
import re
from pathlib import Path
from generate_catalogue import ROOT
from prepare_catalogue import slug


def branches(node):
    if node['kind'] == 'message':
        yield node
    elif node['kind'] == 'conditional':
        yield from branches(node['yes'])
        yield from branches(node['no'])
    elif node['kind'] == 'fallback':
        yield from branches(node['fallback'])
    elif node['kind'] == 'alternatives':
        for option in node['options']:
            yield from branches(option)


def main():
    path = ROOT / 'tools/karvaan/phrases.json'
    entries = json.loads(path.read_text(encoding='utf-8'))
    texts = {item['en'] for item in entries}
    keys = {item['key'] for item in entries}
    inventory = json.loads((ROOT / 'tools/.local/karvaan-ast-inventory.json').read_text(encoding='utf-8'))
    candidates = [(item, item.get('symbol', 'owned')) for item in inventory['known']]
    # Static server catalogue labels, not database rows or customer data.
    server_source = (ROOT / 'supabase/migrations/20261011001400_outputs.sql').read_text(encoding='utf-8')
    for key, label, group in re.findall(r"\('([a-z_]+)','([^']+)','([^']+)','(?:TEXT|MONEY|DATE|INTEGER|BOOLEAN)'", server_source):
        candidates.append(({'en': label}, 'server.field.' + key))
        candidates.append(({'en': group}, 'server.group.' + group))
    codes = 'ADMIN STAFF OWNER BROKER CUSTOMER DRIVER INTERNAL DRAFT DISPATCHED ARRIVED DELIVERED CANCELLED LOADED EMPTY TOTAL PER_CAR NONE FIXED PERCENT PICKUP DROP AUTO PORTRAIT LANDSCAPE ALL_OFFICES ASSIGNED_OFFICES IN_TRANSIT PARTIALLY_DELIVERED'.split()
    candidates.extend(({'en': code}, 'system.code.' + code) for code in codes)
    extra = ROOT / 'tools/karvaan/extra_phrases.json'
    if extra.exists():
        for key, english, urdu in json.loads(extra.read_text(encoding='utf-8')):
            if english in texts:
                continue
            if key in keys:
                raise ValueError('Extra phrase symbol collision: ' + key)
            entries.append({'key': key, 'semantic_key': 'presentation.' + key,
                            'en': english, 'ur': urdu, 'origins': ['reviewed.dynamic.presentation']})
            keys.add(key)
            texts.add(english)
    for surface in inventory['surfaces']:
        candidates.extend((item, surface['file'] + ':' + str(surface['line']))
                          for item in branches(surface['presentation']))
    added = []
    for item, origin in candidates:
        english = item['en']
        words = re.findall('[A-Za-z]+', re.sub(r'\{[0-9]+\}', '', english))
        if english in texts or not any(word not in ('PKR', 'UTC') for word in words):
            continue
        key = slug(english)
        if key in keys:
            key += hashlib.sha256(english.encode()).hexdigest()[:6]
        entries.append({'key': key, 'semantic_key': 'ui.' + key, 'en': english,
                        'ur': None, 'origins': [origin]})
        keys.add(key)
        texts.add(english)
        added.append(key + ' | ' + english)
    path.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('\n'.join(added))
    print(f'Appended {len(added)} classified branch/error phrases; previous keys preserved.')


if __name__ == '__main__':
    main()
