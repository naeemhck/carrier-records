"""Audit artifact contents independently of the containing local review folder."""
import tempfile
import unittest
from pathlib import Path
from web_artifact_audit import audit


class WebArtifactAuditTests(unittest.TestCase):
    def test_ignored_parent_is_not_packaged_but_nested_private_files_are(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / '.local' / 'candidate'
            root.mkdir(parents=True)
            for name in ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js']:
                (root / name).write_text('public candidate', encoding='utf-8')
            (root / '_redirects').write_bytes(b'/* /index.html 200\n')
            self.assertTrue(audit(root)['passed'])
            (root / '.local').mkdir()
            (root / '.local' / 'private.json').write_text('{}')
            self.assertIn(('.local/private.json', 'private/artifact filename'), audit(root)['findings'])

    def test_privileged_key_is_rejected_without_reporting_its_value(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js']:
                (root / name).write_text('public candidate', encoding='utf-8')
            (root / '_redirects').write_bytes(b'/* /index.html 200\n')
            secret = 'sb_secret_' + 'x' * 32
            (root / 'main.dart.js').write_text(secret)
            result = audit(root)
            self.assertFalse(result['passed'])
            self.assertNotIn(secret, str(result))


if __name__ == '__main__':
    unittest.main()
