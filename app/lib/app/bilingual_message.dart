/// Stable typed presentation message. Values are opaque, never translated.
class Bilingual {
  const Bilingual(this.key, this.en, this.ur);
  factory Bilingual.data(Object? value) =>
      Bilingual('opaque.data', value?.toString() ?? '', '');
  final String key, en, ur;
  Bilingual withValues(List<Object?> values) {
    String fill(String template, bool urdu) =>
        template.replaceAllMapped(RegExp(r'\{([0-9]+)\}'), (m) {
          final value = values[int.parse(m[1]!)];
          final text = value is Bilingual
              ? (urdu && value.ur.isNotEmpty ? value.ur : value.en)
              : value?.toString() ?? '';
          return urdu ? '\u2068$text\u2069' : text;
        });
    return Bilingual(key, fill(en, false), fill(ur, true));
  }

  String get inline => '$en\n\u2067$ur\u2069';
}
