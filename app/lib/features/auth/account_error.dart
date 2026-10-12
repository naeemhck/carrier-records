import 'package:supabase_flutter/supabase_flutter.dart';

String accountErrorMessage(Object error) {
  if (error is FunctionException) {
    const messages = {
      'CURRENT_PASSWORD_VERIFICATION_FAILED': 'Current password verification failed. Check the temporary password or contact your administrator.',
      'ACCOUNT_SESSION_REJECTED': 'Your account session was rejected. Sign out and sign in again.',
      'ACCOUNT_ACCESS_REJECTED': 'Account access could not be verified. Contact your administrator.',
      'PASSWORD_PREPARATION_FAILED': 'Password change could not be prepared. Contact your administrator.',
      'ACCOUNT_SERVICE_REJECTED': 'The account service rejected the operation. Contact your administrator.',
      'ACCOUNT_REQUEST_REJECTED': 'Check the account fields. New passwords must contain 12 to 128 characters.',
    };
    final details = error.details;
    final code = details is Map ? details['error_code'] : null;
    final message = messages[code] ?? 'The account request failed. Contact your administrator.';
    return '$message (HTTP ${error.status})';
  }
  return 'Request failed. Check your credentials, connection or administrator access.';
}
