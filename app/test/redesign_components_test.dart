import 'package:carrier_records/app/bilingual.dart';
import 'package:carrier_records/app/karvaan_components.dart';
import 'package:carrier_records/app/karvaan_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the plan §6 component library behavior.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: KarvaanDesign.theme(),
    home: Scaffold(body: child),
  );

  testWidgets('ledger strip renders fare, commission and net in order', (
    t,
  ) async {
    t.view.physicalSize = const Size(1400, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      host(
        const LedgerStrip(
          segments: [
            LedgerSegment(
              label: L10n.agreedFare,
              formattedValue: 'PKR 100,000.00',
            ),
            LedgerSegment(
              label: L10n.brokerCommissionFixed,
              formattedValue: '− PKR 5,000.00',
            ),
            LedgerSegment(
              label: L10n.netOwnerShare,
              formattedValue: '= PKR 95,000.00',
            ),
          ],
        ),
      ),
    );
    final fare = t.getTopLeft(find.text('PKR 100,000.00'));
    final commission = t.getTopLeft(find.text('− PKR 5,000.00'));
    final net = t.getTopLeft(find.text('= PKR 95,000.00'));
    expect(commission.dx, greaterThan(fare.dx));
    expect(net.dx, greaterThan(commission.dx));
    expect(find.byIcon(Icons.arrow_forward), findsNWidgets(2));
    final box = t.widget<Container>(
      find
          .ancestor(
            of: find.text('PKR 100,000.00'),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, KarvaanDesign.moneySurface);
  });

  testWidgets('timeline feed colors dots by kind and collapses details', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        const TimelineFeed(
          entries: [
            TimelineEntry(
              kind: TimelineKind.dispatch,
              title: L10n.dispatched,
              actor: 'qa_khi',
              timestamp: '2026-10-15 23:27',
              details: [Text('Status: Draft → Dispatched')],
            ),
            TimelineEntry(
              kind: TimelineKind.money,
              title: L10n.payments,
              timestamp: '2026-10-15 23:28',
            ),
          ],
        ),
      ),
    );
    expect(find.text(L10n.dispatched.en), findsOneWidget);
    expect(find.text('qa_khi · 2026-10-15 23:27'), findsOneWidget);
    // Details stay collapsed until the entry is expanded.
    expect(find.text('Status: Draft → Dispatched'), findsNothing);
    final dots = t.widgetList<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(dots.length, 2);
    expect(
      (dots.first.decoration as BoxDecoration).color,
      KarvaanDesign.primary,
    );
    expect((dots.last.decoration as BoxDecoration).color, KarvaanDesign.money);
  });

  testWidgets('empty state shows one line and one action', (t) async {
    var tapped = false;
    await t.pumpWidget(
      host(
        EmptyState(
          message: L10n.noRecordsInThisPeriodScope,
          actionLabel: L10n.record,
          onAction: () => tapped = true,
        ),
      ),
    );
    expect(find.text(L10n.noRecordsInThisPeriodScope.en), findsOneWidget);
    await t.tap(find.text(L10n.record.en));
    expect(tapped, isTrue);
  });

  testWidgets('confirm dialog returns true only on confirm', (t) async {
    bool? result;
    await t.pumpWidget(
      host(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await showKarvaanConfirm(
                context,
                title: L10n.remove,
                message: L10n.noRecordsInThisPeriodScope,
                confirmLabel: L10n.remove,
                destructive: true,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.text(L10n.remove.en), findsWidgets);
    await t.tap(find.text(L10n.cancel.en));
    await t.pumpAndSettle();
    expect(result, isFalse);
  });

  testWidgets('data table renders bilingual headers and rows', (t) async {
    await t.pumpWidget(
      host(
        const KarvaanDataTable(
          columns: [
            DataColumn(label: BilingualText(L10n.parties)),
            DataColumn(label: BilingualText(L10n.customerOutstanding)),
          ],
          rows: [
            DataRow(
              cells: [
                DataCell(Text('Synthetic customer')),
                DataCell(Text('PKR 5,000.00')),
              ],
            ),
          ],
        ),
      ),
    );
    expect(find.text(L10n.parties.en), findsOneWidget);
    expect(find.text('Synthetic customer'), findsOneWidget);
    expect(find.text('PKR 5,000.00'), findsOneWidget);
  });
}
