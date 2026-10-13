import 'package:carrier_records/app/bilingual.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool hasEnglishLabel(InputDecoration? decoration, String label) {
  if (decoration?.labelText == label) return true;
  final widget = decoration?.label;
  if (widget is BilingualCaption) return widget.text.en == label;
  if (widget is BilingualOwnedCaption) {
    return ownedMessage(widget.source).en == label;
  }
  if (widget is BilingualFloatingLabel) return widget.message.en == label;
  return false;
}

Finder englishTextContaining(Pattern pattern) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.textDirection != TextDirection.rtl &&
      (widget.data ?? widget.textSpan?.toPlainText() ?? '').contains(pattern),
);

String? englishWidgetLabel(Widget widget) {
  if (widget is SizedBox && widget.child != null) {
    return englishWidgetLabel(widget.child!);
  }
  if (widget is Text) return widget.data;
  if (widget is BilingualText) return widget.text.en;
  if (widget is BilingualCaption) return widget.text.en;
  if (widget is BilingualOwnedText) return ownedMessage(widget.source).en;
  if (widget is BilingualOwnedCaption) return ownedMessage(widget.source).en;
  return null;
}
