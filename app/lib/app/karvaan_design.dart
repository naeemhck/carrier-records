import 'dart:ui';

import 'package:flutter/material.dart';

import 'bilingual.dart';
import 'karvaan_typography.dart';

/// Presentation tokens only. No domain state or derived financial totals.
///
/// Redesign tokens (frontend plan §2.1): color is semantic — blue always
/// means movement, green always means money, amber means attention, red
/// means error/overdue. Radius: cards 10, inputs/buttons 8, chips full-round.
abstract final class KarvaanDesign {
  static const primary = Color(0xFF1E40AF);
  static const primaryBright = Color(0xFF3B82F6);
  static const money = Color(0xFF15803D);
  static const moneySurface = Color(0xFFF0FDF4);
  static const attention = Color(0xFFD97706);
  static const destructive = Color(0xFFDC2626);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const headingInk = Color(0xFF172554);
  static const ink = Color(0xFF1F2937);
  static const muted = Color(0xFFE9EEF6);
  static const secondary = Color(0xFF475569);
  static const borderColor = Color(0xFFDBEAFE);

  /// Money green. Kept as the accent name existing screens reference; it
  /// marks money only — movement and primary actions use [primary].
  static const accent = money;
  static const space = 8.0;
  static const primaryGradient = LinearGradient(
    colors: [primary, primaryBright],
  );

  static ThemeData theme() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );
    return ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      fontFamily: KarvaanTypography.latinFamily,
      textTheme: KarvaanTypography.textTheme,
      fontFamilyFallback: KarvaanTypography.latinFallback,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
        primary: primary,
        onSurface: ink,
        surface: surface,
        onSurfaceVariant: secondary,
        error: destructive,
      ),
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
        toolbarHeight: 88,
        titleTextStyle: KarvaanTypography.textTheme.titleLarge?.copyWith(
          color: headingInk,
          fontFamily: KarvaanTypography.latinFamily,
        ),
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: borderColor),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: KarvaanTypography.textTheme.bodyMedium,
        helperStyle: KarvaanTypography.textTheme.bodySmall,
        errorStyle: KarvaanTypography.textTheme.bodySmall,
        // Avoid Material shrinking Urdu floating labels below the readable floor.
        floatingLabelStyle: KarvaanTypography.textTheme.bodyMedium,
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 56),
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              animationDuration: Duration.zero,
            ).copyWith(
              backgroundBuilder: (context, states, child) =>
                  states.contains(WidgetState.disabled)
                  ? child ?? const SizedBox()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: primaryGradient,
                        ),
                        // Contrast overlay keeps both languages readable on the bright end.
                        child: ColoredBox(
                          color: const Color(0x33000000),
                          child: child,
                        ),
                      ),
                    ),
              side: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.focused)
                    ? const BorderSide(color: ink, width: 2)
                    : BorderSide.none,
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
          animationDuration: Duration.zero,
        ),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: KarvaanTypography.textTheme.bodyMedium?.copyWith(
          color: ink,
          fontFamily: KarvaanTypography.latinFamily,
        ),
        subtitleTextStyle: KarvaanTypography.textTheme.bodySmall?.copyWith(
          color: secondary,
          fontFamily: KarvaanTypography.latinFamily,
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: KarvaanTypography.textTheme.titleLarge?.copyWith(
          color: headingInk,
          fontFamily: KarvaanTypography.latinFamily,
        ),
        contentTextStyle: KarvaanTypography.textTheme.bodyMedium?.copyWith(
          color: ink,
          fontFamily: KarvaanTypography.latinFamily,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: KarvaanTypography.textTheme.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: KarvaanTypography.textTheme.bodySmall?.copyWith(
          color: Colors.white,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: KarvaanTypography.textTheme.labelLarge,
        dataTextStyle: KarvaanTypography.textTheme.bodyMedium,
      ),
      dividerTheme: const DividerThemeData(color: borderColor),
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

/// Bounded navigation/action material. Never apply to forms, rows or money.
class KarvaanGlass extends StatelessWidget {
  const KarvaanGlass({super.key, required this.child, this.opaque = false});
  final Widget child;
  final bool opaque;
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final solid =
        opaque ||
        media.highContrast ||
        media.accessibleNavigation ||
        media.disableAnimations;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? Colors.white : const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KarvaanDesign.borderColor),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: solid
          ? panel
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: panel,
            ),
    );
  }
}

class KarvaanSection extends StatelessWidget {
  const KarvaanSection({super.key, required this.title, required this.child});
  final Bilingual title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BilingualText(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
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
      'DISPATCHED' => (KarvaanDesign.primary, KarvaanDesign.borderColor),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: BilingualText(
          tripStateLabel(state),
          style: TextStyle(color: foreground),
        ),
      ),
    );
  }
}

class KarvaanPinnedTabs extends SliverPersistentHeaderDelegate {
  KarvaanPinnedTabs({
    required this.labels,
    required this.selected,
    required this.onSelected,
    required this.height,
  });
  final List<Bilingual> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox(
    height: height,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: KarvaanGlass(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton(
                    key: ValueKey('detail-tab-$i'),
                    style: TextButton.styleFrom(
                      backgroundColor: selected == i
                          ? KarvaanDesign.borderColor
                          : Colors.transparent,
                    ),
                    onPressed: () => onSelected(i),
                    child: BilingualText(labels[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  @override
  bool shouldRebuild(KarvaanPinnedTabs oldDelegate) =>
      oldDelegate.selected != selected ||
      oldDelegate.height != height ||
      oldDelegate.labels != labels;
}
