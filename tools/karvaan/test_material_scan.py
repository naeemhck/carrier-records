import unittest
from material_scan import has_private_key_material

class PrivateMaterialTests(unittest.TestCase):
    def test_parser_literals_are_not_key_material(self):
        self.assertFalse(has_private_key_material(b'-----BEGIN '+b'PRIVATE KEY'+b'-----\x00parser data\x00-----END '+b'PRIVATE KEY'+b'-----'))

    def test_complete_private_bodies_are_denied(self):
        for kind in ['PRIVATE KEY','RSA PRIVATE KEY','EC PRIVATE KEY','OPENSSH PRIVATE KEY','ENCRYPTED PRIVATE KEY']:
            with self.subTest(kind=kind):
                data=('-----BEGIN '+kind+'-----\n').encode()+b'A'*128+('\n-----END '+kind+'-----').encode()
                self.assertTrue(has_private_key_material(data))

    def test_legacy_encrypted_body_is_denied(self):
        data=b'-----BEGIN '+b'RSA PRIVATE KEY'+b'-----\nProc-Type: 4,ENCRYPTED\nDEK-Info: AES-256-CBC,synthetic\n\n'+b'A'*128+b'\n-----END '+b'RSA PRIVATE KEY'+b'-----'
        self.assertTrue(has_private_key_material(data))

if __name__=='__main__':unittest.main()
