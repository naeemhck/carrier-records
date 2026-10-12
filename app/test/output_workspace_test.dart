import 'dart:async';

import 'package:carrier_records/features/reports/output_repository.dart';
import 'package:carrier_records/features/reports/output_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'trip_workspace_test.dart' show FakeMasters, FakeTrips;

final outputCatalogue = {
  'fields': [
    for (final key in ['scope', 'period', 'generated_at', 'recipient_name'])
      {
        'field_key': key,
        'label': key,
        'field_group': 'Identity',
        'value_type': 'TEXT',
        'required': true,
        'header': true,
      },
    {
      'field_key': 'record_name',
      'label': 'Record',
      'field_group': 'Identity',
      'value_type': 'TEXT',
      'required': true,
      'header': false,
    },
    for (final entry in [
      ('owner_earnings', 'Owner fare share'),
      ('owner_cost', 'Owner-borne costs'),
      ('owner_profit', 'Owner profit'),
    ])
      {
        'field_key': entry.$1,
        'label': entry.$2,
        'field_group': entry.$1 == 'owner_cost' ? 'Expenses' : 'Balances',
        'value_type': 'MONEY',
        'required': false,
        'header': false,
      },
  ],
  'defaults': [
    'scope',
    'period',
    'generated_at',
    'recipient_name',
    'record_name',
    'owner_earnings',
    'owner_cost',
  ],
};

class OutputsFake implements OutputCommands {
  final requests = <String>[],
      bodies = <Map<String, dynamic>>[],
      preparations = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>> pending = Completer();
  @override
  Future<Map<String, dynamic>> catalogue(String r, String p) async =>
      Map.from(outputCatalogue);
  @override
  Future<List<Map<String, dynamic>>> presets(String r, String p) async => [];
  @override
  Future<Map<String, dynamic>> prepare(Map<String, dynamic> command) async {
    preparations.add(Map.from(command));
    final selected = (command['field_order'] as List).cast<String>();
    final fields = (outputCatalogue['fields'] as List)
        .cast<Map>()
        .where((f) => selected.contains(f['field_key']))
        .toList();
    return {
      'metadata': {
        'scope': 'Assigned-office records — not a complete business balance',
        'period': '2026-01-01 to 2026-04-30',
        'generated_at': 'now',
        'recipient_name': 'Internal',
        'date_bases': {'earnings': 'Dispatch date'},
      },
      'totals': {'owner_profit': '85000.00'},
      'summary_fields': [
        {'field_key': 'owner_profit', 'label': 'Owner profit'},
      ],
      'fields': fields,
      'rows': [
        {
          'record_name': 'Trip 1',
          'owner_earnings': '95000.00',
          'owner_cost': '10000.00',
          'owner_profit': '85000.00',
        },
      ],
      'page_offset': 0,
      'row_count': 1,
      'has_more': false,
    };
  }

  @override
  Future<Map<String, dynamic>> save(
    String id,
    String request,
    int version,
    Map<String, dynamic> p,
  ) {
    requests.add(request);
    bodies.add(Map.from(p));
    return pending.future;
  }

  @override
  Future<Map<String, dynamic>> delete(
    String id,
    String request,
    int version,
  ) async => {};
  @override
  Future<List<Map<String, dynamic>>> receipts(
    String recipient,
    String? party,
    Map<String, dynamic> f,
    int offset,
  ) async => [];
}

void main() {
  test(
    'Required fields, select all, defaults and ordering use server catalogue',
    () {
      final s = OutputSelection(Map.from(outputCatalogue));
      s.toggle('scope', false);
      expect(s.order.contains('scope'), isTrue);
      s.all();
      expect(s.order.contains('owner_profit'), isTrue);
      s.move(s.order.length - 1, -1);
      expect(s.order[s.order.length - 2], 'owner_profit');
      s.reset();
      expect(s.order, (outputCatalogue['defaults'] as List).cast<String>());
      expect(() => s.load([...s.order, 'brokerage']), throwsFormatException);
    },
  );
  testWidgets('Desktop configuration and preview remain visible together', (
    t,
  ) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: OutputWorkspace(
          commands: OutputsFake(),
          masters: FakeMasters(),
          trips: FakeTrips(),
          offices: const [],
          administrator: false,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Preview'));
    await t.tap(find.text('Preview'));
    await t.pumpAndSettle();
    expect(find.text('Authorized preview'), findsOneWidget);
    expect(find.text('Save named preset'), findsOneWidget);
    expect(find.text('Edit configuration'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Hidden expense column preserves filters and canonical preview total',
    (t) async {
      final fake = OutputsFake();
      await t.pumpWidget(
        MaterialApp(
          home: OutputWorkspace(
            commands: fake,
            masters: FakeMasters(),
            trips: FakeTrips(),
            offices: const [],
            administrator: false,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Preview'));
      await t.tap(find.text('Preview'));
      await t.pumpAndSettle();
      expect(find.text('Owner profit: 85000.00'), findsOneWidget);
      await t.tap(find.text('Edit configuration'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('field-owner_cost')));
      await t.tap(find.byKey(const ValueKey('field-owner_cost')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Preview'));
      await t.tap(find.text('Preview'));
      await t.pumpAndSettle();
      expect(fake.preparations.length, 2);
      expect(fake.preparations[0]['filters'], fake.preparations[1]['filters']);
      expect(
        fake.preparations[1]['field_order'],
        isNot(contains('owner_cost')),
      );
      expect(find.text('Owner profit: 85000.00'), findsOneWidget);
      final table = t.widget<DataTable>(find.byType(DataTable));
      expect(
        table.columns.where(
          (c) => (c.label as Text).data == 'Owner-borne costs',
        ),
        isEmpty,
      );
    },
  );
  testWidgets('Preset ambiguous retry keeps UUID and body until committed', (
    t,
  ) async {
    final fake = OutputsFake();
    await t.pumpWidget(
      MaterialApp(
        home: OutputWorkspace(
          commands: fake,
          masters: FakeMasters(),
          trips: FakeTrips(),
          offices: const [],
          administrator: false,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Save named preset'));
    await t.tap(find.text('Save named preset'));
    await t.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Preset name',
    );
    await t.enterText(field, 'Personal');
    await t.tap(find.text('Save preset'));
    await t.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(t.widget<TextField>(field).enabled, isFalse);
    fake.pending.completeError(Exception('Lost response'));
    await t.pumpAndSettle();
    fake.pending = Completer();
    await t.tap(find.text('Save preset'));
    await t.pump();
    expect(fake.requests[0], fake.requests[1]);
    expect(fake.bodies[0], fake.bodies[1]);
    fake.pending.complete({'id': 'preset', 'version': 1});
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets(
    'Current scope guard removes output preview and open preset form',
    (t) async {
      final allowed = ValueNotifier(true);
      final fake = OutputsFake();
      Widget guard(Widget child) => ValueListenableBuilder<bool>(
        valueListenable: allowed,
        builder: (_, value, _) => value
            ? child
            : const Scaffold(body: Text('Current access required')),
      );
      await t.pumpWidget(
        MaterialApp(
          home: guard(
            OutputWorkspace(
              commands: fake,
              masters: FakeMasters(),
              trips: FakeTrips(),
              offices: const [],
              administrator: false,
              guard: guard,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Save named preset'));
      await t.tap(find.text('Save named preset'));
      await t.pumpAndSettle();
      allowed.value = false;
      await t.pumpAndSettle();
      expect(find.text('Save preset'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    },
  );
}
