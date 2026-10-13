"""Audit every drafted Urdu character against bundled fonts; no downloads."""
import json
import sys
import unicodedata
from generate_catalogue import ROOT

sys.path.insert(0, str(ROOT / 'tools/.local/python_packages'))
from fontTools.ttLib import TTFont

entries = json.loads((ROOT / 'tools/karvaan/phrases.json').read_text(encoding='utf-8'))
characters = {ord(char) for entry in entries for char in entry['ur']
              if not char.isspace() and unicodedata.category(char) != 'Cf'}
for weight in ('Regular', 'Bold'):
    arabic = TTFont(ROOT / f'app/assets/fonts/NotoSansArabic-{weight}.ttf')
    latin = TTFont(ROOT / f'app/assets/fonts/NotoSans-{weight}.ttf')
    symbols = TTFont(ROOT / 'app/assets/fonts/NotoSansMath-Regular.ttf')
    coverage = set(arabic.getBestCmap()) | set(latin.getBestCmap()) | set(symbols.getBestCmap())
    missing = characters - coverage
    if missing:
        raise RuntimeError(f'Missing {weight} glyphs: {sorted(missing)}')
    joining = {record.FeatureTag for record in arabic['GSUB'].table.FeatureList.FeatureRecord}
    if not {'init', 'medi', 'fina', 'rlig'}.issubset(joining):
        raise RuntimeError('Bundled Arabic joining features incomplete.')
    print(f'PASS {weight}: {len(characters)} catalogue glyphs covered; init/medi/fina/rlig joining features present.')
