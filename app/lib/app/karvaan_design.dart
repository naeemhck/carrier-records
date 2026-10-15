import 'dart:ui';

import 'package:flutter/material.dart';

import 'bilingual.dart';

/// Presentation tokens only. No domain state or derived financial totals.
abstract final class KarvaanDesign {
  static const background = Color(0xFFF4F5F7);
  static const ink = Color(0xFF1D1D1F);
  static const secondary = Color(0xFF646469);
  static const accent = Color(0xFF0E7A3D);
  static const space = 8.0;
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF12A150), Color(0xFF0B5C2E)],
  );

  static ThemeData theme() {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic', 'NotoSansMath'],
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: accent).copyWith(
        primary: accent,
        onSurface: ink,
        surface: Colors.white,
        onSurfaceVariant: secondary,
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
      appBarTheme: const AppBarTheme(
        toolbarHeight: 88,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x0D000000)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          animationDuration: Duration.zero,
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
      dividerTheme: const DividerThemeData(color: Color(0x0D000000)),
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
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x16000000)),
      ),
      child: child,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
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

class TripStatusBadge extends StatelessWidget {
  const TripStatusBadge(this.state, {super.key});
  final String state;
  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (state) {
      'DRAFT' => (const Color(0xFFB25000), const Color(0xFFFFF4E0)),
      'DISPATCHED' => (const Color(0xFF0B57D0), const Color(0xFFE8F1FE)),
      'ARRIVED' => (const Color(0xFF0B5C2E), const Color(0xFFEAF4ED)),
      _ => (KarvaanDesign.secondary, KarvaanDesign.background),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: BilingualOwnedText(state, style: TextStyle(color: foreground)),
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
                          ? const Color(0xFFEAF4ED)
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
