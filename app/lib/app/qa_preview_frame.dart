import 'karvaan_typography.dart';

import 'package:flutter/material.dart';

import 'bilingual.dart';

/// Always visible, including authentication and nested dialogs/routes.
class QaPreviewFrame extends StatelessWidget {
  const QaPreviewFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: const Color(0xFFFFF4E0),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: BilingualText(
                L10n.syntheticTestingPreview,
                style: KarvaanTypography.bodyStyle.copyWith(
                  color: const Color(0xFF713300),
                ),
              ),
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
