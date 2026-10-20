import 'authorized_output.dart';

/// V2 consumes only frozen, authorized presentation. Never reads today's UI catalogue.
class BilingualOutput {
  BilingualOutput(Map<String, dynamic> raw) {
    if (raw['template_version'] != 2 || raw['schema_version'] != 1) {
      throw const FormatException('Unsupported bilingual output version.');
    }
    base = AuthorizedOutput.fromPayload({...raw, 'template_version': 1});
    final p = raw['presentation'];
    if (p is! Map ||
        p['version'] != 2 ||
        p['font_set'] != 'noto-karvaan-20261013' ||
        !_presentationKeys(p)) {
      throw const FormatException('Invalid frozen presentation.');
    }
    internalUse = p.containsKey('internal_use')
        ? message(p['internal_use'])
        : _internalUseFallback;
    brand = message(p['brand']);
    titlePair = message(p['title']);
    if (titlePair.en != base.title) {
      throw const FormatException('Output identity mismatch.');
    }
    labels = messages(p['fields'], base.fields.map((f) => f.key).toSet());
    summaries = messages(p['summaries'], base.summaries.keys.toSet());
    for (final f in base.fields) {
      if (labels[f.key]!.en != f.label) {
        throw const FormatException('Field identity mismatch.');
      }
    }
    for (final e in base.summaries.entries) {
      if (summaries[e.key]!.en != e.value) {
        throw const FormatException('Summary identity mismatch.');
      }
    }
    frames = messages(p['frames'], frameKeys);
    dates = messages(p['date_bases'], base.bases.keys.toSet());
    for (final e in base.bases.entries) {
      if (dates[e.key]!.en != '${e.key}: ${e.value}') {
        throw const FormatException('Date basis mismatch.');
      }
    }
  }
  static const frameKeys = {
    'offices',
    'date_bases',
    'currency',
    'records',
    'supersedes',
    'row',
    'summary',
    'no_records',
    'selected',
    'page',
    'issued',
    'live',
    'continuation',
    'precision',
    'totals',
  };
  static bool _sameKeys(Map map, Set<String> keys) =>
      map.length == keys.length && map.keys.every(keys.contains);

  /// Required presentation keys, plus the optional server-supplied
  /// "internal use" footer note. Unknown keys are still rejected.
  static const _requiredPresentationKeys = {
    'version',
    'font_set',
    'brand',
    'title',
    'fields',
    'summaries',
    'frames',
    'date_bases',
  };
  static bool _presentationKeys(Map p) =>
      _requiredPresentationKeys.every(p.containsKey) &&
      p.keys.every(
        (k) => _requiredPresentationKeys.contains(k) || k == 'internal_use',
      );

  /// Renderer-side frozen fallback for the footer "internal use" note, used
  /// only when the server presentation does not supply its own wording.
  static const _internalUseFallback = FrozenLabel(
    'Internal use only',
    'صرف اندرونی استعمال',
  );
  static FrozenLabel message(dynamic raw) {
    if (raw is! Map ||
        !_sameKeys(raw, {'en', 'ur'}) ||
        raw.values.any(
          (v) =>
              v is! String ||
              v.isEmpty ||
              v.length > 800 ||
              cleanText(v) != v ||
              RegExp('[۰-۹٠-٩]').hasMatch(v),
        )) {
      throw const FormatException('Invalid frozen label.');
    }
    return FrozenLabel(raw['en'] as String, raw['ur'] as String);
  }

  static Map<String, FrozenLabel> messages(dynamic raw, Set<String> keys) {
    if (raw is! Map || !_sameKeys(raw, keys)) {
      throw const FormatException('Unexpected presentation fields.');
    }
    return {for (final key in keys) key: message(raw[key])};
  }

  late final AuthorizedOutput base;
  late final FrozenLabel brand, titlePair, internalUse;
  late final Map<String, FrozenLabel> labels, summaries, frames, dates;
  String get title => '${brand.combined}\n${titlePair.combined}';
  List<OutputField> get fields => [
    for (final f in base.fields)
      OutputField({
        'field_key': f.key,
        'label': labels[f.key]!.combined,
        'value_type': f.type,
        'header': f.header,
      }),
  ];
  List<OutputField> get columns => fields.where((f) => !f.header).toList();
  Map<String, dynamic> get metadata => base.metadata;
  Map<String, dynamic> get totals => base.totals;
  bool get landscape => base.landscape;
  bool get issued => base.issued;
  String get sheetName => base.sheetName;
  int get recordCount => base.recordCount;
  List<Map<String, dynamic>> get rows => base.rows;
  List<List<dynamic>> get displayRows => base.displayRows;
  List<(String, String, String)> get headers => [
    for (final f in base.fields.where((f) => f.header))
      (
        labels[f.key]!.combined,
        f.type,
        // The generated-at header renders as a human date-time
        // ("20 Oct 2026, 13:16"), never the raw ISO stamp.
        f.key == 'generated_at'
            ? humanTimestampText(displayValue(f.type, base.metadata[f.key]))
            : displayValue(f.type, base.metadata[f.key]),
      ),
    (frames['offices']!.combined, 'TEXT', base.offices.join(', ')),
    // No date-bases block in exported documents: the basis descriptors are
    // internal metadata, not document content (owner directive, reports
    // pass). The frozen `dates` validation above still runs unchanged.
    if (base.metadata['supersedes_number'] != null)
      (
        frames['supersedes']!.combined,
        'TEXT',
        base.metadata['supersedes_number'] as String,
      ),
    (frames['currency']!.combined, 'TEXT', 'PKR'),
    (frames['records']!.combined, 'INTEGER', base.recordCount.toString()),
  ];
}

class FrozenLabel {
  const FrozenLabel(this.en, this.ur);
  final String en, ur;
  String get combined => '$en\n\u2067$ur\u2069';
  FrozenLabel values(List<Object> values) {
    var english = en, urdu = ur;
    for (var i = 0; i < values.length; i++) {
      english = english.replaceAll('{$i}', values[i].toString());
      urdu = urdu.replaceAll('{$i}', values[i].toString());
    }
    return FrozenLabel(english, urdu);
  }
}
