/// UUIDs stay as validated strings at backend interfaces.
final class RecordId {
  final String value;
  RecordId(String value) : value = value.toLowerCase() {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value)) {
      throw FormatException('Expected UUID');
    }
  }
  @override
  bool operator ==(Object other) => other is RecordId && value == other.value;
  @override
  int get hashCode => value.hashCode;
}

final class RecordContext {
  final RecordId id;
  final RecordId businessId;
  final int version;
  RecordContext({
    required this.id,
    required this.businessId,
    required this.version,
  }) {
    if (version < 1 || version > 2147483647) {
      throw RangeError('Invalid record version');
    }
  }
}

/// Expected version zero is reserved for creation; request ID survives retries.
final class CommandEnvelope {
  final RecordId requestId;
  final int expectedVersion;
  final Map<String, Object?> payload;
  CommandEnvelope({
    required this.requestId,
    required this.expectedVersion,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload) {
    if (expectedVersion < 0 || expectedVersion > 2147483647) {
      throw RangeError('Invalid expected version');
    }
  }
  Map<String, Object?> toJson() => {
    'request_id': requestId.value,
    'expected_version': expectedVersion,
    'payload': payload,
  };
}
