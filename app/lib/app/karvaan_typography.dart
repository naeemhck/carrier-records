import 'package:flutter/material.dart';

/// Logical-pixel UI scale. Printed/snapshot typography is intentionally separate.
///
/// Redesign tokens (frontend plan §2.2): Display 28/36, KPI figure 20/26,
/// Title 18/24, Body 14/20, Caption 12/16. Every face is bundled, so the
/// office PC renders identically offline: Latin UI is Fira Sans, figures and
/// identifiers are Fira Mono, and Urdu is Noto Sans Arabic.
abstract final class KarvaanTypography {
  static const display = 28.0;
  static const headline = 22.0;
  static const title = 18.0;
  static const body = 14.0;
  static const caption = 12.0;
  static const micro = 11.0;

  /// Owner directive (2026-11-26 GUI refresh): Urdu stays on every label
  /// but as a quiet companion to the English, never a second full-size
  /// line. The companion run is sized from the English it accompanies and
  /// held between these bounds; accessibility text scaling still applies
  /// on top. This supersedes the earlier 11pt (44/3 px) Urdu floor.
  static const urduMinimum = 13.0;
  static const urduCompanionMaximum = 16.0;
  static const urduCompanionRatio = 0.93;

  static const latinFamily = 'FiraSans';
  static const figureFamily = 'FiraMono';
  static const urduBodyFamily = 'NotoSansArabic';

  /// Headings share the body face: a taller display script was the main
  /// reason bilingual headings dominated the page.
  static const urduDisplayFamily = urduBodyFamily;
  static const latinFallback = ['NotoSans', 'NotoSansArabic', 'NotoSansMath'];
  static const urduFallback = ['NotoSansArabic', 'NotoSans', 'NotoSansMath'];

  static const screenTitle = TextStyle(
    fontSize: headline,
    fontWeight: FontWeight.w600,
    fontFamily: latinFamily,
    fontFamilyFallback: latinFallback,
  );
  static const sectionTitle = TextStyle(
    fontSize: title,
    fontWeight: FontWeight.w600,
    fontFamily: latinFamily,
    fontFamilyFallback: latinFallback,
  );
  static const bodyStyle = TextStyle(
    fontSize: body,
    fontFamily: latinFamily,
    fontFamilyFallback: latinFallback,
  );
  static const figureFeatures = [FontFeature.tabularFigures()];
  static TextStyle role(
    double size, [
    FontWeight weight = FontWeight.w400,
    double? height,
  ]) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    height: height,
    fontFamily: latinFamily,
    fontFamilyFallback: latinFallback,
    fontFeatures: figureFeatures,
  );

  static TextTheme get textTheme => TextTheme(
    displayLarge: role(display, FontWeight.w700, 36 / display),
    displayMedium: role(display, FontWeight.w700, 36 / display),
    displaySmall: role(display, FontWeight.w700, 36 / display),
    headlineLarge: role(headline, FontWeight.w600),
    headlineMedium: role(headline, FontWeight.w600),
    headlineSmall: role(20, FontWeight.w600, 26 / 20),
    titleLarge: role(headline, FontWeight.w600),
    titleMedium: role(title, FontWeight.w600, 24 / title),
    titleSmall: role(16, FontWeight.w600),
    bodyLarge: role(body, FontWeight.w400, 20 / body),
    bodyMedium: role(body, FontWeight.w400, 20 / body),
    bodySmall: role(caption, FontWeight.w400, 16 / caption),
    labelLarge: role(body, FontWeight.w600, 20 / body),
    labelMedium: role(caption),
    labelSmall: role(micro),
  );
}
