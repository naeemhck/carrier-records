import 'package:flutter/material.dart';

import 'bilingual_message.dart';
import 'language_mode.dart';
import 'owned_presentation.dart';
import 'karvaan_typography.dart';

/// Urdu runs never inherit Material's Latin line height, which compresses
/// Urdu ink into adjacent labels, especially at 200%.
///
/// A [companion] run accompanies English in bilingual mode: it is sized
/// from that English (never larger than it, within the typography bounds),
/// regular weight and a quieter tint of the same color, so the pair reads
/// as one label with its translation instead of two competing lines. A
/// primary run (Urdu-only mode) keeps the requested size, weight and color.
///
/// The tint stays at [_companionTint] so the quietest text color in the
/// app still clears 4.5:1 against the page background. Action captions
/// pass [tinted] false: a button label keeps the button's own foreground.
///
/// No line height is forced: the script's natural ascent and descent are
/// what keep its marks from being cut off at a panel edge.
TextStyle _urduStyle(
  BuildContext context,
  TextStyle? requested, {
  bool companion = false,
  bool tinted = true,
}) {
  final base = DefaultTextStyle.of(context).style.merge(requested);
  final latin = base.fontSize ?? KarvaanTypography.body;
  final size = companion
      ? (latin * KarvaanTypography.urduCompanionRatio).clamp(
          KarvaanTypography.urduMinimum,
          KarvaanTypography.urduCompanionMaximum,
        )
      : latin.clamp(KarvaanTypography.urduMinimum, double.infinity);
  final color = base.color;
  return TextStyle(
    inherit: false,
    fontFamily: KarvaanTypography.urduBodyFamily,
    fontFamilyFallback: KarvaanTypography.urduFallback,
    fontSize: size,
    fontWeight: companion
        ? FontWeight.w400
        : base.fontWeight ?? FontWeight.w400,
    fontFeatures: KarvaanTypography.figureFeatures,
    color: companion && tinted && color != null
        ? color.withValues(alpha: _companionTint)
        : color,
    backgroundColor: base.backgroundColor,
    decoration: base.decoration,
    decorationColor: base.decorationColor,
    decorationStyle: base.decorationStyle,
    decorationThickness: base.decorationThickness,
  );
}

const _companionTint = 0.85;

/// Public entry to the Urdu run styling (see [_urduStyle]); the language
/// switch labels its Urdu segment with it.
TextStyle karvaanUrduStyle(
  BuildContext context,
  TextStyle? requested, {
  bool companion = false,
}) => _urduStyle(context, requested, companion: companion);

/// The bilingual pair: English, then its Urdu companion on the same line.
/// When both do not fit the available width the Urdu drops beneath the
/// English, so a short label costs one line and only a long sentence costs
/// two. [Wrap] keeps this intrinsic-safe for dialogs. The pair stacks
/// instead where a side-by-side pair would only take width that is not
/// there: inside a [DataTable] cell (unbounded, so it would widen every
/// column) and on phone-width windows (buttons in a row would overflow).
Widget _bilingualPair(
  BuildContext context, {
  required Bilingual text,
  required Widget english,
  required Widget urdu,
  TextAlign? textAlign,
  bool? stacked,
}) {
  stacked ??=
      context.findAncestorWidgetOfExactType<DataTable>() != null ||
      MediaQuery.sizeOf(context).width < 600;
  return Semantics(
    label: '${text.en}. ${text.ur}',
    excludeSemantics: true,
    child: stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [english, urdu],
          )
        : Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: switch (textAlign) {
              TextAlign.center => WrapAlignment.center,
              TextAlign.right || TextAlign.end => WrapAlignment.end,
              _ => WrapAlignment.start,
            },
            children: [english, urdu],
          ),
  );
}

/// Intrinsic-safe wrapping in dialogs/tables; RTL only for the Urdu run.
///
/// Renders per the app-wide [KarvaanLanguageMode]: English only, Urdu only,
/// or English with its quieter Urdu companion (the default). Layout stays
/// LTR in every mode.
class BilingualText extends StatelessWidget {
  const BilingualText(
    this.text, {
    super.key,
    this.style,
    this.urStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.stacked,
  });
  final Bilingual text;

