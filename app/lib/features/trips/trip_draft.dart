import '../../core/domain/business_date.dart';
import '../../core/domain/money.dart';
import '../../core/domain/quote.dart';
import '../masters/master_repository.dart';

class DraftStop {
  DraftStop({String? id, this.kind = 'PICKUP', this.address = ''})
    : id = id ?? newRecordId();
  final String id;
  String kind, address;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'address': address.trim(),
  };
}

class DraftCar {
  DraftCar({String? id, this.identifier = '', this.pickup, this.drop})
    : id = id ?? newRecordId();
  final String id;
  String identifier;
  String? pickup, drop;
  Map<String, dynamic> toJson() => {
    'id': id,
    'identifier': identifier.trim(),
    'pickup_stop_id': pickup,
    'drop_stop_id': drop,
  };
}

class DraftConsignment {
  DraftConsignment({String? id}) : id = id ?? newRecordId();
  final String id;
  String? customer, broker, customerName, brokerName, pickup, drop;
  String count = '1', amount = '0.00', commissionValue = '0.00', notes = '';
  String mode = 'DEDUCTED', method = 'FIXED';
  int fareRevision = 0;
  final cars = <DraftCar>[];
  Quote preview() => Quote.calculate(
    amount: Money.parse(amount),
    mode: mode == 'ADDED' ? QuoteMode.added : QuoteMode.deducted,
    commission: method == 'FIXED'
        ? FixedCommission(Money.parse(commissionValue))
        : PercentageCommission(Percentage.parse(commissionValue)),
    hasBroker: broker != null,
  );
  Map<String, dynamic> toJson() {
    final quote = preview();
    if (customer == null ||
        !RegExp(r'^[1-9][0-9]{0,5}$').hasMatch(count) ||
        cars.length > int.parse(count)) {
      throw const FormatException(TripStrings.invalidConsignment);
    }
    return {
      'id': id,
      'customer_id': customer,
      'broker_id': broker,
      'car_count': int.parse(count),
      'quoted_amount': quote.quotedAmount.toString(),
      'quote_mode': mode,
      'commission_method': method,
      'commission_value': Money.parse(commissionValue).toString(),
      'notes': notes,
      'pickup_stop_id': pickup,
      'drop_stop_id': drop,
      'cars': cars.map((c) => c.toJson()).toList(),
    };
  }
}

class TripDraft {
  TripDraft({String? id}) : id = id ?? newRecordId();
  final String id;
  int version = 0;
  String? number,
      vehicle,
      registration,
      driver,
      driverName,
      origin,
      destination,
      route,
      routeName,
      parent,
      parentNumber,
      ownerName;
  String planned = '', kind = 'LOADED', notes = '', reason = '';
  String? suggestedFare;
  final stops = <DraftStop>[];
  final consignments = <DraftConsignment>[];

  factory TripDraft.fromDetail(Map<String, dynamic> row) {
    final d = TripDraft(id: row['id'] as String)
      ..version = row['version'] as int
      ..number = row['trip_number'] as String?
      ..vehicle = row['vehicle_id'] as String?
      ..registration = row['registration'] as String?
      ..driver = row['driver_id'] as String?
      ..driverName = row['driver_name'] as String?
      ..origin = row['origin_office_id'] as String?
      ..destination = row['destination_office_id'] as String?
      ..route = row['route_id'] as String?
      ..parent = row['return_of_trip_id'] as String?
      ..planned = row['planned_dispatch_date'] as String? ?? ''
      ..kind = row['load_kind'] as String
      ..notes = row['notes'] as String? ?? ''
      ..ownerName = (row['owner_snapshot'] as Map)['display_name'] as String?;
    final route = row['route_snapshot'] as Map;
    d.routeName = route['code'] as String?;
    for (final s in row['stops'] as List) {
      d.stops.add(
        DraftStop(id: s['id'], kind: s['kind'], address: s['address']),
      );
    }
    for (final c in row['consignments'] as List) {
      final item = DraftConsignment(id: c['id'])
        ..customer = c['customer_id']
        ..customerName = c['customer_name']
        ..broker = c['broker_id']
        ..brokerName = c['broker_name']
        ..count = '${c['car_count']}'
        ..amount = c['quoted_amount']
        ..mode = c['quote_mode']
        ..method = c['commission_method']
        ..commissionValue = c['commission_value']
        ..pickup = c['pickup_stop_id']
        ..drop = c['drop_stop_id']
        ..notes = c['notes'];
      for (final a in c['cars'] as List) {
        item.cars.add(
          DraftCar(
            id: a['id'],
            identifier: a['identifier'],
            pickup: a['pickup_stop_id'] == c['pickup_stop_id']
                ? null
                : a['pickup_stop_id'],
            drop: a['drop_stop_id'] == c['drop_stop_id']
                ? null
                : a['drop_stop_id'],
          ),
        );
      }
      d.consignments.add(item);
    }
    return d;
  }
  factory TripDraft.returnFrom(Map<String, dynamic> parent) => TripDraft()
    ..vehicle = parent['vehicle_id']
    ..registration = parent['registration']
    ..driver = parent['driver_id']
    ..driverName = parent['driver_name']
    ..origin = parent['destination_office_id']
    ..destination = parent['origin_office_id']
    ..parent = parent['id']
    ..parentNumber = parent['trip_number']
    ..kind = 'EMPTY';

