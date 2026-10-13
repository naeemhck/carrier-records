import unittest
from integrate_ui import apply_indexed


class SyntaxEdits(unittest.TestCase):
    def test_exact_dart_offsets_for_lf_crlf_and_supplementary_characters(self):
        for newline in ('\n', '\r\n'):
            source = '// synthetic 😀' + newline + "const Text('Save');" + newline
            start = len(source[:source.index('Text')].encode('utf-16-le')) // 2
            result = apply_indexed(source, [(start, start + 4, 'BilingualText')])
            self.assertEqual(result, source.replace("Text('Save')", "BilingualText('Save')"))
            self.assertTrue(result.endswith(newline))

    def test_rejects_overlap_and_out_of_range(self):
        for edits in ([(1, 4, 'x'), (2, 3, 'y')], [(0, 20, 'x')], [(-1, 0, 'x')]):
            with self.assertRaises(ValueError):
                apply_indexed('12345', edits)


if __name__ == '__main__':
    unittest.main()
