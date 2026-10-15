import unittest,io,json,urllib.error
from unittest.mock import patch
from profile_reports import error_evidence,http_request
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


class FailureEvidenceTests(unittest.TestCase):
 def test_actual_timeout_retains_safe_code_and_timings(self):
  payload=json.dumps({'code':'57014','message':'canceling statement due to statement timeout','details':'sensitive payload must not enter evidence'}).encode()
  error=urllib.error.HTTPError('http://127.0.0.1:60321/rest/v1/rpc/get_scoped_report',500,'error',{},io.BytesIO(payload))
  with patch('profile_reports.urllib.request.urlopen',side_effect=error):value,timing=http_request('/rest/v1/rpc/get_scoped_report',{},'synthetic-public','synthetic-session')
  self.assertEqual(value['code'],'57014');self.assertEqual(timing['http_status'],500);self.assertEqual(timing['error']['code'],'57014');self.assertNotIn('sensitive',json.dumps(timing));self.assertGreaterEqual(timing['total_ms'],0)
 def test_transport_failure_is_a_retained_sample(self):
  with patch('profile_reports.urllib.request.urlopen',side_effect=TimeoutError('private transport details')):value,timing=http_request('/rest/v1/rpc/get_scoped_report',{},'synthetic-public')
  self.assertEqual(timing['http_status'],0);self.assertEqual(timing['error']['code'],'TRANSPORT_ERROR');self.assertNotIn('private',json.dumps(timing));self.assertIn('total_ms',timing)
 def test_untrusted_error_details_never_copied(self):
  self.assertEqual(error_evidence({'code':'secret token contains spaces','message':'private payload'})['code'],'UNKNOWN')
  self.assertNotIn('private',json.dumps(error_evidence({'code':'42501','details':'private'})))
  self.assertEqual(error_evidence({'code':'syntheticPassword123'})['code'],'UNKNOWN')

 def test_malformed_http200_is_an_error_not_a_success(self):
  class Response(io.BytesIO):
   status=200
   headers={}
  with patch('profile_reports.urllib.request.urlopen',return_value=Response(b'not-json')):value,timing=http_request('/rest/v1/rpc/get_scoped_report',{},'synthetic-public')
  self.assertEqual(timing['http_status'],200);self.assertEqual(timing['error']['code'],'INVALID_JSON');self.assertIn('http_error',value)
