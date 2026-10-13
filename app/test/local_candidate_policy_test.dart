import 'package:flutter_test/flutter_test.dart';
import 'package:carrier_records/features/auth/local_candidate_policy.dart';
import 'package:carrier_records/features/auth/public_config.dart';

void main() {
  PublicConfig config(String url,{String environment='test'}) => PublicConfig(environment:environment,url:url,key:'sb_publishable_synthetic_key_only',businessId:'00000000-0000-0000-0000-000000000001');
  test('candidate defaults local-only and rejects hosted/other local environments',() {
    expect(karvaanLocalOnly,isTrue);
    LocalCandidatePolicy.validate(config('http://127.0.0.1:60321'));
    LocalCandidatePolicy.validate(config('http://10.0.2.2:60321'));
    for(final url in ['https://example.supabase.co','http://127.0.0.1:54321','http://localhost:60321','http://127.0.0.1:60321/rest/v1','https://127.0.0.1:60321','http://127.0.0.1:60321?project=test']) {
      expect(()=>LocalCandidatePolicy.validate(config(url)),throwsFormatException);
    }
    expect(()=>LocalCandidatePolicy.validate(config('http://127.0.0.1:60321',environment:'production')),throwsFormatException);
  });
  test('local identity must match all fields before session access',() {
    final identity={'project_id':LocalCandidatePolicy.project,'api_port':60321,'purpose':'synthetic-only'};
    LocalCandidatePolicy.validateIdentity(identity);
    for(final invalid in [null,{}, {...identity,'project_id':'transport_project'}, {...identity,'api_port':54321}, {...identity,'purpose':'production'}, {...identity,'extra':true}]) {
      expect(()=>LocalCandidatePolicy.validateIdentity(invalid),throwsFormatException);
    }
    expect(LocalCandidatePolicy.sessionPrefix,isNot('carrier.session'));
  });
}