  bool stopUsed(String id) => consignments.any(
    (c) =>
        c.pickup == id ||
        c.drop == id ||
        c.cars.any((a) => a.pickup == id || a.drop == id),
  );
  void validateLinks(String? pickup, String? drop) {
    final p = pickup == null
        ? -1
        : stops.indexWhere((s) => s.id == pickup && s.kind == 'PICKUP');
    final d = drop == null
        ? -1
        : stops.indexWhere((s) => s.id == drop && s.kind == 'DROP');
    if ((pickup != null && p < 0) ||
        (drop != null && d < 0) ||
        (p >= 0 && d >= 0 && p >= d)) {
      throw const FormatException(TripStrings.invalidStops);
    }
  }

  Map<String, dynamic> toJson() {
    if (vehicle == null ||
        origin == null ||
        destination == null ||
        origin == destination) {
      throw const FormatException(TripStrings.requiredJourney);
    }
    if (planned.isNotEmpty) BusinessDate.parse(planned);
    if (version > 0 && reason.trim().isEmpty) {
      throw const FormatException(TripStrings.reasonRequired);
    }
    if ((kind == 'LOADED' && consignments.isEmpty) ||
        (kind == 'EMPTY' && consignments.isNotEmpty)) {
      throw const FormatException(TripStrings.invalidLoad);
    }
    for (final s in stops) {
      if (s.address.trim().isEmpty) {
        throw const FormatException(TripStrings.stopAddress);
      }
    }
    for (final c in consignments) {
      validateLinks(c.pickup, c.drop);
      final identifiers = <String>{};
      for (final a in c.cars) {
        if (a.identifier.trim().isEmpty ||
            !identifiers.add(a.identifier.trim())) {
          throw const FormatException(TripStrings.invalidIdentifiers);
        }
        validateLinks(a.pickup ?? c.pickup, a.drop ?? c.drop);
      }
    }
    return {
      'vehicle_id': vehicle,
      'driver_id': driver,
      'origin_office_id': origin,
      'destination_office_id': destination,
      'route_id': route,
      'planned_dispatch_date': planned.isEmpty ? null : planned,
      'load_kind': kind,
      'notes': notes,
      'return_of_trip_id': parent,
      'reason': reason,
      'stops': stops.map((s) => s.toJson()).toList(),
      'consignments': consignments.map((c) => c.toJson()).toList(),
    };
  }

  Map<String, String> previewTotals() {
    var customer = BigInt.zero, commission = BigInt.zero, owner = BigInt.zero;
    for (final c in consignments) {
      final q = c.preview();
      customer += BigInt.from(q.customerCharge.paisa);
      commission += BigInt.from(q.commission.paisa);
      owner += BigInt.from(q.ownerEntitlement.paisa);
    }
    String decimal(BigInt n) =>
        '${n ~/ BigInt.from(100)}.${(n % BigInt.from(100)).toString().padLeft(2, '0')}';
    return {
      'customer_charge': decimal(customer),
      'commission': decimal(commission),
      'owner_entitlement': decimal(owner),
    };
  }
}

