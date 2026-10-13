"""Inventory presentation surfaces, including non-Text labels and safe errors."""
import json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def string_token(source,start):
    quote=source[start];triple=source.startswith(quote*3,start)
    ender=quote*(3 if triple else 1);i=start+len(ender)
    while i<len(source):
        if source[i]=='\\':i+=2;continue
        if source.startswith('${',i):
            i=balanced(source,i+1)+1;continue
        if source.startswith(ender,i):return i+len(ender)
        i+=1
    raise ValueError('Unclosed Dart string')

def balanced(source,start):
    closing={'(':')','[':']','{':'}'};stack=[closing[source[start]]];i=start+1
    while stack:
        c=source[i]
        if c in "\"'":i=string_token(source,i);continue
        if c in closing:stack.append(closing[c])
        elif c==stack[-1]:stack.pop()
        i+=1
    return i-1

def inventory():
    rows=[]
    surface=re.compile(r'\b(Text|TextSpan|InputDecoration|Tooltip|SnackBar|AppBar|DataColumn|DropdownMenuItem)\s*\(|\b(labelText|hintText|errorText|helperText|tooltip|semanticsLabel)\s*:|\b(FormatException|StateError)\s*\(')
    for path in sorted((ROOT/'app/lib').rglob('*.dart')):
        code=path.read_text(encoding='utf-8')
        for match in surface.finditer(code):
            start=match.end();snippet=code[start:start+260].strip()
            rows.append({'file':str(path.relative_to(ROOT)).replace('\\','/'),'line':code.count('\n',0,match.start())+1,'surface':next(x for x in match.groups() if x),'source':snippet})
    target=ROOT/'tools/.local/karvaan-ui-inventory.json';target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return rows

def text_literals():
    """First Text argument and decoration strings; interpolations remain opaque."""
    result={}
    for path in sorted((ROOT/'app/lib').rglob('*.dart')):
        if path.name in ('output_pdf.dart','output_xlsx.dart'):continue
        code=path.read_text(encoding='utf-8')
        for m in re.finditer(r'\bText\s*\(|\b(?:labelText|hintText|errorText|helperText|tooltip)\s*:',code):
            i=m.end()
            while i<len(code) and code[i].isspace():i+=1
            if code[i] not in "\"'":continue
            end=string_token(code,i);text=code[i+1:end-1]
            result.setdefault(text,[]).append({'file':str(path.relative_to(ROOT)).replace('\\','/'),'line':code.count('\n',0,i)+1})
    target=ROOT/'tools/.local/karvaan-literal-inventory.json'
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    return result

if __name__=='__main__':
    rows=inventory();counts={}
    for row in rows:counts[row['surface']]=counts.get(row['surface'],0)+1
    print(json.dumps({'surfaces':len(rows),'by_surface':counts,'files':len(set(row['file'] for row in rows))}))
    print('Direct literal messages:',len(text_literals()))
