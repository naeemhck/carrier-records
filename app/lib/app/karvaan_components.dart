import 'package:flutter/material.dart';

import 'bilingual.dart';
import 'karvaan_design.dart';

/// Shared redesign components (frontend plan §6). Every component here is
/// presentation-only: callers pass already-formatted strings and resolved
/// labels; nothing computes money or reads repositories.

/// One step of a [LedgerStrip]: a bilingual caption over a formatted figure.
class LedgerSegment {
  const LedgerSegment({required this.label, required this.formattedValue});
  final Bilingual label;
  final String formattedValue;
}

/// The ledger strip: fare → −commission → =net on the money surface, with
/// tabular figures and drawn arrow connectors (plan §5.4). Callers include
/// the sign in the formatted value ("− PKR 5,000.00", "= PKR 95,000.00").
class LedgerStrip extends StatelessWidget {
  const LedgerStrip({super.key, required this.segments});
  final List<LedgerSegment> segments;
  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KarvaanDesign.moneySurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0)
              const Icon(
                Icons.arrow_forward,
                size: 18,
                color: KarvaanDesign.secondary,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                KarvaanFigure(
                  segments[i].formattedValue,
                  style: type.headlineSmall,
                ),
                const SizedBox(height: 4),
                BilingualText(segments[i].label, style: type.bodySmall),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Event kinds for [TimelineFeed]; dot colors are fixed by the plan (§5.4):
/// create = muted, dispatch = blue, money = green, edit = amber.
enum TimelineKind { create, dispatch, money, edit, other }

class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.title,
    this.actor = '',
    this.timestamp = '',
    this.note,
    this.details = const [],
  });
  final TimelineKind kind;
  final Bilingual title;
  final String actor;
  final String timestamp;

  /// One short line under the title (an event reason, or "no changes").
  final Bilingual? note;
  final List<Widget> details;

  Color get dotColor => switch (kind) {
    TimelineKind.create => KarvaanDesign.secondary,
    TimelineKind.dispatch => KarvaanDesign.primary,
    TimelineKind.money => KarvaanDesign.money,
    TimelineKind.edit => KarvaanDesign.attention,
    TimelineKind.other => KarvaanDesign.secondary,
  };
}

/// A vertical timeline of plain-language events (plan §5.4): colored dot,
/// title, actor and short timestamp, with field-level detail collapsed
/// under a per-entry "Details" expander. Never renders raw payloads.
class TimelineFeed extends StatelessWidget {
  const TimelineFeed({super.key, required this.entries});
  final List<TimelineEntry> entries;
  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                        color: entries[i].dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < entries.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: KarvaanDesign.borderColor,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < entries.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BilingualText(entries[i].title, style: type.labelLarge),
                        if (entries[i].note != null)
                          BilingualText(
                            entries[i].note!,
                            style: type.bodyMedium,
                          ),
                        if (entries[i].actor.isNotEmpty ||
                            entries[i].timestamp.isNotEmpty)
                          Text(
                            [
                              entries[i].actor,
                              entries[i].timestamp,
                            ].where((s) => s.isNotEmpty).join(' · '),
                            textDirection: TextDirection.ltr,
                            style: type.bodySmall?.copyWith(
                              color: KarvaanDesign.secondary,
                            ),
                          ),
                        if (entries[i].details.isNotEmpty)
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: const BilingualCaption(L10n.details),
                            children: entries[i].details,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One line plus one action (plan §6). No paragraphs, ever.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
  });
  final Bilingual message;
  final Bilingual? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 32, color: KarvaanDesign.secondary),
          const SizedBox(height: 12),
        ],
        BilingualText(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onAction,
            child: BilingualCaption(actionLabel!),
          ),
        ],
      ],
    ),
  );
}

/// The app's one data-table wrapper (plan §6): muted header, theme tabular
/// figures, horizontal scroll at narrow widths.
class KarvaanDataTable extends StatelessWidget {
  const KarvaanDataTable({
    super.key,
    required this.columns,
    required this.rows,
  });
  final List<DataColumn> columns;
  final List<DataRow> rows;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      headingRowColor: const WidgetStatePropertyAll(KarvaanDesign.muted),
      // Stacked bilingual headers and status chips are taller than the
      // Material default row heights; let rows size to their content.
      headingRowHeight: 64,
      dataRowMinHeight: 52,
      dataRowMaxHeight: double.infinity,
      columns: columns,
      rows: rows,
    ),
  );
}

/// Standard layout for a screen's filter controls (plan §6 FilterBar).
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}

/// Destructive and consequential actions always confirm (plan §5.9/§6).
/// Returns true only when the user confirms.
Future<bool> showKarvaanConfirm(
  BuildContext context, {
  required Bilingual title,
  required Bilingual message,
  required Bilingual confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
    builder: (context) => AlertDialog(
      title: BilingualText(title),
      content: BilingualText(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const BilingualCaption(L10n.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: KarvaanDesign.destructive,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: BilingualCaption(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