  /// Forces the pair beside each other (false) or stacked (true). Null
  /// chooses: beside each other, except inside a [DataTable].
  final bool? stacked;
  final TextStyle? style, urStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) {
      final english = Text(
        text.en,
        style: style,
        textAlign: textAlign ?? TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
        softWrap: softWrap ?? true,
      );
      if (text.ur.isEmpty || mode == KarvaanLanguageMode.english) {
        return english;
      }
      final urdu = Text(
        text.ur,
        style: _urduStyle(context, urStyle ?? style, companion: true),
        textAlign: textAlign ?? TextAlign.left,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
        softWrap: softWrap ?? true,
      );
      if (mode == KarvaanLanguageMode.urdu) {
        // The layout stays LTR; only the run itself is Urdu.
        return Semantics(
          label: '${text.en}. ${text.ur}',
          excludeSemantics: true,
          child: Text(
            text.ur,
            style: _urduStyle(context, urStyle ?? style),
            textAlign: textAlign ?? TextAlign.left,
            textDirection: TextDirection.rtl,
            maxLines: maxLines,
            overflow: overflow ?? TextOverflow.clip,
            softWrap: softWrap ?? true,
          ),
        );
      }
      return _bilingualPair(
        context,
        text: text,
        english: english,
        urdu: urdu,
        textAlign: textAlign,
        stacked: stacked,
      );
    },
  );
}

/// One-line bilingual label/value row: "English / اردو: value", overall LTR.
/// Used where a stacked EN/UR pair would only repeat the same fact twice.
/// Values stay in place; only the label is translated. Pass Bilingual.data
/// for opaque values (names, amounts, identifiers) that have no Urdu form.
class BilingualInlineLine extends StatelessWidget {
  const BilingualInlineLine(
    this.label, {
    super.key,
    required this.value,
    this.style,
  });
  final Bilingual label;
  final Bilingual value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) {
      final latin = style ?? DefaultTextStyle.of(context).style;
      final urdu = _urduStyle(
        context,
        latin,
        companion: mode == KarvaanLanguageMode.bilingual,
      );
      final valueText = switch (mode) {
        KarvaanLanguageMode.urdu when value.ur.isNotEmpty => value.ur,
        _ => value.en,
      };
      return Semantics(
        label: '${label.en}. ${label.ur}: ${value.en}',
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(
            children: switch (mode) {
              KarvaanLanguageMode.english => [
                TextSpan(text: label.en),
                TextSpan(text: ': $valueText'),
              ],
              KarvaanLanguageMode.urdu => [
                if (label.ur.isNotEmpty)
                  TextSpan(text: label.ur, style: urdu)
                else
                  TextSpan(text: label.en),
                TextSpan(text: '\u200E: $valueText'),
              ],
              KarvaanLanguageMode.bilingual => [
                TextSpan(text: label.en),
                const TextSpan(text: ' / '),
                TextSpan(text: label.ur, style: urdu),
                // The mark keeps a date or amount that follows the Urdu
                // label in its own left-to-right order.
                TextSpan(text: '\u200E: ${value.en}'),
                if (value.ur.isNotEmpty)
                  TextSpan(text: ' / ${value.ur}', style: urdu),
              ],
            },
          ),
          style: latin,
          textDirection: TextDirection.ltr,
        ),
      );
    },
  );
}

class BilingualCaption extends StatelessWidget {
  const BilingualCaption(this.text, {super.key, this.style});
  final Bilingual text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) {
      final effective = style ?? KarvaanTypography.textTheme.bodySmall;
      final english = Text(
        text.en,
        style: effective,
        textDirection: TextDirection.ltr,
      );
      if (text.ur.isEmpty || mode == KarvaanLanguageMode.english) {
        return Semantics(
          label: '${text.en}. ${text.ur}',
          excludeSemantics: true,
          child: english,
        );
      }
      if (mode == KarvaanLanguageMode.urdu) {
        return Semantics(
          label: '${text.en}. ${text.ur}',
          excludeSemantics: true,
          child: Text(
            text.ur,
            style: _urduStyle(context, effective),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.left,
          ),
        );
      }
      return _bilingualPair(
        context,
        text: text,
        english: english,
        urdu: Text(
          text.ur,
          style: _urduStyle(context, effective, companion: true, tinted: false),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.left,
        ),
      );
    },
  );
}

