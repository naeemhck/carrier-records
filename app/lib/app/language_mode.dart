import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bilingual_message.dart';
import 'bilingual_widgets.dart';
import 'ui_catalogue.dart';

/// Display language for the whole app (owner directive, 2026-10-20 density
/// pass). This supersedes the earlier "always stacked, never a switch" rule:
/// staff choose English only, Urdu only, or the stacked bilingual view.
/// Bilingual stays the default because the office is mixed-language.
///
/// The mode is presentation state only: it is persisted on the device with
/// SharedPreferences and never reaches the backend. Layout stays LTR in
/// every mode and values (amounts, dates, IDs) stay LTR-locked Latin —
/// Urdu-only renders the existing Urdu strings, it does not mirror the UI.
enum KarvaanLanguageMode { english, urdu, bilingual }

extension KarvaanLanguageModeLabel on KarvaanLanguageMode {
  Bilingual get label => switch (this) {
    KarvaanLanguageMode.english => L10n.languageEnglish,
    KarvaanLanguageMode.urdu => L10n.languageUrdu,
    KarvaanLanguageMode.bilingual => L10n.languageBilingual,
  };
}

extension BilingualModeText on Bilingual {
  /// The one-string form of this message in [mode]: single-string slots
  /// (tooltips, menu labels) use it instead of always stacking both lines.
  String inMode(KarvaanLanguageMode mode) => switch (mode) {
    KarvaanLanguageMode.english => en,
    KarvaanLanguageMode.urdu => ur.isEmpty ? en : ur,
    KarvaanLanguageMode.bilingual => inline,
  };
}

/// Owns the current [KarvaanLanguageMode] and its on-device persistence.
/// Widgets listen through [LanguageModeBuilder]; nothing else needs wiring.
class LanguageModeStore {
  LanguageModeStore._();
  static final LanguageModeStore instance = LanguageModeStore._();
  static const String storageKey = 'karvaan.language_mode';

  final ValueNotifier<KarvaanLanguageMode> mode = ValueNotifier(
    KarvaanLanguageMode.bilingual,
  );

  bool get isSingleLanguage => mode.value != KarvaanLanguageMode.bilingual;

  /// Restores the saved choice at startup. Storage failures keep the
  /// bilingual default — a preference must never block sign-in.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      final parsed = KarvaanLanguageMode.values.asNameMap()[saved];
      if (parsed != null) mode.value = parsed;
    } catch (_) {
      // Best-effort preference; ignore storage errors.
    }
  }

  Future<void> setMode(KarvaanLanguageMode next) async {
    if (mode.value == next) return;
    mode.value = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, next.name);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

/// Rebuilds [builder] whenever the display language changes.
class LanguageModeBuilder extends StatelessWidget {
  const LanguageModeBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, KarvaanLanguageMode mode) builder;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<KarvaanLanguageMode>(
        valueListenable: LanguageModeStore.instance.mode,
        builder: (context, mode, _) => builder(context, mode),
      );
}

/// The language switch as a segmented control (Account settings). Each
/// segment names itself in its own language, so it reads correctly in
/// whichever mode is currently active.
class LanguageModePicker extends StatelessWidget {
  const LanguageModePicker({super.key});
  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) => SegmentedButton<KarvaanLanguageMode>(
      showSelectedIcon: false,
      segments: [
        const ButtonSegment(
          value: KarvaanLanguageMode.english,
          label: Text('English', textDirection: TextDirection.ltr),
        ),
        ButtonSegment(
          value: KarvaanLanguageMode.urdu,
          label: Text(
            'اردو',
            textDirection: TextDirection.rtl,
            style: karvaanUrduStyle(context, null),
          ),
        ),
        const ButtonSegment(
          value: KarvaanLanguageMode.bilingual,
          label: Text('English + اردو', textDirection: TextDirection.ltr),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) =>
          LanguageModeStore.instance.setMode(selection.first),
    ),
  );
}

/// The language switch for the shell top bar: a compact menu button whose
/// items name the three modes and tick the active one.
class LanguageModeMenuButton extends StatelessWidget {
  const LanguageModeMenuButton({super.key});
  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) => PopupMenuButton<KarvaanLanguageMode>(
      popUpAnimationStyle: AnimationStyle.noAnimation,
      tooltip: L10n.language.inMode(mode),
      icon: const Icon(Icons.language_outlined),
      initialValue: mode,
      onSelected: LanguageModeStore.instance.setMode,
      itemBuilder: (_) => [
        for (final option in KarvaanLanguageMode.values)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: option == mode
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                Expanded(child: BilingualText(option.label)),
              ],
            ),
          ),
      ],
    ),
  );
}
