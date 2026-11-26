import 'package:flutter/material.dart';

import 'bilingual.dart';
import 'karvaan_typography.dart';

/// Presentation tokens only. No domain state or derived financial totals.
///
/// Color is semantic (frontend plan §2.1): blue always means movement and
/// the primary action, green always means money, amber means attention,
/// red means error/overdue. Everything else is a neutral: structure comes
/// from one hairline grey and white surfaces, not from tinted borders.
/// Radius: cards 10, inputs/buttons 8, chips full-round.
abstract final class KarvaanDesign {
  static const primary = Color(0xFF1E40AF);
  static const primaryBright = Color(0xFF3B82F6);

  /// Tinted fill for selected navigation, tabs, chips and the Dispatched
  /// status. Never a border.
  static const primarySurface = Color(0xFFE8EEFC);
  static const money = Color(0xFF15803D);
  static const moneySurface = Color(0xFFF0FDF4);
  static const attention = Color(0xFFD97706);
  static const destructive = Color(0xFFDC2626);
  static const background = Color(0xFFF5F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const headingInk = Color(0xFF0F172A);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFFEEF1F5);
  static const secondary = Color(0xFF475569);

  /// The one hairline: card, panel, table and divider edges.
  static const borderColor = Color(0xFFE3E7ED);

  /// Control outlines (inputs, outlined buttons) sit one step darker so
  /// an empty field is still visibly a field.
  static const outline = Color(0xFFC7CED8);

  /// Money green. Kept as the accent name existing screens reference; it
  /// marks money only — movement and primary actions use [primary].
  static const accent = money;
  static const space = 8.0;
  static const primaryGradient = LinearGradient(
    colors: [primary, primaryBright],
  );

  static ThemeData theme() {
    const radius = BorderRadius.all(Radius.circular(8));
    const shape = RoundedRectangleBorder(borderRadius: radius);
    final type = KarvaanTypography.textTheme;
    final scheme = ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primarySurface,
      onPrimaryContainer: primary,
      secondaryContainer: primarySurface,
      onSecondaryContainer: primary,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: secondary,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: surface,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: muted,
      surfaceContainerHighest: muted,
      outline: outline,
      outlineVariant: borderColor,
      error: destructive,
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      // One density on every platform: desktop otherwise shrinks buttons
      // below the fields they sit beside.
      visualDensity: VisualDensity.standard,
      splashFactory: NoSplash.splashFactory,
      fontFamily: KarvaanTypography.latinFamily,
      textTheme: type,
      fontFamilyFallback: KarvaanTypography.latinFallback,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      // Entry, focus, dropdown and navigation changes remain immediate.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: _ImmediateTransition(),
          TargetPlatform.android: _ImmediateTransition(),
          TargetPlatform.linux: _ImmediateTransition(),
          TargetPlatform.macOS: _ImmediateTransition(),
          TargetPlatform.iOS: _ImmediateTransition(),
        },
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 56,
        titleTextStyle: type.titleMedium?.copyWith(
          color: headingInk,
          fontFamily: KarvaanTypography.latinFamily,
        ),
        backgroundColor: surface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: borderColor)),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          side: BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: type.bodyMedium?.copyWith(color: secondary),
        helperStyle: type.bodySmall?.copyWith(color: secondary),
        errorStyle: type.bodySmall,
        // Avoid Material shrinking Urdu floating labels below the readable floor.
        floatingLabelStyle: type.bodyMedium,
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: inputBorder(outline),
        enabledBorder: inputBorder(outline),
        disabledBorder: inputBorder(borderColor),
        focusedBorder: inputBorder(primary, 1.5),
        errorBorder: inputBorder(destructive),
        focusedErrorBorder: inputBorder(destructive, 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 40),
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              textStyle: type.labelLarge,
              animationDuration: Duration.zero,
            ).copyWith(
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? const BorderSide(color: ink, width: 2)
                    : BorderSide.none,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          backgroundColor: surface,
          shape: shape,
          side: const BorderSide(color: outline),
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: type.labelLarge,
          animationDuration: Duration.zero,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: shape,
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: type.labelLarge,
          animationDuration: Duration.zero,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(shape),
          side: const WidgetStatePropertyAll(BorderSide(color: outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primarySurface
                : surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? primary : ink,
          ),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
          animationDuration: Duration.zero,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primarySurface,
        side: const BorderSide(color: outline),
        shape: const StadiumBorder(),
        labelStyle: type.bodySmall?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: type.bodyMedium?.copyWith(
          color: ink,
          fontFamily: KarvaanTypography.latinFamily,
        ),
        subtitleTextStyle: type.bodySmall?.copyWith(
          color: secondary,
          fontFamily: KarvaanTypography.latinFamily,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        titleTextStyle: type.titleMedium?.copyWith(
          color: headingInk,
          fontFamily: KarvaanTypography.latinFamily,
        ),
        contentTextStyle: type.bodyMedium?.copyWith(
          color: ink,
          fontFamily: KarvaanTypography.latinFamily,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: borderColor),
        ),
        textStyle: type.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: headingInk,
          borderRadius: BorderRadius.all(Radius.circular(6)),
        ),
        textStyle: type.bodySmall?.copyWith(color: Colors.white),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: type.bodySmall?.copyWith(
          color: secondary,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: type.bodyMedium?.copyWith(color: ink),
        dividerThickness: 1,
        decoration: const BoxDecoration(
          color: surface,
          border: Border.fromBorderSide(BorderSide(color: borderColor)),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primarySurface,
      ),
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 1),
    );
  }
}

