import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/domain/business_date.dart';
import '../../core/domain/money.dart';
import '../../core/domain/record_context.dart';

enum AccountPurpose {
  customerReceivable('CUSTOMER_RECEIVABLE'),
  custodyReceivable('CUSTODY_RECEIVABLE'),
  ownerPayable('OWNER_PAYABLE'),
  brokerCommissionPayable('BROKER_COMMISSION_PAYABLE'),
  customerAdvanceCredit('CUSTOMER_ADVANCE_CREDIT'),
  expenseReimbursementPayable('EXPENSE_REIMBURSEMENT_PAYABLE'),
  tripFundingPayable('TRIP_FUNDING_PAYABLE'),
  partyCostRecovery('PARTY_COST_RECOVERY');

  const AccountPurpose(this.key);
  final String key;
  static AccountPurpose parse(String key) =>
      values.firstWhere((p) => p.key == key);
}

/// Aggregates may exceed a single NUMERIC(18,2) transaction; still exact paisa.
final class LedgerAmount {
  LedgerAmount.fromJson(Object? value) {
    if (value is! String || !RegExp(r'^-?[0-9]+\.[0-9]{2}$').hasMatch(value)) {
      throw const FormatException('Canonical decimal balance required');
    }
    final parts = value.replaceFirst('-', '').split('.');
    paisa =
        (BigInt.parse(parts[0]) * BigInt.from(100) + BigInt.parse(parts[1])) *
        BigInt.from(value.startsWith('-') ? -1 : 1);
  }
  late final BigInt paisa;
  @override
  String toString() =>
      '${paisa.isNegative ? '-' : ''}${paisa.abs() ~/ BigInt.from(100)}.${(paisa.abs() % BigInt.from(100)).toString().padLeft(2, '0')}';
}

final class FinancialClaim {
  FinancialClaim.fromJson(Map<String, dynamic> row)
    : id = RecordId(row['line_id'] as String),
      party = RecordId(row['party_id'] as String),
      purpose = AccountPurpose.parse(row['account_purpose'] as String),
      remaining = Money.fromJson(row['remaining']),
      version = row['version'] as int;
  final RecordId id, party;
  final AccountPurpose purpose;
  final Money remaining;
  final int version;
}

final class ReceiptAllocation {
  ReceiptAllocation(this.claim, this.amount) {
    if (claim.purpose != AccountPurpose.customerReceivable ||
        amount.paisa <= 0 ||
        amount.compareTo(claim.remaining) > 0) {
      throw const FormatException(
        'Positive allocation within customer claim required',
      );
    }
  }
  final FinancialClaim claim;
  final Money amount;
  Map<String, Object> toJson() => {
    'target_line_id': claim.id.value,
    'target_version': claim.version,
    'amount': amount.toString(),
  };
}

final class CustomerReceipt {
  CustomerReceipt({
    required this.payer,
    required this.recipient,
    required this.office,
    required this.date,
    required this.amount,
    required this.reason,
    required List<ReceiptAllocation> allocations,
  }) : allocations = List.unmodifiable(allocations) {
    if (amount.paisa <= 0 ||
        reason.trim().isEmpty ||
        reason.trim().length > 500 ||
        allocations.isEmpty ||
        allocations.length > 100 ||
        allocations.map((a) => a.claim.id.value).toSet().length !=
            allocations.length ||
        allocations.any((a) => a.claim.party.value != payer.value) ||
        allocations.fold(
              BigInt.zero,
              (sum, a) => sum + BigInt.from(a.amount.paisa),
            ) !=
            BigInt.from(amount.paisa)) {
      throw const FormatException(
        'Receipt amount and explicit customer allocations must match',
      );
    }
  }
  final RecordId payer, recipient, office;
  final BusinessDate date;
  final Money amount;
  final String reason;
  final List<ReceiptAllocation> allocations;
  Map<String, Object> toJson() => {
    'payer_id': payer.value,
    'payee_id': recipient.value,
    'office_id': office.value,
    'effective_date': date.toString(),
    'amount': amount.toString(),
    'reason': reason.trim(),
    'allocations': allocations.map((a) => a.toJson()).toList(),
  };
}

/// T07 contracts only. Transfer/expense entry screens are added in T08/T09.
class FinancialRepository {
  FinancialRepository(this.client);
  final SupabaseClient client;
  Future<Map<String, dynamic>> trip(RecordId id) async =>
      Map<String, dynamic>.from(
        await client.rpc('get_trip_financials', params: {'trip_id': id.value})
            as Map,
      );
  Future<Map<String, dynamic>> receipt(
    RecordId request,
    CustomerReceipt receipt,
  ) async => Map<String, dynamic>.from(
    await client.rpc(
      'post_financial_event',
      params: {
        'event_kind': 'CUSTOMER_RECEIPT',
        'request_id': request.value,
        'expected_version': 0,
        'payload': receipt.toJson(),
      },
    ) as Map,
  );
}
