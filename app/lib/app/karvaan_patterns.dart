import 'package:flutter/material.dart';

import 'bilingual.dart';
import 'karvaan_design.dart';
import 'karvaan_typography.dart';

/// Shared presentation patterns borrowed from the Super Dispatch / Odobase
/// reviews (see codex-prompt-addendum-competitor-ideas.md). Presentation
/// only: these widgets never compute totals or change navigation targets.
/// All text renders stacked bilingual per the branch convention; amounts use
/// Latin digits with tabular figures.

/// Origin pin (movement blue) -> dashed route line -> destination pin
/// (money green). Each leg carries a small caption (city, date, office).
/// Spatial order is authoritative: always LTR, like RouteLabel.
class TripRouteLine extends StatelessWidget {
  const TripRouteLine({
    super.key,
    required this.origin,
    required this.originMeta,
    required this.destination,
    required this.destinationMeta,
    this.stopDots = 0,
  });
  final String origin, originMeta, destination, destinationMeta;

  /// Intermediate stops drawn as small dots along the line (plan §5.4).
  final int stopDots;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        textDirection: TextDirection.ltr,
        children: [
          const Icon(Icons.location_on, color: KarvaanDesign.primary, size: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(height: 20, child: _DashedLine(stops: stopDots)),
            ),
          ),
          const Icon(Icons.location_on, color: KarvaanDesign.accent, size: 20),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  origin,
                  textDirection: TextDirection.ltr,
                  style: KarvaanTypography.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  originMeta,
                  textDirection: TextDirection.ltr,
                  style: KarvaanTypography.textTheme.bodySmall?.copyWith(
                    color: KarvaanDesign.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  destination,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: KarvaanTypography.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  destinationMeta,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: KarvaanTypography.textTheme.bodySmall?.copyWith(
                    color: KarvaanDesign.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({this.stops = 0});
  final int stops;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DashedLinePainter(stops), size: Size.infinite);
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.stops);
  final int stops;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = KarvaanDesign.secondary.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), paint);
      x += 11;
    }
    if (stops > 0) {
      final dot = Paint()..color = KarvaanDesign.secondary;
      for (var i = 1; i <= stops; i++) {
        canvas.drawCircle(Offset(size.width * i / (stops + 1), y), 3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.stops != stops;
}

/// One headline tabular figure with a quiet stacked caption and an optional
/// period tag. Tapping drills into the underlying filtered list. The live-state
/// (in-transit) card renders filled in movement blue — green is money only.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.figure,
    this.period,
    this.onTap,
    this.filled = false,
  });
  final Bilingual label;
  final String figure;
  final String? period;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final onFilled = Colors.white;
    final figureStyle = KarvaanTypography.textTheme.headlineSmall?.copyWith(
      color: filled ? onFilled : KarvaanDesign.ink,
    );
    final captionStyle = KarvaanTypography.textTheme.bodySmall?.copyWith(
      color: filled
          ? onFilled.withValues(alpha: 0.85)
          : KarvaanDesign.secondary,
    );
    return Card(
      color: filled ? KarvaanDesign.primary : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KarvaanFigure(figure, style: figureStyle),
                    const SizedBox(height: 4),
                    BilingualText(label, style: captionStyle),
                    if (period != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        period!,
                        style: KarvaanTypography.textTheme.labelSmall?.copyWith(
                          color: filled
                              ? onFilled.withValues(alpha: 0.7)
                              : KarvaanDesign.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward,
                  color: filled ? onFilled : KarvaanDesign.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Receivables aging bands. Tapping a band filters the table beneath it.
class AgingBand {
  const AgingBand({required this.label, required this.figure});
  final Bilingual label;
  final String figure;
}

class AgingBandStrip extends StatelessWidget {
  const AgingBandStrip({
    super.key,
    required this.bands,
    required this.selected,
    required this.onSelect,
  });
  final List<AgingBand> bands;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < bands.length; i++)
        ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KarvaanFigure(
                bands[i].figure,
                style: KarvaanTypography.textTheme.titleMedium?.copyWith(
                  color: i == selected
                      ? KarvaanDesign.accent
                      : KarvaanDesign.ink,
                ),
              ),
              BilingualText(
                bands[i].label,
                style: KarvaanTypography.textTheme.bodySmall?.copyWith(
                  color: KarvaanDesign.secondary,
                ),
              ),
            ],
          ),
          selected: i == selected,
          onSelected: (_) => onSelect(i),
          showCheckmark: false,
          selectedColor: KarvaanDesign.primarySurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: i == selected
                  ? KarvaanDesign.primary
                  : const Color(0x16000000),
            ),
          ),
        ),
    ],
  );
}

/// Tiny provenance caption: created / updated / dispatched stamps.
/// Metadata only — never a labeled row.
class TimestampFooter extends StatelessWidget {
  const TimestampFooter({
    super.key,
    this.created,
    this.updated,
    this.dispatched,
  });
  final String? created, updated, dispatched;
  Bilingual _stamp(Bilingual label, String value) => Bilingual(
    'pattern.stamp',
    '${label.en}: $value',
    // Isolate the Latin date so it renders as one LTR unit in the RTL line.
    '${label.ur}: \u2066$value\u2069',
  );
  @override
  Widget build(BuildContext context) {
    final stamps = [
      if (created != null && created!.isNotEmpty)
        _stamp(L10n.createdOn, created!),
      if (updated != null && updated!.isNotEmpty)
        _stamp(L10n.updatedOn, updated!),
      if (dispatched != null && dispatched!.isNotEmpty)
        _stamp(L10n.dispatchedOn, dispatched!),
    ];
    if (stamps.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: [
        for (final stamp in stamps)
          BilingualText(
            stamp,
            style: KarvaanTypography.textTheme.labelSmall?.copyWith(
              color: KarvaanDesign.secondary,
            ),
          ),
      ],
    );
  }
}

/// A money figure that deep-links to its source record (paper-trail rule).
/// The caller supplies the navigation target (usually the trip detail's
/// Money tab). Green marks the financial flow.
class PaperTrailAmount extends StatelessWidget {
  const PaperTrailAmount({
    super.key,
    required this.formatted,
    required this.onTap,
    this.style,
    this.semanticLabel,
  });
  final String formatted;
  final VoidCallback onTap;
  final TextStyle? style;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Semantics(
      button: true,
      label: semanticLabel ?? formatted,
      excludeSemantics: true,
      child: Text(
        formatted,
        textDirection: TextDirection.ltr,
        style: (style ?? KarvaanTypography.textTheme.headlineSmall)?.copyWith(
          color: KarvaanDesign.accent,
          fontFeatures: KarvaanTypography.figureFeatures,
        ),
      ),
    ),
  );
}
