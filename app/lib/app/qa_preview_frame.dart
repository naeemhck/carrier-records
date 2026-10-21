import 'package:flutter/material.dart';

/// Frame applied around the whole app in the QA preview build.
///
/// Owner directive (2026-10-21): the "Testing — synthetic data only"
/// banner is no longer pinned over the app. The frame stays in place as
/// a pass-through so the QA preview wiring in the app builder is
/// unchanged; it simply renders its child with nothing above it.
class QaPreviewFrame extends StatelessWidget {
  const QaPreviewFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
