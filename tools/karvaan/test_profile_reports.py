import unittest
from profile_reports import pct

class PercentileTests(unittest.TestCase):
    def test_fifty_samples_keep_nearest_rank_and_median(self):
        result=pct(list(reversed(range(1,51))))
        self.assertEqual(result,{'n':50,'p50_ms':25.5,'p95_ms':48,'max_ms':50})
    def test_slow_samples_are_not_discarded(self):
        result=pct([100]*45+[7000]*5)
        self.assertEqual(result['n'],50)
        self.assertEqual(result['p95_ms'],7000)

if __name__=='__main__':unittest.main()