/// Only source-owned labels/mapped safe errors; never operational names.
class BilingualOwnedText extends StatelessWidget {
  const BilingualOwnedText(this.source, {super.key, this.style});
  final Object? source;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) =>
      BilingualText(ownedMessage(source), style: style);
}

class BilingualOwnedCaption extends StatelessWidget {
  const BilingualOwnedCaption(this.source, {super.key, this.style});
  final Object? source;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) =>
      BilingualCaption(ownedMessage(source), style: style);
}

class BilingualFloatingLabel extends StatelessWidget {
  const BilingualFloatingLabel(this.message, {super.key});
  final Bilingual message;
  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) => Tooltip(
      message: message.inMode(mode),
      child: Semantics(
        label: '${message.en}. ${message.ur}',
        excludeSemantics: true,
        child: mode == KarvaanLanguageMode.urdu && message.ur.isNotEmpty
            ? Text(
                message.ur,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.rtl,
                style: _urduStyle(context, null),
              )
            : mode == KarvaanLanguageMode.bilingual && message.ur.isNotEmpty
            // One line in the field's own label slot: the English label
            // with its Urdu companion, instead of a second helper line
            // under every field. The tooltip carries the full pair if a
            // narrow field has to ellipsize it.
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      message.en,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      message.ur,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: _urduStyle(context, null, companion: true),
                    ),
                  ),
                ],
              )
            : Text(
                message.en,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
              ),
      ),
    ),
  );
}

/// Material's floating-label slot is single-line: the label carries the
/// English and its Urdu companion together on that line in bilingual mode.
/// The primary label supplies both languages to assistive technology.
InputDecoration bilingualDecoration(
  BuildContext context,
  InputDecoration source,
) {
  final label = source.label;
  final Bilingual? message = label is BilingualCaption
      ? label.text
      : label is BilingualOwnedCaption
      ? ownedMessage(label.source)
      : null;
  if (message == null || message.ur.isEmpty) return source;
  // Every mode keeps the field to one label line (GUI refresh): the Urdu
  // companion no longer rides in a helper row beneath each field.
  return source.copyWith(label: BilingualFloatingLabel(message));
}

/// Put multiline actions below the title when narrow rather than consuming
/// its width. The underlying ListTile preserves normal hit targets/semantics.
class BilingualListTile extends StatelessWidget {
  const BilingualListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.dense,
    this.contentPadding,
    this.selected = false,
    this.trailingBelow = false,
  });
  final Widget? title, subtitle, leading, trailing;
  final VoidCallback? onTap;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool selected;
  // Two-line actions can exceed ListTile's 40px trailing limit even when wide.
  final bool trailingBelow;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final below =
          trailing != null && (trailingBelow || constraints.maxWidth < 600);
      return ListTile(
        title: title,
        leading: leading,
        onTap: onTap,
        dense: dense,
        contentPadding: contentPadding,
        selected: selected,
        trailing: below || trailing == null
            ? null
            : ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.4,
                ),
                child: trailing,
              ),
        subtitle: below
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?subtitle,
                  Align(alignment: Alignment.centerLeft, child: trailing),
                ],
              )
            : subtitle,
      );
    },
  );
}

/// Spatial order is authoritative even when either office name is Urdu.
/// Names remain opaque; direction controls never enter records or requests.
class RouteLabel extends StatelessWidget {
  const RouteLabel({
    super.key,
    required this.origin,
    required this.destination,
  });
  final String origin, destination;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$origin → $destination',
    textDirection: TextDirection.ltr,
    excludeSemantics: true,
    child: Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: Text(origin, textDirection: TextDirection.ltr)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('→', textDirection: TextDirection.ltr),
        ),
        Flexible(child: Text(destination, textDirection: TextDirection.ltr)),
      ],
    ),
  );
}

