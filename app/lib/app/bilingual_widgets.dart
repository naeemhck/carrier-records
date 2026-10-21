import 'package:flutter/material.dart';

import 'bilingual_message.dart';
import 'language_mode.dart';
import 'owned_presentation.dart';
import 'karvaan_typography.dart';

/// Urdu runs never inherit Material's Latin line height, which compresses
/// Urdu ink into adjacent labels, especially at 200%. Plan §2.2: headings
/// render in Noto Nastaliq Urdu (keeping that font's naturally tall metrics),
/// body and labels in Noto Naskh Arabic at the plan's 14/26 leading. The
/// bundled Noto Sans Arabic remains the offline/test fallback.
TextStyle _urduStyle(BuildContext context, TextStyle? requested) {
  final base = DefaultTextStyle.of(context).style.merge(requested);
  final size = (base.fontSize ?? KarvaanTypography.body).clamp(
    KarvaanTypography.urduMinimum,
    double.infinity,
  );
  final display = size >= KarvaanTypography.title;
  return TextStyle(
    inherit: false,
    fontFamily: display
        ? KarvaanTypography.urduDisplayFamily
        : KarvaanTypography.urduBodyFamily,
    fontFamilyFallback: KarvaanTypography.urduFallback,
    fontSize: size,
    height: display ? null : 26 / 14,
    fontWeight: base.fontWeight ?? FontWeight.w400,
    fontFeatures: KarvaanTypography.figureFeatures,
    color: base.color,
    backgroundColor: base.backgroundColor,
    decoration: base.decoration,
    decorationColor: base.decorationColor,
    decorationStyle: base.decorationStyle,
    decorationThickness: base.decorationThickness,
  );
}

/// Public entry to the Urdu run styling (see [_urduStyle]); the language
/// switch labels its Urdu segment with it.
TextStyle karvaanUrduStyle(BuildContext context, TextStyle? requested) =>
    _urduStyle(context, requested);

/// Intrinsic-safe wrapping in dialogs/tables; RTL only for the Urdu run.
///
/// Renders per the app-wide [KarvaanLanguageMode]: English only, Urdu only,
/// or the stacked pair (the default). Layout stays LTR in every mode.
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
  });
  final Bilingual text;
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
        style: _urduStyle(context, urStyle ?? style),
        textAlign: textAlign ?? TextAlign.right,
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
      return Semantics(
        label: '${text.en}. ${text.ur}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [english, urdu],
        ),
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
      final urdu = _urduStyle(context, latin);
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
                TextSpan(text: ': $valueText'),
              ],
              KarvaanLanguageMode.bilingual => [
                TextSpan(text: label.en),
                const TextSpan(text: ' / '),
                TextSpan(text: label.ur, style: urdu),
                TextSpan(text: ': ${value.en}'),
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
      return Semantics(
        label: '${text.en}. ${text.ur}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            english,
            Text(
              text.ur,
              style: _urduStyle(context, effective),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ],
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

/// Material's floating-label slot is single-line. Keep native English label
/// behavior and place its complete Urdu companion in the wrapping helper slot.
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
  // The Urdu companion line rides in the helper slot only in bilingual
  // mode; single-language modes keep the field to one line (density pass).
  if (LanguageModeStore.instance.mode.value != KarvaanLanguageMode.bilingual) {
    return source.copyWith(label: BilingualFloatingLabel(message));
  }
  return source.copyWith(
    label: BilingualFloatingLabel(message),
    helper: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(
            message.ur,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: _urduStyle(context, Theme.of(context).textTheme.bodySmall),
          ),
        ),
        ?source.helper,
      ],
    ),
  );
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
      final urduStyle = _urduStyle(context, base);
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
  final urduHeight = measure(
    title.ur,
    _urduStyle(context, style),
    TextDirection.rtl,
  );
  if (mode == KarvaanLanguageMode.urdu) {
    return (urduHeight + 16).clamp(
      56 * MediaQuery.textScalerOf(context).scale(1),
      double.infinity,
    );
  }
  return (englishHeight + urduHeight + 16).clamp(
    88 * MediaQuery.textScalerOf(context).scale(1),
    double.infinity,
  );
}
