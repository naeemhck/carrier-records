import 'package:flutter/material.dart';

import 'bilingual_message.dart';
import 'owned_presentation.dart';

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
      overflow: overflow,
      softWrap: softWrap,
    );
    if (text.ur.isEmpty) return english;
    return Semantics(
      label: '${text.en}. ${text.ur}',
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 2,
        children: [
          english,
          Text(
            text.ur,
            style: (urStyle ?? style ?? const TextStyle()).copyWith(
              fontFamily: 'NotoSansArabic',
              fontFamilyFallback: const ['NotoSans', 'NotoSansMath'],
              height: 1.6,
            ),
            textAlign: textAlign ?? TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: maxLines,
            overflow: overflow,
            softWrap: softWrap,
          ),
        ],
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
        Text(text.en, style: style, textDirection: TextDirection.ltr),
        if (text.ur.isNotEmpty)
          Text(
            text.ur,
            style: (style ?? const TextStyle()).copyWith(
              fontFamily: 'NotoSansArabic',
              fontFamilyFallback: const ['NotoSans', 'NotoSansMath'],
              height: 1.6,
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
            style: const TextStyle(
              fontFamily: 'NotoSansArabic',
              fontFamilyFallback: ['NotoSans', 'NotoSansMath'],
              height: 1.6,
            ),
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
  });
  final Widget? title, subtitle, leading, trailing;
  final VoidCallback? onTap;
  final bool? dense;
  final EdgeInsetsGeometry? contentPadding;
  final bool selected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final below = trailing != null && constraints.maxWidth < 600;
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
