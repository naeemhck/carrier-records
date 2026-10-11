import 'package:carrier_records/core/domain/business_date.dart';
import 'package:carrier_records/core/domain/money.dart';
import 'package:carrier_records/core/domain/record_context.dart';
import 'package:carrier_records/features/finance/financial_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const id = '11111111-1111-4111-8111-111111111111';
  FinancialClaim claim({
    String purpose = 'CUSTOMER_RECEIVABLE',
    String remaining = '0.03',
  }) => FinancialClaim.fromJson({
    'line_id': id,
    'party_id': id,
    'account_purpose': purpose,
    'remaining': remaining,
    'version': 2,
  });
  CustomerReceipt receipt(String total, List<ReceiptAllocation> allocations) =>
      CustomerReceipt(
        payer: RecordId(id),
        recipient: RecordId(id),
        office: RecordId(id),
        date: BusinessDate.parse('2026-03-05'),
        amount: Money.parse(total),
        reason: ' Real receipt ',
        allocations: allocations,
      );
  test('eight purposes retain distinct claims/custody/settlement meanings', () {
    expect(AccountPurpose.values.length, 8);
    expect(
      AccountPurpose.parse('CUSTODY_RECEIVABLE'),
      isNot(AccountPurpose.ownerPayable),
    );
    expect(() => AccountPurpose.parse('REVENUE'), throwsStateError);
  });
  test('aggregates remain exact beyond one transaction limit', () {
    final amount = LedgerAmount.fromJson('19999999999999999.98');
    expect(amount.paisa, BigInt.parse('1999999999999999998'));
    expect(amount.toString(), '19999999999999999.98');
    expect(LedgerAmount.fromJson('-0.01').paisa, BigInt.from(-1));
    expect(() => LedgerAmount.fromJson(0.01), throwsFormatException);
  });
  test(
    'AT-17 receipt uses decimal strings and exact matched paisa allocations',
    () {
      final c = claim();
      final p = receipt('0.02', [
        ReceiptAllocation(c, Money.parse('0.02')),
      ]).toJson();
      expect(p['amount'], '0.02');
      expect(p['effective_date'], '2026-03-05');
      expect((p['allocations'] as List).first, {
        'target_line_id': id,
        'target_version': 2,
        'amount': '0.02',
      });
      expect(p.containsKey('journal_lines'), false);
      expect(p.containsKey('actor_id'), false);
      expect(
        () => receipt('0.03', [ReceiptAllocation(c, Money.parse('0.02'))]),
        throwsFormatException,
      );
      expect(
        () => receipt('0.02', [
          ReceiptAllocation(c, Money.parse('0.01')),
          ReceiptAllocation(c, Money.parse('0.01')),
        ]),
        throwsFormatException,
      );
    },
  );
  test(
    'wrong purpose, overconsumption and invalid precision fail before posting',
    () {
      expect(
        () => ReceiptAllocation(
          claim(purpose: 'OWNER_PAYABLE'),
          Money.parse('0.01'),
        ),
        throwsFormatException,
      );
      expect(
        () => ReceiptAllocation(claim(), Money.parse('0.04')),
        throwsFormatException,
      );
      expect(() => Money.parse('0.001'), throwsFormatException);
      expect(
        () => FinancialClaim.fromJson({
          'line_id': id,
          'party_id': id,
          'account_purpose': 'CUSTOMER_RECEIVABLE',
          'remaining': 0.03,
          'version': 1,
        }),
        throwsFormatException,
      );
    },
  );
}
