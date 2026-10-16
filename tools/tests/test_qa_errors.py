import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'karvaan'))
from qa_seed import safe_error_code
class ErrorCodeTest(unittest.TestCase):
 def test_auth_numeric_status_does_not_hide_semantic_code(self):
  self.assertEqual(safe_error_code({'code':422,'error_code':'signup_disabled'}),'signup_disabled')
 def test_postgres_permission_code_retained(self):
  self.assertEqual(safe_error_code({'code':'42501'}),'42501')
 def test_invalid_or_absent_payload(self):
  for value in [None,[],{},'invalid']:self.assertEqual(safe_error_code(value),'unknown')
if __name__=='__main__':unittest.main()
