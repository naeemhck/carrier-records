"""Apply syntax-inventoried presentation edits, never global text replacement.

Only catalogue-owned literals/symbols are eligible. Remaining dynamic nodes
are written to a review ledger so user records are not silently translated.
"""
import json
from pathlib import Path
from generate_catalogue import ROOT, dart_identifier
from presentation_ownership import owned_expression


def apply_indexed(source, edits):
    # Dart AST positions are UTF-16 code units; Python indices are Unicode
    # scalar values. Byte-index UTF-16 so CRLF and supplementary glyphs both
    # retain exact positions. Refuse overlapping or out-of-range edits.
    original = source.encode('utf-16-le')
    previous = len(original) // 2
    for start, end, replacement in sorted(edits, reverse=True):
        if not 0 <= start <= end <= previous:
            raise ValueError('Invalid or overlapping syntax edits.')
        original = original[:start * 2] + replacement.encode('utf-16-le') + original[end * 2:]
        previous = start
    return original.decode('utf-16-le')


def main():
    inventory = json.loads((ROOT / 'tools/.local/karvaan-ast-inventory.json').read_text(encoding='utf-8'))
    entries = json.loads((ROOT / 'tools/karvaan/phrases.json').read_text(encoding='utf-8'))
    by_text = {item['en']: item for item in entries}
    symbols = {origin: item for item in entries for origin in item['origins']
               if 'Strings.' in origin and '[' not in origin}
    edits, pending, changed = {}, [], []
    def typed(node):
        kind = node['kind']
        if kind == 'message':
            entry = by_text.get(node['en'])
            if entry is None:
                return None
            value = 'L10n.' + dart_identifier(entry['key'])
            if node['args']:
                value += '.withValues([' + ','.join(
                    'ownedMessage(' + arg + ')' if owned_expression(arg) else arg
                    for arg in node['args']) + '])'
            return value
        if kind == 'conditional':
            yes, no = typed(node['yes']), typed(node['no'])
            if yes and no:
                return '(' + node['condition'] + ' ? ' + yes + ' : ' + no + ')'
        if kind == 'fallback':
            fallback = typed(node['fallback'])
            if fallback:
                return '(' + node['value'] + ' != null ? Bilingual.data(' + node['value'] + ') : ' + fallback + ')'
        if kind == 'expression':
            entry = symbols.get(node['source'])
            if entry:
                return 'L10n.' + dart_identifier(entry['key'])
            if owned_expression(node['source']):
                return 'ownedMessage(' + node['source'] + ')'
            return 'Bilingual.data(' + node['source'] + ')'
        return None
    for node in inventory['surfaces']:
        file = node['file']
        if file.endswith(('/bilingual.dart', '/bilingual_message.dart', '/ui_catalogue.dart')):
            continue
        message = node.get('message')
        entry = by_text.get(message['en']) if message else symbols.get(node['source'])
        value = typed(node['presentation'])
        if entry is None and node['presentation']['kind'] == 'expression' and owned_expression(node['source'], file):
            changes = edits.setdefault(file, [])
            if node.get('surface') in ('labelText', 'hintText', 'errorText', 'helperText'):
                changes.append((node['offset'], node['end'], node['surface'][:-4] + ': BilingualOwnedCaption(' + node['source'] + ')'))
            elif node.get('surface') is None:
                changes.append((node['constructor_offset'], node['constructor_offset'] + 4, 'BilingualOwnedText'))
            else:
                pending.append(node)
                continue
            changed.append({'file': file, 'line': node['line'], 'key': 'owned.dynamic', 'surface': node.get('surface', 'Text')})
            continue
        if entry is None and node['presentation']['kind'] in ('message', 'expression'):
            pending.append(node)
            continue
        if value is None:
            pending.append(node)
            continue
        args = message['args'] if message else []
        surface = node.get('surface')
        changes = edits.setdefault(file, [])
        if surface is None:
            changes.extend([(node['constructor_offset'], node['constructor_offset'] + 4, 'BilingualText'),
                            (node['arg_offset'], node['arg_end'], value)])
        elif surface in ('labelText', 'hintText', 'errorText', 'helperText'):
            changes.append((node['offset'], node['end'], surface[:-4] + ': BilingualCaption(' + value + ')'))
        elif surface in ('tooltip', 'semanticsLabel'):
            # Static accessibility strings remain usable in const widget trees.
            changes.append((node['arg_offset'], node['arg_end'],
                            value + '.inline' if args else 'L10n.' + dart_identifier(entry['key']) + 'Accessibility'))
        else:
            pending.append(node)
            continue
        changed.append({'file': file, 'line': node['line'], 'key': entry['semantic_key'] if entry else 'classified.branch', 'surface': surface or 'Text'})
    for file, changes in edits.items():
        path = ROOT / file
        # Analyzer offsets refer to the exact CRLF/LF source, not normalized
        # universal-newline text. Preserve bytes throughout indexed edits.
        with path.open(encoding='utf-8', newline='') as handle:
            text = handle.read()
        text = apply_indexed(text, changes)
        if "import 'package:carrier_records/app/bilingual.dart';" not in text:
            text = "import 'package:carrier_records/app/bilingual.dart';\n" + text
        with path.open('w', encoding='utf-8', newline='') as handle:
            handle.write(text)
    (ROOT / 'tools/.local/karvaan-ui-pending.json').write_text(json.dumps(pending, ensure_ascii=False, indent=2), encoding='utf-8')
    ledger = ROOT / 'tools/karvaan/ui-coverage.json'
    previous = json.loads(ledger.read_text(encoding='utf-8')) if ledger.exists() else []
    ledger.write_text(json.dumps(previous + changed, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Integrated {len(changed)} owned surfaces; {len(pending)} dynamic/data nodes require classification.')


if __name__ == '__main__':
    main()
