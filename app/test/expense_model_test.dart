import 'package:carrier_records/features/expenses/expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> make({
    ExpenseFunding funding = ExpenseFunding.self,
    String payer = 'owner',
    String bearer = 'owner',
    String amount = '10000.00',
    bool agreed = false,
    List<Map<String, dynamic>> allocations = const [],
    bool recognized = true,
    String? available,
  }) => expensePayload(
    vehicle: 'vehicle',
    trip: 'trip',
    office: 'office',
    category: 'diesel',
    date: '2026-02-01',
    amount: amount,
    payer: payer,
    bearer: bearer,
    owner: 'owner',
    funding: funding,
    reason: 'Actual expense',
    agreed: agreed,
    allocations: allocations,
    earningsRecognized: recognized,
    availableOwner: available,
  );
  test('Owner personally pays cost without an entitlement allocation', () {
    final p = make();
    expect(p['amount'], '10000.00');
    expect(p['allocations'], isEmpty);
    expect(p['funding_source'], 'SELF_FUNDED_COST');
  });
  test('Broker advance requires separately agreed exact owner offset', () {
    expect(
      () => make(funding: ExpenseFunding.personal, payer: 'broker'),
      throwsFormatException,
    );
    final p = make(
      funding: ExpenseFunding.personal,
      payer: 'broker',
      agreed: true,
      allocations: [
        {'amount': '10000.00', 'component': 'OFFSET'},
      ],
    );
    expect(p['funding_source'], 'PERSONAL_FUNDS');
    expect(p['allocations'], hasLength(1));
  });
  test(
    'Held spending validates both cash and noncash amounts independently',
    () {
      expect(
        () => make(
          funding: ExpenseFunding.held,
          payer: 'broker',
          agreed: true,
          allocations: [
            {'amount': '10000.00', 'component': 'OFFSET'},
          ],
        ),
        throwsFormatException,
      );
      expect(
        make(
          funding: ExpenseFunding.held,
          payer: 'broker',
          agreed: true,
          allocations: [
            {'amount': '10000.00', 'component': 'OFFSET'},
            {'amount': '10000.00', 'component': 'CASH'},
          ],
        )['amount'],
        '10000.00',
      );
    },
  );
  test('Different cost bearer and draft have separate recovery without owner netting', () {
    expect(
      make(
        funding: ExpenseFunding.personal,
        payer: 'broker',
        bearer: 'driver',
      )['allocations'],
      isEmpty,
    );
    expect(
      make(
        funding: ExpenseFunding.personal,
        payer: 'broker',
        recognized: false,
      )['allocations'],
      isEmpty,
    );
  });
  test('Exact validation rejects extra decimals and self funding mismatch', () {
    expect(() => make(amount: '0.001'), throwsFormatException);
    expect(() => make(payer: 'broker'), throwsFormatException);
  });
  test(
    'Expense above available entitlement only consumes its available claim',
    () {
      expect(
        make(
          funding: ExpenseFunding.personal,
          payer: 'broker',
          amount: '100000.00',
          available: '9500000',
          agreed: true,
          allocations: [
            {'amount': '95000.00', 'component': 'OFFSET'},
          ],
        )['amount'],
        '100000.00',
      );
    },
  );
}
