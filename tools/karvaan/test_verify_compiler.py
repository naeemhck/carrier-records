import tempfile,unittest
from pathlib import Path
from verify_compiler import verify_compiler

class CompilerSignatureTests(unittest.TestCase):
    def test_existing_signed_compiler(self):
        verify_compiler('D:/portfolio/transport_project/tools/.local/inno/compiler/ISCC.exe')

    def test_missing_and_unsigned_are_denied(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'unsigned.exe'
            with self.assertRaisesRegex(RuntimeError,'absent'):verify_compiler(path)
            path.write_bytes(b'not an executable or a signature')
            with self.assertRaisesRegex(RuntimeError,'signature verification failed'):verify_compiler(path)

if __name__=='__main__':unittest.main()
