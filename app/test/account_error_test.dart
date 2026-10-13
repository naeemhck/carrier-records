import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:carrier_records/features/auth/account_error.dart';

void main() {
  test('account errors identify only approved stages and status', () {
    final message = accountErrorMessage(
      FunctionException(
        status: 403,
        details: {
          'error_code': 'CURRENT_PASSWORD_VERIFICATION_FAILED',
          'error': 'private credential or provider details',
        },
      ),
    );
    expect(message, contains('Current password verification failed'));
    expect(message, contains('HTTP 403'));
    expect(message, isNot(contains('private')));
  });
  test('unknown bodies and exceptions cannot expose private information', () {
    for (final body in [
      'private token',
      {'error_code': 'private token', 'error': 'secret'},
      null,
    ]) {
      expect(
        accountErrorMessage(FunctionException(status: 400, details: body)),
        isNot(contains('secret')),
      );
      expect(
        accountErrorMessage(FunctionException(status: 400, details: body)),
        isNot(contains('private token')),
      );
    }
    expect(accountErrorMessage(Exception('secret')), isNot(contains('secret')));
  });
}
