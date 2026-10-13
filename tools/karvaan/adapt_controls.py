"""Responsive bilingual controls plus equivalent English regression selectors."""
import re
from generate_catalogue import ROOT

(ROOT / 'app/lib/app/bilingual.dart').write_text(
    "export 'bilingual_message.dart';\nexport 'ui_catalogue.dart';\n"
    "export 'owned_presentation.dart';\nexport 'bilingual_widgets.dart';\n", encoding='utf-8')
for path in (ROOT / 'app/lib').rglob('*.dart'):
    if path.name in ('bilingual_widgets.dart', 'ui_catalogue.dart'):
        continue
    text = path.read_text(encoding='utf-8')
    if 'package:carrier_records/app/bilingual.dart' not in text:
        continue
    text = re.sub(r'\bListTile\(', 'BilingualListTile(', text)
    text = re.sub(r'(DropdownButtonFormField<[^>]+>\(\n)(?!\s*isExpanded:)',
                  r'\1isExpanded: true, itemHeight: 80,\n', text)
    text = re.sub(r'Bilingual\.data\((TripStrings\.labels\[[^]]+\])\)', r'ownedMessage(\1)', text)
    text = text.replace('Bilingual.data(label)', 'ownedMessage(label)')
    if path.name == 'carrier_records_app.dart':
        text = text.replace("import '../features/trips/trip_draft.dart';\n", '')
        text = text.replace('useMaterial3: true,', "useMaterial3: true,\nfontFamily: 'NotoSans', fontFamilyFallback: const ['NotoSansArabic'],\nappBarTheme: const AppBarTheme(toolbarHeight: 88),")
    path.write_text(text, encoding='utf-8')
for folder in ('test', 'integration_test'):
    for path in (ROOT / 'app' / folder).glob('*_test.dart'):
        text = path.read_text(encoding='utf-8')
        changed = re.sub(r'w\.decoration\??\.labelText == (label|entry\.\$1|\x27[^\x27]+\x27)',
                         r'hasEnglishLabel(w.decoration, \1)', text)
        changed = changed.replace('find.textContaining(', 'englishTextContaining(')
        if changed != text:
            relative = 'bilingual_finders.dart' if folder == 'test' else '../test/bilingual_finders.dart'
            changed = f"import '{relative}';\n" + changed
            path.write_text(changed, encoding='utf-8')
print('Adapted responsive controls and English regression selectors; data and assertions retained.')
