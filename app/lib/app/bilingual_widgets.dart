import 'package:flutter/material.dart';

import 'bilingual_message.dart';
import 'owned_presentation.dart';
import 'karvaan_typography.dart';

/// Use the bundled font's natural ascent/descent. Inheriting Material's Latin
/// line height compresses Urdu ink into adjacent labels, especially at 200%.
TextStyle _urduStyle(BuildContext context, TextStyle? requested) {
  final base = DefaultTextStyle.of(context).style.merge(requested);
  return TextStyle(
    inherit: false,
    fontFamily: 'NotoSansArabic',
    fontFamilyFallback: const ['NotoSans', 'NotoSansMath'],
    fontSize: (base.fontSize ?? KarvaanTypography.body).clamp(
      KarvaanTypography.urduMinimum,
      double.infinity,
    ),
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

/// Intrinsic-safe wrapping in dialogs/tables; RTL only for the Urdu run.
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
  Widget build(BuildContext context) {
    final english = Text(
      text.en,
      style: style,
      textAlign: textAlign ?? TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      softWrap: softWrap ?? true,
    );
    if (text.ur.isEmpty) return english;
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
            style: _urduStyle(context, urStyle ?? style),
            textAlign: textAlign ?? TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: maxLines,
            overflow: overflow ?? TextOverflow.clip,
            softWrap: softWrap ?? true,
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final latin = style ?? DefaultTextStyle.of(context).style;
    final urdu = _urduStyle(context, latin);
    return Semantics(
      label: '${label.en}. ${label.ur}: ${value.en}',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label.en),
            const TextSpan(text: ' / '),
            TextSpan(text: label.ur, style: urdu),
            TextSpan(text: ': ${value.en}'),
            if (value.ur.isNotEmpty)
              TextSpan(text: ' / ${value.ur}', style: urdu),
          ],
        ),
        style: latin,
        textDirection: TextDirection.ltr,
      ),
    );
  }
}

class BilingualCaption extends StatelessWidget {
  const BilingualCaption(this.text, {super.key, this.style});
  final Bilingual text;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${text.en}. ${text.ur}',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.en,
          style: style ?? KarvaanTypography.textTheme.bodySmall,
          textDirection: TextDirection.ltr,
        ),
        if (text.ur.isNotEmpty)
          Text(
            text.ur,
            style: _urduStyle(
              context,
              style ?? KarvaanTypography.textTheme.bodySmall,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
      ],
    ),
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
  Widget build(BuildContext context) => Tooltip(
    message: message.inline,
    child: Semantics(
      label: '${message.en}. ${message.ur}',
      excludeSemantics: true,
      child: Text(
        message.en,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
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

  return (measure(
            title.en,
            style.copyWith(fontWeight: FontWeight.w600),
            TextDirection.ltr,
          ) +
          measure(title.ur, _urduStyle(context, style), TextDirection.rtl) +
          16)
      .clamp(88 * MediaQuery.textScalerOf(context).scale(1), double.infinity);
}
