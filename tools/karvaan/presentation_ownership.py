"""Explicit dynamic presentation boundary; never classify record names as labels."""


def owned_expression(source, file=''):
    if source in {'error', 'error!', 'message!', 'status!', 'receiptStatus', 'totals()',
                  'widget.kind.label', 'widget.action.label', 'action.label',
                  'TripAction.cancelConsignment.label', 'f.label', 'a.label',
                  'item.label', 'role', 'group', 'title', 'entry.$1', 'field.$2',
                  'label', 's.data!.scope', "data['scope'] as String", "f['label'] as String"}:
        return True
    if source.startswith(('tripError(', 'correctionError(', 'MasterStrings.',
                          'TripStrings.labels[', 'LifecycleStrings.', 'reportLabels[')):
        return True
    if "s.fields.firstWhere(" in source and "['label']" in source:
        return True
    if source == 'r' and file.endswith(('carrier_records_app.dart', 'output_workspace.dart')):
        return True
    if source == 'v' and file.endswith(('trip_workspace.dart', 'output_workspace.dart')):
        return True
    if source == 's' and file.endswith('trip_workspace.dart'):
        return True
    # Selection results called label are record identities, not field labels.
    # r['label'], row.label, r.label and p.label deliberately remain data.
    return False
