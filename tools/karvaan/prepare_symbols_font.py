import hashlib
import json
import urllib.request
from generate_catalogue import ROOT

base = 'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansmath/'
assets = ROOT / 'app/assets/fonts'
for remote, local in [('NotoSansMath-Regular.ttf', 'NotoSansMath-Regular.ttf'),
                      ('OFL.txt', 'NotoSansMath-OFL.txt')]:
    with urllib.request.urlopen(base + remote, timeout=60) as response:
        content = response.read()
    (assets / local).write_bytes(content)
font = assets / 'NotoSansMath-Regular.ttf'
provenance = {'source': base, 'license': 'SIL OFL 1.1',
              'bytes': font.stat().st_size,
              'sha256': hashlib.sha256(font.read_bytes()).hexdigest()}
(assets / 'NotoSansMath-provenance.json').write_text(
    json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
print(json.dumps(provenance))
