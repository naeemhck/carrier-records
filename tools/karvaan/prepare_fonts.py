"""Download Google's OFL font and make static default-width 400/700 instances."""
import hashlib,json,sys,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/.local/python_packages'))
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

def main():
    base='https://raw.githubusercontent.com/google/fonts/main/ofl/notosansarabic/'
    local=ROOT/'tools/.local';assets=ROOT/'app/assets/fonts'
    local.mkdir(parents=True,exist_ok=True)
    source=local/'NotoSansArabic-variable.ttf'
    with urllib.request.urlopen(base+'NotoSansArabic%5Bwdth,wght%5D.ttf',timeout=90) as response:source.write_bytes(response.read())
    with urllib.request.urlopen(base+'OFL.txt',timeout=30) as response:(assets/'NotoSansArabic-OFL.txt').write_bytes(response.read())
    results=[]
    for name,weight in [('Regular',400),('Bold',700)]:
        font=instantiateVariableFont(TTFont(source),{'wght':weight,'wdth':100},inplace=False)
        path=assets/f'NotoSansArabic-{name}.ttf';font.save(path)
        cmap=font.getBestCmap()
        sample='کارواں کنسائنمنٹ تحویل رقم زیرِ تحویل اخراجات کا ذمہ دار تصفیہ کمیشن گاڑی PKR 125,000.00'
        missing=sorted(set(ord(c) for c in sample if not c.isspace())-set(cmap))
        assert not missing,f'Urdu prototype glyphs absent: {missing}'
        results.append({'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    provenance={'source':base,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'license':'SIL OFL 1.1','tool':'fontTools 4.66.1 static instancer','fonts':results}
    (assets/'NotoSansArabic-provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(provenance))
if __name__=='__main__':main()