class TripStrings {
  static const defaultDriver = "Vehicle default; review the saved driver";
  static const trips = 'Trips',
      newTrip = 'New draft',
      save = 'Review and save draft',
      saved = 'Draft saved. Server-calculated amounts shown below.';
  static const potential =
      'Draft quotes are potential fare. No earnings or payment status is posted.';
  static const scope = 'Assigned-office trips',
      all = 'All offices',
      search = 'Search trip, vehicle or party',
      refresh = 'Search / refresh';
  static const requiredJourney = 'Choose a vehicle and two different offices.',
      invalidConsignment =
          'Choose a customer, a positive car count and no more identifiers than cars.';
  static const invalidStops =
          'Choose pickup/drop stops on this trip, with pickup before drop.',
      stopAddress = 'Enter an address for every stop.';
  static const invalidLoad =
      'A loaded draft needs consignments. An empty draft cannot carry consignments.';
  static const invalidIdentifiers =
          'Car identifiers must be nonempty and unique within their consignment.',
      reasonRequired = 'Enter a reason for changing this draft.';
  static const failed =
      'Request failed. Your entries remain here. Check your connection and access before retrying.';
  static const conflict =
      'This draft or overlap changed. Review the current record and warning before trying again.';
  static const overlap =
      'Another dispatched journey uses this vehicle. Review and confirm before saving.';
  static const restricted =
      'An active journey outside your office scope also uses this vehicle. Its details are restricted.';
  static const reviewReason = 'Reason for allowing the overlap',
      confirmOverlap = 'I reviewed this vehicle overlap',
      cancel = 'Cancel',
      confirm = 'Confirm save';
  static const labels = {
    'vehicle': 'Vehicle',
    'driver': 'Driver (optional)',
    'origin': 'Origin office',
    'destination': 'Destination office',
    'route': 'Route (optional)',
    'planned': 'Planned dispatch date (YYYY-MM-DD, optional)',
    'load': 'Load kind',
    'notes': 'Notes',
    'reason': 'Reason for edit',
    'owner': 'Recorded owner',
    'customer': 'Customer',
    'broker': 'Broker (optional)',
    'count': 'Car count',
    'amount': 'Total quoted fare, PKR',
    'mode': 'Quote basis',
    'method': 'Brokerage method',
    'value': 'Fixed PKR / percentage value',
    'pickup': 'Pickup stop (optional)',
    'drop': 'Drop stop (optional)',
    'identifier': 'Car identifier',
    'customer_charge': 'Customer charge',
    'commission': 'Brokerage',
    'owner_entitlement': 'Owner fare share',
    'from': 'From dispatch/planned date (YYYY-MM-DD)',
    'to': 'To dispatch/planned date (YYYY-MM-DD)',
  };
  static const addConsignment = 'Add consignment',
      removeConsignment = 'Remove consignment',
      addStop = 'Add stop',
      stops = 'Pickup / drop stops';
  static const addCar = 'Add optional identifier',
      carsHelp =
          'Count includes all cars; identifiers are optional. Car stops follow consignment stops unless overridden.';
  static const choose = 'Choose',
      clear = 'Clear',
      none = 'None',
      close = 'Close',
      edit = 'Edit draft',
      linkedReturn = 'Create linked return';
  static const next = 'Next',
      previous = 'Previous',
      empty = 'No trips in this scope.',
      unavailable = 'Trips unavailable. Retry';
  static const remove = 'Remove',
      address = 'Stop address',
      up = 'Move up',
      down = 'Move down',
      stopInUse = 'Clear this stop from consignments/cars before removing it.';
  static const applySuggestion = 'Use reviewed route suggestion',
      fareInvalid = 'Check the quote and brokerage values.',
      emptySwitch = 'Remove the consignments before selecting EMPTY.';
  static const noChoices = 'No choices on this page.',
      searchChoices = 'Search name / code',
      review = 'Review draft',
      identifiers = 'Car identifiers';
  static const serverErrors = {
    'FORBIDDEN': 'Your current account cannot perform this operation.',
    'DRAFT_EDIT_UNAVAILABLE': 'Only unposted drafts can be edited here.',
    'OVERLAP_CONFIRMATION_REQUIRED':
        'Review and confirm the current vehicle overlap.',
    'ACTIVE_PARTY_ROLE_REQUIRED': 'Choose active customer and broker roles.',
    'INVALID_RETURN_LINK':
        'A return must use the same vehicle and reverse the original offices.',
    'INVALID_STOP_LINK': invalidStops,
    'INVALID_CAR_STOPS': invalidStops,
    'RETURN_DEPENDENCY': 'Linked returns require these vehicle and office details to remain consistent.',
  };
}
