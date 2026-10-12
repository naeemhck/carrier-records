// Execute dart2js output with Node to verify the release JavaScript money runtime.
import 'package:carrier_records/core/domain/money.dart';
import 'package:carrier_records/features/finance/payment_model.dart';

void main() {
  var checks = 0;
  void check(bool condition) {
    if (!condition) throw StateError('Exact-money JavaScript regression');
    checks++;
  }

  final value = Money.parse('90071992547409.93');
  check(value.paisa == BigInt.parse('9007199254740993'));
  check(value.toJson() == '90071992547409.93');
  check((value + Money.parse('0.01')).toJson() == '90071992547409.94');
  check((value - Money.parse('0.01')).toJson() == '90071992547409.92');
  check((-value).toJson() == '-90071992547409.93');
  final maximum = Money.parse('9999999999999999.99');
  check(maximum.toJson() == '9999999999999999.99');
  check(Percentage.parse('100').applyTo(maximum) == maximum);
  check(Percentage.parse('50').applyTo(Money.parse('0.01')).toJson() == '0.01');
  var rejected = false;
  try {
    maximum + Money.parse('0.01');
  } on RangeError {
    rejected = true;
  }
  check(rejected);
  final totals = AllocationTotals(['90071992547409.93', '0.01'], [], []);
  totals.validate('90071992547409.94', false);
  check(totals.cash == BigInt.parse('9007199254740994'));
  rejected = false;
  try {
    totals.validate('90071992547409.93', false);
  } on FormatException {
    rejected = true;
  }
  check(rejected);
  // This standalone verification tool intentionally reports its check count.
  // ignore: avoid_print
  print('PASS $checks exact-money checks in the JavaScript runtime');
}