/// One-line screen title for the single shell header row (header
/// compaction pass): in bilingual mode the English and Urdu runs sit on
/// the SAME line at the owner's 20px heading size instead of stacking
/// into a two-line title block. The pair is measured first; when both
/// runs cannot fit the available width at natural size (very narrow
/// screens, 200% text), the title falls back to the stacked pair so the
/// header grows rather than clipping. Layout stays LTR; only the Urdu
/// run itself is RTL.
class BilingualHeaderTitle extends StatelessWidget {
  const BilingualHeaderTitle(this.text, {super.key, this.style});
  final Bilingual text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => LanguageModeBuilder(
    builder: (context, mode) {
      final base =
          style ??
          Theme.of(context).textTheme.headlineSmall ??
          const TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
      final english = Text(
        text.en,
        style: base,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      );
      if (text.ur.isEmpty || mode == KarvaanLanguageMode.english) {
        return english;
      }
      final urduStyle = _urduStyle(
        context,
        base,
        companion: mode == KarvaanLanguageMode.bilingual,
      );
      if (mode == KarvaanLanguageMode.urdu) {
        return Semantics(
          label: '${text.en}. ${text.ur}',
          excludeSemantics: true,
          child: Text(
            text.ur,
            style: urduStyle,
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedWidth && constraints.maxWidth < 64) {
            // Degenerate sliver (can occur transiently in dense bars):
            // one ellipsized English line, never a vertical explosion.
            return english;
          }
          double measure(String value, TextStyle s, TextDirection dir) {
            final painter = TextPainter(
              text: TextSpan(text: value, style: s),
              textDirection: dir,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final fits =
              !constraints.hasBoundedWidth ||
              measure(text.en, base, TextDirection.ltr) +
                      12 +
                      measure(text.ur, urduStyle, TextDirection.rtl) <=
                  constraints.maxWidth;
          if (!fits) {
            // Grow, never clip — but bounded: the stacked pair, each run
            // on its own single line, fitted down when the pair is wider
            // than the slot (long titles on phone widths). Two lines at
            // most, so the header grows to ~2 line-heights, never to a
            // wrapped paragraph.
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text.en,
                    style: base,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    softWrap: false,
                  ),
                  Text(
                    text.ur,
                    style: urduStyle,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            );
          }
          return Semantics(
            label: '${text.en}. ${text.ur}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: english),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    text.ur,
                    style: urduStyle,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Measure the same wrapping styles used by a complete stacked toolbar title.
/// The caller supplies actual parent width after navigation/action reservations.
double bilingualToolbarHeight(
  BuildContext context,
  Bilingual title,
  double availableWidth,
) {
  final style = Theme.of(context).textTheme.titleLarge!;
  double measure(String text, TextStyle textStyle, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: direction,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: availableWidth.clamp(1, double.infinity));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final mode = LanguageModeStore.instance.mode.value;
  final englishHeight = measure(
    title.en,
    style.copyWith(fontWeight: FontWeight.w600),
    TextDirection.ltr,
  );
  if (mode == KarvaanLanguageMode.english || title.ur.isEmpty) {
    return (englishHeight + 16).clamp(
      56 * MediaQuery.textScalerOf(context).scale(1),
      double.infinity,
    );
  }
  final urduStyle = _urduStyle(
    context,
    style,
    companion: mode == KarvaanLanguageMode.bilingual,
  );
  final urduHeight = measure(title.ur, urduStyle, TextDirection.rtl);
  final minimum = 56 * MediaQuery.textScalerOf(context).scale(1);
  if (mode == KarvaanLanguageMode.urdu) {
    return (urduHeight + 16).clamp(minimum, double.infinity);
  }
  // The pair shares one line when it fits beside each other; otherwise the
  // Urdu drops beneath the English and the toolbar grows to hold both.
  double width(String text, TextStyle textStyle, TextDirection direction) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: direction,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final result = painter.width;
    painter.dispose();
    return result;
  }

  final sideBySide =
      width(
            title.en,
            style.copyWith(fontWeight: FontWeight.w600),
            TextDirection.ltr,
          ) +
          8 +
          width(title.ur, urduStyle, TextDirection.rtl) <=
      availableWidth;
  return ((sideBySide
              ? (englishHeight > urduHeight ? englishHeight : urduHeight)
              : englishHeight + urduHeight) +
          16)
      .clamp(minimum, double.infinity);
}
