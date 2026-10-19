import 'package:flutter/material.dart';

/// Logical-pixel UI scale. Printed/snapshot typography is intentionally separate.
abstract final class KarvaanTypography {
  static const display = 30.0;
  static const headline = 22.0;
  static const title = 16.0;
  static const body = 13.0;
  static const caption = 12.0;
  static const micro = 11.0;
  // 11 typographic points at 96 logical pixels/inch. Never scale Urdu down
  // to the Latin caption/micro size; accessibility scaling remains unrestricted.
  static const urduMinimum = 44.0 / 3;

  static const screenTitle = TextStyle(
    fontSize: headline,
    fontWeight: FontWeight.w600,
  );
  static const sectionTitle = TextStyle(
    fontSize: title,
    fontWeight: FontWeight.w600,
  );
  static const bodyStyle = TextStyle(fontSize: body);
  static const figureFeatures = [FontFeature.tabularFigures()];
  static TextStyle role(double size, [FontWeight weight = FontWeight.w400]) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFeatures: figureFeatures,
      );

  static TextTheme get textTheme => TextTheme(
    displayLarge: role(display, FontWeight.w700),
    displayMedium: role(display, FontWeight.w700),
    displaySmall: role(display, FontWeight.w700),
    headlineLarge: role(headline, FontWeight.w600),
    headlineMedium: role(headline, FontWeight.w600),
    headlineSmall: role(20, FontWeight.w600),
    titleLarge: role(headline, FontWeight.w600),
    titleMedium: role(title, FontWeight.w600),
    titleSmall: role(15, FontWeight.w600),
    bodyLarge: role(body),
    bodyMedium: role(body),
    bodySmall: role(caption),
    labelLarge: role(body, FontWeight.w600),
    labelMedium: role(caption),
    labelSmall: role(micro),
  );
}
