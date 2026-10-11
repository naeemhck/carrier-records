import 'package:carrier_records/features/trips/trip_draft.dart';
import 'package:flutter_test/flutter_test.dart';

TripDraft sample() {
  final d = TripDraft()
    ..vehicle = 'vehicle'
    ..origin = 'origin'
    ..destination = 'destination';
  final p = DraftStop(address: 'Pickup'),
      drop = DraftStop(kind: 'DROP', address: 'Drop');
  d.stops.addAll([p, drop]);
  d.consignments.addAll([
    DraftConsignment()
      ..customer = 'customer1'
      ..broker = 'broker'
      ..count = '3'
      ..amount = '100000.00'
      ..method = 'PERCENTAGE'
      ..commissionValue = '5.00'
      ..pickup = p.id
      ..drop = drop.id,
    DraftConsignment()
      ..customer = 'customer2'
      ..broker = 'broker'
      ..count = '2'
      ..amount = '1234.56'
      ..mode = 'ADDED'
      ..commissionValue = '10.01',
  ]);
  return d;
}

void main() {
  test('saved inherited car stops follow subsequent consignment edits', () {
    final d = sample();
    final c = d.consignments.first;
    final row = {
      'id': d.id,
      'version': 1,
      'trip_number': 'TRP-1',
      'vehicle_id': d.vehicle,
      'origin_office_id': d.origin,
      'destination_office_id': d.destination,
      'load_kind': d.kind,
      'owner_snapshot': {'display_name': 'Owner'},
      'route_snapshot': {},
      'stops': d.stops.map((s) => s.toJson()).toList(),
      'consignments': [
        {
          ...c.toJson(),
          'customer_name': 'Customer',
          'broker_name': 'Broker',
          'cars': [
            {
              'id': 'car',
              'identifier': 'ABC',
              'pickup_stop_id': c.pickup,
              'drop_stop_id': c.drop,
            },
          ],
        },
      ],
    };
    final loaded = TripDraft.fromDetail(row)..reason = 'Correction';
    expect(loaded.consignments.first.cars.first.pickup, isNull);
    final extra = DraftStop(address: 'New pickup');
    loaded.stops.insert(0, extra);
    loaded.consignments.first.pickup = extra.id;
    final saved = (loaded.toJson()['consignments'] as List).first;
    expect(saved['pickup_stop_id'], extra.id);
    expect(saved['cars'][0]['pickup_stop_id'], isNull);
  });
  test('AT-08 independent customers aggregate exact potential amounts', () {
    final d = sample();
    expect(d.previewTotals(), {
      'customer_charge': '101244.57',
      'commission': '5010.01',
      'owner_entitlement': '96234.56',
    });
    final c = d.toJson()['consignments'] as List;
    expect(c[0]['car_count'], 3);
    expect(c[0]['cars'], isEmpty);
    expect(c[1]['quoted_amount'], '1234.56');
    expect(c[0].containsKey('customer_charge'), isFalse);
  });
  test('aggregate preview does not overflow per-consignment money bound', () {
    final d = sample();
    for (final c in d.consignments) {
      c.amount = '9999999999999999.99';
      c.commissionValue = '0.00';
    }
    expect(d.previewTotals()['customer_charge'], '19999999999999999.98');
  });
  test('count includes cars with optional identifiers and rejects duplicates/excess', () {
    final d = sample(), c = sample().consignments.first;
    d.consignments.first.cars.add(DraftCar(identifier: 'ABC'));
    expect((d.toJson()['consignments'] as List).first['car_count'], 3);
    d.consignments.first.cars.add(DraftCar(identifier: ' ABC '));
    expect(d.toJson, throwsFormatException);
    c.count = '1';
    c.cars.addAll([DraftCar(identifier: 'A'), DraftCar(identifier: 'B')]);
    expect(c.toJson, throwsFormatException);
  });
  test('wrong-kind, foreign and reordered stop links require correction', () {
    final d = sample();
    expect(d.stopUsed(d.stops.first.id), isTrue);
    d.stops.setAll(0, d.stops.reversed.toList());
    expect(d.toJson, throwsFormatException);
    d.consignments.first.pickup = 'foreign';
    expect(d.toJson, throwsFormatException);
  });
  test(
    'draft edits require reason, valid business date and loaded contents',
    () {
      final d = sample()..version = 1;
      expect(d.toJson, throwsFormatException);
      d.reason = 'Correction';
      d.planned = '2026-02-30';
      expect(d.toJson, throwsFormatException);
      d.planned = '2026-10-11';
      d.kind = 'EMPTY';
      expect(d.toJson, throwsFormatException);
      d.consignments.clear();
      expect(d.toJson()['load_kind'], 'EMPTY');
    },
  );
  test(
    'AT-09 linked return reverses offices, preserves vehicle, starts empty',
    () {
      final d = TripDraft.returnFrom({
        'id': 'parent',
        'trip_number': 'TRP-1',
        'vehicle_id': 'vehicle',
        'registration': 'ABC',
        'driver_id': null,
        'driver_name': null,
        'origin_office_id': 'origin',
        'destination_office_id': 'destination',
      });
      expect(d.toJson()['return_of_trip_id'], 'parent');
      expect(d.origin, 'destination');
      expect(d.destination, 'origin');
      expect(d.kind, 'EMPTY');
      expect(d.version, 0);
      expect(d.consignments, isEmpty);
      d.kind = 'LOADED';
      expect(d.toJson, throwsFormatException);
    },
  );
}
