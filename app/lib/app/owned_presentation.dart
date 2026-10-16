import 'bilingual_message.dart';
import 'ui_catalogue.dart';

// Call only for source-owned labels and mapped safe errors. Never call on
// names, notes, addresses, identifiers or arbitrary operational records.
final _exact = {for (final value in L10n.values) value.en: value};
final _folded = {
  for (final value in L10n.values)
    if (!value.en.contains('{')) value.en.toLowerCase(): value,
};
final _templates = [
  for (final value in L10n.values)
    if (value.en.contains(RegExp(r'\{[0-9]+\}')) &&
        RegExp(r'[A-Za-z]{3}')
            .hasMatch(value.en.replaceAll(RegExp(r'\{[0-9]+\}'), '')))
      _OwnedTemplate(value),
];

class _OwnedTemplate {
  _OwnedTemplate(this.value) {
    final placeholders = RegExp(r'\{([0-9]+)\}');
    final buffer = StringBuffer('^');
    var offset = 0;
    for (final match in placeholders.allMatches(value.en)) {
      buffer.write(RegExp.escape(value.en.substring(offset, match.start)));
      buffer.write('([\\s\\S]*?)');
      indices.add(int.parse(match[1]!));
      offset = match.end;
    }
    buffer.write(RegExp.escape(value.en.substring(offset)));
    buffer.write(r'$');
    pattern = RegExp(buffer.toString());
  }
  final Bilingual value;
  final indices = <int>[];
  late final RegExp pattern;
  Bilingual? resolve(String english) {
    final match = pattern.firstMatch(english);
    if (match == null) return null;
    final values = List<String>.filled(
      indices.reduce((a, b) => a > b ? a : b) + 1,
      '',
    );
    for (var i = 0; i < indices.length; i++) {
      values[indices[i]] = match[i + 1]!;
    }
    final filled = value.withValues(values);
    // Protect exact English and opaque values even if a future template has
    // repeated placeholders or an ambiguous delimiter.
    return filled.en == english ? filled : null;
  }
}

Bilingual ownedMessage(Object? source) {
  final english = source?.toString() ?? '';
  final exact = _exact[english];
  if (exact != null) return exact;
  final folded = _folded[english.toLowerCase()];
  if (folded != null) return Bilingual(folded.key, english, folded.ur);
  final http = RegExp(r'^([\s\S]*) \(HTTP ([0-9]{3})\)$').firstMatch(english);
  if (http != null) {
    final base = ownedMessage(http[1]);
    if (base.ur.isNotEmpty) return L10n.http.withValues([base, http[2]]);
  }
  for (final template in _templates) {
    final resolved = template.resolve(english);
    if (resolved != null) return resolved;
  }
  // Unknown provider text is not guessed, logged or used to change behavior.
  // Coverage tests must flag this key in any source-owned presentation fixture.
  return Bilingual('unresolved.presentation', english, '');
}

/// Only the backend's controlled date-basis descriptors, never record data.
Bilingual ownedDateBases(Object? source) {
  if (source is! Map) return Bilingual.data(source);
  return Bilingual(
    'ui.dateBasisValues',
    source.toString(),
    '{${source.entries.map((e) {
      final key = ownedMessage(e.key), value = ownedMessage(e.value);
      return L10n.labelValuesfb62fe.withValues([key, value]).ur;
    }).join(', ')}}',
  );
}

/// Controlled domain enums only: never infer meaning from arbitrary record text.
Bilingual tripStateLabel(Object? code) => switch (code) {
  'DRAFT' => L10n.draft,
  'DISPATCHED' => L10n.dispatched,
  'ARRIVED' => L10n.arrived,
  'CANCELLED' => L10n.cancelled,
  _ => Bilingual.data(code),
};
Bilingual loadKindLabel(Object? code) => switch (code) {
  'LOADED' => L10n.loaded,
  'EMPTY' => L10n.empty,
  _ => Bilingual.data(code),
};
Bilingual consignmentStateLabel(Object? code) => switch (code) {
  'ACTIVE' => L10n.consignmentActive,
  'DELIVERED' => L10n.delivered,
  'CANCELLED' => L10n.cancelled,
  _ => Bilingual.data(code),
};
Bilingual backupOutcomeLabel(Object? code) => switch (code) {
  'NEVER_RUN' => L10n.backupNeverRun,
  'RUNNING' => L10n.backupRunning,
  'SUCCESS' => L10n.backupSucceeded,
  'FAILED' => L10n.backupFailedState,
  _ => Bilingual.data(code),
};
