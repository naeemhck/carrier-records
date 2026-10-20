import 'package:flutter/material.dart';

import '../../app/bilingual.dart';
import '../../app/karvaan_components.dart';
import '../../app/karvaan_design.dart';
import '../../app/karvaan_patterns.dart';
import '../reports/report_repository.dart';
import 'financial_repository.dart' show LedgerAmount;

/// Balances-first Money workspace (plan §5.5): three balance summaries over
/// a party balances table. The money questions are about parties, not trips;
/// trip-level work stays one tap away via "View trips", which opens the
/// existing money-mode trip list. Presentation only — all figures come from
/// the existing report reads; nothing is computed here beyond zero checks.
class MoneyWorkspace extends StatefulWidget {
  const MoneyWorkspace({
    super.key,
    required this.reports,
    required this.onViewTrips,
  });
  final ReportCommands reports;
  final VoidCallback onViewTrips;
  @override
  State<MoneyWorkspace> createState() => _MoneyWorkspaceState();
}

class _MoneyWorkspaceState extends State<MoneyWorkspace> {
  late Future<Map<String, dynamic>> monthly;
  late Future<Map<String, dynamic>> claims;

  Map<String, dynamic> get _filters {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final from = '${now.year}-${two(now.month)}-01';
    final to = DateTime(
      now.year,
      now.month + 1,
      0,
    ).toIso8601String().substring(0, 10);
    return {
      'from': from,
      'to': to,
      'office_id': null,
      'vehicle_id': null,
      'owner_id': null,
      'trip_id': null,
      'search': '',
    };
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    monthly = widget.reports.report('MONTHLY_VEHICLE', _filters);
    claims = widget.reports.report('CLAIMS', _filters);
  }

  void reload() => setState(_load);

  bool _nonZero(Object? amount) {
    if (amount == null) return false;
    try {
      return LedgerAmount.fromJson(amount).paisa != BigInt.zero;
    } on FormatException {
      return false;
    }
  }

  Widget _band(Map<String, dynamic> totals, double cardWidth) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final (label, key) in [
        (L10n.customerOutstanding, 'customer_outstanding'),
        (L10n.settlementsDue, 'owner_due'),
        (L10n.moneyHeld, 'custody'),
      ])
        SizedBox(
          width: cardWidth,
          child: KpiCard(
            label: label,
            figure: displayField('MONEY', totals[key]),
          ),
        ),
    ],
  );

  Widget _partyTable() => FutureBuilder<Map<String, dynamic>>(
    future: claims,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (s.hasError || !s.hasData) {
        return const BilingualText(
          L10n.reportUnavailableCheckDatesTripSelectionAndCurrentOffice,
        );
      }
      final rows = [
        for (final r in (s.data!['rows'] as List? ?? []))
          if (r is Map &&
              (_nonZero((r['values'] as Map?)?['customer_outstanding']) ||
                  _nonZero((r['values'] as Map?)?['owner_due']) ||
                  _nonZero((r['values'] as Map?)?['custody'])))
            r,
      ];
      if (rows.isEmpty) {
        return const EmptyState(message: L10n.noRecordsInThisPeriodScope);
      }
      return SingleChildScrollView(
        child: KarvaanDataTable(
          columns: const [
            DataColumn(label: BilingualText(L10n.parties)),
            DataColumn(
              label: BilingualText(L10n.customerOutstanding),
              numeric: true,
            ),
            DataColumn(
              label: BilingualText(L10n.settlementsDue),
              numeric: true,
            ),
            DataColumn(label: BilingualText(L10n.moneyHeld), numeric: true),
          ],
          rows: [
            for (final r in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text((r['name'] ?? '').toString()),
                    onTap: widget.onViewTrips,
                  ),
                  for (final key in [
                    'customer_outstanding',
                    'owner_due',
                    'custody',
                  ])
                    DataCell(
                      KarvaanFigure(
                        displayField('MONEY', (r['values'] as Map?)?[key]),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88 * MediaQuery.textScalerOf(context).scale(1),
      title: const BilingualText(L10n.moneyNavigation),
      actions: [
        IconButton(
          onPressed: reload,
          icon: const Icon(Icons.refresh),
          tooltip: L10n.searchRefreshAccessibility,
        ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        // Desktop (plan §4): the page never scrolls — the party table owns
        // the remaining height and scrolls internally. Phone widths scroll
        // the page inside the fixed shell instead.
        final wide = constraints.maxWidth >= 760;
        final header = <Widget>[
          FutureBuilder<Map<String, dynamic>>(
            future: monthly,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator();
              }
              if (s.hasError || !s.hasData) {
                return const BilingualText(
                  L10n.reportUnavailableCheckDatesTripSelectionAndCurrentOffice,
                );
              }
              final totals = Map<String, dynamic>.from(
                s.data!['totals'] as Map,
              );
              final cardWidth = wide
                  ? (constraints.maxWidth - 32 - 24) / 3
                  : constraints.maxWidth - 32;
              return _band(totals, cardWidth);
            },
          ),
          const SizedBox(height: 8),
          const BilingualText(L10n.moneyWorkspacePurpose),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: widget.onViewTrips,
              child: const BilingualCaption(L10n.viewTrips),
            ),
          ),
          const SizedBox(height: 12),
          BilingualText(
            L10n.parties,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
        ];
        if (!wide) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...header,
              SizedBox(height: 420, child: _partyTable()),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...header,
              Expanded(child: _partyTable()),
            ],
          ),
        );
      },
    ),
  );
}
