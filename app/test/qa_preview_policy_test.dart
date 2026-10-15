import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carrier_records/features/auth/qa_preview_policy.dart';
import 'package:carrier_records/features/auth/local_candidate_policy.dart';
import 'package:carrier_records/features/auth/public_config.dart';
import 'package:carrier_records/app/qa_preview_frame.dart';

void main() {
  PublicConfig config(
    String url, {
    String environment = 'test',
    String business = QaPreviewPolicy.businessId,
    String key = 'sb_publishable_synthetic_key_only',
  }) => PublicConfig(
    environment: environment,
    url: url,
    key: key,
    businessId: business,
  );
  test(
    'QA explicitly pins TEST project and business, preserves local guard',
    () {
      expect(karvaanQaPreview, isFalse);
      QaPreviewPolicy.validate(config(QaPreviewPolicy.api));
      for (final url in [
        'https://tuasxnfwrepbcelnrlgb.supabase.co',
        'https://zuoaxtjfylfuwsxfbgzl.supabase.co',
        'https://example.supabase.co',
        'http://127.0.0.1:60321',
        'http://nxyjjjxvgibehovlyycx.supabase.co',
        '${QaPreviewPolicy.api}/rest/v1',
        '${QaPreviewPolicy.api}?redirect=production',
        '${QaPreviewPolicy.api}.attacker.invalid',
      ]) {
        expect(
          () => QaPreviewPolicy.validate(config(url)),
          throwsFormatException,
        );
      }
      expect(
        () => QaPreviewPolicy.validate(
          config(QaPreviewPolicy.api, environment: 'production'),
        ),
        throwsFormatException,
      );
      expect(
        () => QaPreviewPolicy.validate(
          config(
            QaPreviewPolicy.api,
            business: '00000000-0000-0000-0000-000000000001',
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => QaPreviewPolicy.validate(
          config(
            QaPreviewPolicy.api,
            key: ['sb', 'secret', 'synthetic', 'forbidden', 'key'].join('_'),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => LocalCandidatePolicy.validate(config(QaPreviewPolicy.api)),
        throwsFormatException,
      );
      expect(
        QaPreviewPolicy.sessionPrefix,
        isNot(LocalCandidatePolicy.sessionPrefix),
      );
      expect(QaPreviewPolicy.sessionPrefix, isNot('carrier.session'));
    },
  );
  test('QA identity requires all exact fields without extra claims', () {
    final identity = {
      'project_ref': QaPreviewPolicy.projectRef,
      'business_id': QaPreviewPolicy.businessId,
      'purpose': 'synthetic-only',
    };
    QaPreviewPolicy.validateIdentity(identity);
    for (final invalid in [
      null,
      {},
      {...identity, 'purpose': 'production'},
      {...identity, 'project_ref': 'tuasxnfwrepbcelnrlgb'},
      {...identity, 'business_id': 'other'},
      {...identity, 'extra': true},
    ]) {
      expect(
        () => QaPreviewPolicy.validateIdentity(invalid),
        throwsFormatException,
      );
    }
  });
  testWidgets('QA banner stays legible at narrow 200 percent scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const QaPreviewFrame(child: Scaffold(body: Text('Sign in'))),
        ),
      ),
    );
    expect(find.text('Testing — synthetic data only'), findsOneWidget);
    expect(find.text('آزمائش — صرف مصنوعی ڈیٹا'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
