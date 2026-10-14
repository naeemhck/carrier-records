"""Independent inspection regression against actual local synthetic exports."""
import copy,json,shutil,sys,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/.local/python_packages'))
sys.path.insert(0,str(ROOT/'tools/tests'))
from t14_file_inspection import inspect
from local_environment import boundary

class NativeInspectionTests(unittest.TestCase):
    def setUp(self):
        boundary()
        self.root=ROOT/'tools/.local/t14-native-files'
        self.source=next(p for p in self.root.glob('*.json') if p.with_suffix('.pdf').exists() and len([f for f in json.loads(p.read_text(encoding='utf-8'))['fields'] if not f['header']])>1)

    def altered(self,update,expected):
        with tempfile.TemporaryDirectory(dir=ROOT/'tools/.local') as temporary:
            folder=Path(temporary)
            for suffix in ['.json','.pdf','.xlsx']:
                shutil.copy2(self.source.with_suffix(suffix),folder/(self.source.stem+suffix))
            payload=json.loads((folder/self.source.name).read_text(encoding='utf-8'))
            update(payload)
            (folder/self.source.name).write_text(json.dumps(payload),encoding='utf-8')
            with self.assertRaisesRegex(AssertionError,expected):inspect(folder)

    def test_actual_eight_native_exports(self):
        inspect(self.root)
        self.assertEqual(len(json.loads((self.root/'inspection.json').read_text())),8)

    def test_changed_order_is_rejected(self):
        def reorder(payload):
            keys=[f['field_key'] for f in payload['fields'] if not f['header']]
            a,b=map(payload['field_order'].index,keys[:2])
            payload['field_order'][a],payload['field_order'][b]=payload['field_order'][b],payload['field_order'][a]
        self.altered(reorder,'PDF selected order changed')

    def test_changed_scope_is_rejected(self):
        self.altered(lambda p:p['metadata'].update(scope='UNAUTHORIZED COMPLETE GLOBAL BALANCE'),'Authoritative scope missing')

if __name__=='__main__':unittest.main()
