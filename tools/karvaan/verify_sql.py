"""Run existing pgTAP files on the pinned isolated container; never reset data."""
import json
import re
from pathlib import Path
from local_environment import ROOT, boundary, validate_defines, sql, require


def assertions(result):
    require(not re.search(r'^not ok\b|^Bail out!', result, re.M), 'SQL assertion failed.')
    count = len(re.findall(r'^ok\s+\d+', result, re.M))
    plans = re.findall(r'^1\.\.(\d+)\s*$', result, re.M)
    require(count > 0 and len(plans) == 1 and int(plans[0]) == count,
            'SQL assertion count does not match its plan.')
    return count


def transaction(source):
    require(source.lower().count('begin;') == 1 and source.lower().rstrip().endswith('rollback;'),
            'Only complete rollback-only test transactions are accepted.')
    # Some existing files expect the harness to supply pgTAP. Bootstrap inside
    # the same transaction so neither the extension nor fixture data persists.
    if 'create extension if not exists pgtap' not in source.lower():
        source = source.replace('begin;', 'begin;\ncreate extension if not exists pgtap with schema extensions;\nset local search_path=public,extensions;', 1)
    return source


def main():
    boundary()
    validate_defines(json.loads((ROOT/'tools/.local/karvaan-test-defines.json').read_text(encoding='utf-8')))
    total = 0
    files = sorted((ROOT/'supabase/tests/database').glob('*.sql'))
    with (ROOT/'tools/.local/karvaan-sql-assertions.log').open('w', encoding='utf-8') as log:
        for path in files:
            result = sql(transaction(path.read_text(encoding='utf-8')))
            log.write(path.name+'\n'+result+'\n'); log.flush()
            count = assertions(result); total += count
            print(f'PASS {path.name}: {count} assertions, rolled back', flush=True)
    print(f'PASS {total} assertions across {len(files)} files; no reset or persistent test change.', flush=True)


if __name__ == '__main__':
    main()