class _ImmediateTransition extends PageTransitionsBuilder {
  const _ImmediateTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Bounded navigation/action panel: an opaque white surface with the one
/// hairline edge. It replaced the blurred translucent material — a records
/// tool reads better on solid surfaces, and it costs nothing to paint.
/// Never apply to forms, rows or money.
class KarvaanGlass extends StatelessWidget {
  const KarvaanGlass({super.key, required this.child, this.opaque = false});
  final Widget child;

  /// Retained for callers; the panel is always opaque now.
  final bool opaque;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: KarvaanDesign.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KarvaanDesign.borderColor),
      ),
      child: child,
    ),
  );
}

class KarvaanSection extends StatelessWidget {
  const KarvaanSection({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Bilingual title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BilingualText(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// One canonical figure, followed by its quiet label. Never computes a total.
class KarvaanMetric extends StatelessWidget {
  const KarvaanMetric({
    super.key,
    required this.label,
    required this.formattedValue,
    this.hero = false,
    this.compact = false,
  });
  final Bilingual label;
  final String formattedValue;
  final bool hero, compact;
  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        KarvaanFigure(
          formattedValue,
          style: hero
              ? type.displaySmall
              : compact
              ? type.bodyMedium
              : type.headlineSmall,
        ),
        const SizedBox(height: 4),
        BilingualText(label, style: type.bodySmall),
      ],
    );
  }
}

/// Keep decimal digits on one line without reducing the user's text scale.
/// A bounded horizontal scrollbar exposes long values at narrow/large scales.
/// Figures always render in the tabular figure face (plan §2.2).
class KarvaanFigure extends StatefulWidget {
  const KarvaanFigure(this.value, {super.key, required this.style});
  final String value;
  final TextStyle? style;
  @override
  State<KarvaanFigure> createState() => _KarvaanFigureState();
}

class _KarvaanFigureState extends State<KarvaanFigure> {
  final scroll = ScrollController();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: scroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: scroll,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        widget.value,
        style: (widget.style ?? const TextStyle()).copyWith(
          fontFamily: KarvaanTypography.figureFamily,
          fontFamilyFallback: KarvaanTypography.latinFallback,
          fontFeatures: KarvaanTypography.figureFeatures,
        ),
        textDirection: TextDirection.ltr,
        softWrap: false,
      ),
    ),
  );
}

/// Displays an existing canonical amount; deliberately performs no arithmetic.
class KarvaanAmount extends StatelessWidget {
  const KarvaanAmount({
    super.key,
    required this.label,
    required this.value,
    this.hero = false,
  });
  final Bilingual label;
  final String value;
  final bool hero;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: KarvaanDesign.moneySurface,
      borderRadius: BorderRadius.circular(10),
    ),
    child: KarvaanMetric(
      label: label,
      formattedValue: displayMoney(value),
      hero: hero,
    ),
  );
}

/// Status chip (plan §2.1): one component, fixed colors everywhere —
/// Draft muted, Dispatched blue, Arrived green, Cancelled red outline.
class TripStatusBadge extends StatelessWidget {
  const TripStatusBadge(this.state, {super.key});
  final String state;
  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (state) {
      'DRAFT' => (KarvaanDesign.secondary, KarvaanDesign.muted),
      'DISPATCHED' => (KarvaanDesign.primary, KarvaanDesign.primarySurface),
      'ARRIVED' => (KarvaanDesign.money, KarvaanDesign.moneySurface),
      'CANCELLED' => (KarvaanDesign.destructive, KarvaanDesign.surface),
      _ => (KarvaanDesign.secondary, KarvaanDesign.background),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: state == 'CANCELLED'
            ? Border.all(color: KarvaanDesign.destructive)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: BilingualText(
          tripStateLabel(state),
          stacked: false,
          style: TextStyle(
            color: foreground,
            fontSize: KarvaanTypography.caption,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The detail tab bar (density pass): the same glass pill row the pinned
/// sliver header used to render, but a plain widget — the detail layout
/// keeps it permanently visible above the scrolling tab content instead
/// of pinning it inside a page scroll view.
class KarvaanTabBar extends StatelessWidget {
  const KarvaanTabBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<Bilingual> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: KarvaanGlass(
      key: const ValueKey('detail-tabs'),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: TextButton(
                  key: ValueKey('detail-tab-$i'),
                  style: TextButton.styleFrom(
                    backgroundColor: selected == i
                        ? KarvaanDesign.primarySurface
                        : Colors.transparent,
                    foregroundColor: selected == i
                        ? KarvaanDesign.primary
                        : KarvaanDesign.secondary,
                  ),
                  onPressed: () => onSelected(i),
                  child: BilingualText(labels[i]),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
