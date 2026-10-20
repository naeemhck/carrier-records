import 'package:flutter/material.dart';

/// Logical-pixel UI scale. Printed/snapshot typography is intentionally separate.
///
/// Redesign tokens (frontend plan §2.2): Display 28/36, KPI figure 20/26,
/// Title 18/24, Body 14/20, Caption 12/16. Latin UI is Fira Sans, figures and
/// identifiers are Fira Code, Urdu headings are Noto Nastaliq Urdu and Urdu
/// body is Noto Naskh Arabic — all loaded via Google Fonts at app start, with
/// the bundled Noto fonts as the offline/test fallback.
abstract final class KarvaanTypography {
  static const display = 28.0;
  static const headline = 22.0;
  static const title = 18.0;
  static const body = 14.0;
  static const caption = 12.0;
  static const micro = 11.0;
  // 11 typographic points at 96 logical pixels/inch. Never scale Urdu down
  // to the Latin caption/micro size; accessibility scaling remains unrestricted.
  static const urduMinimum = 44.0 / 3;

  /// Google Fonts family names (no spaces), registered by the loaders in
  /// main(). Tests never run main(); they render through the fallbacks.
  static const latinFamily = 'FiraSans';
  static const figureFamily = 'FiraCode';
  static const urduDisplayFamily = 'NotoNastaliqUrdu';
  static const urduBodyFamily = 'NotoNaskhArabic';
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
