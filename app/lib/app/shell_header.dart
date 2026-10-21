import 'package:flutter/material.dart';

import 'bilingual.dart';

/// One primary action of a screen, as shown in the shell header row.
/// [child] is the full form (a labelled button) used on wide bars;
/// [compactChild] is the icon form used on narrow (phone) bars.
/// [hideOnNarrow] omits the action from narrow bars entirely — only
/// for shortcuts whose destination is independently reachable from the
/// phone navigation (e.g. the Dashboard's Reports shortcut duplicates
/// the rail's Reports destination).
class ShellHeaderAction {
  const ShellHeaderAction({
    required this.child,
    this.compactChild,
    this.hideOnNarrow = false,
  });
  final Widget child;
  final Widget? compactChild;
  final bool hideOnNarrow;

  /// The form to render at [narrow] bar widths, or null to omit.
  Widget? form(bool narrow) {
    if (!narrow) return child;
    if (hideOnNarrow) return null;
    return compactChild ?? child;
  }
}

/// What a screen shows in the shell's ONE header row (header compaction
/// pass): a one-line bilingual title plus the screen's primary actions.
/// The shell renders the spec for the current workspace route beside the
/// language menu and account control; screens no longer stack their own
/// 88px AppBar title blocks under the shell bar.
class ShellHeaderSpec {
  const ShellHeaderSpec({required this.title, this.actions = const []});
  final Bilingual title;
  final List<ShellHeaderAction> actions;
}

/// Route-keyed registry of header specs. The workspace route observer
/// reports the current route; a page that registers nothing for its route
/// (an editor or detail page that keeps its own AppBar) leaves the shell
/// bar in its slim fallback form — compact identity chip + language +
/// account, no title and no second back button.
class ShellHeaderRegistry extends ChangeNotifier {
  final Map<Route<dynamic>, ShellHeaderSpec> _byRoute = {};
  final List<Object> _order = [];
  static const Object _routeless = Object();
  ShellHeaderSpec? _routelessSpec;
  Route<dynamic>? currentRoute;

  ShellHeaderSpec? get current {
    final route = currentRoute;
    if (route != null) return _byRoute[route];
    // No route wiring (unit hosts): the most recently registered spec.
    if (_order.isEmpty) return _routelessSpec;
    final last = _order.last;
    return last == _routeless ? _routelessSpec : _byRoute[last];
  }

  bool _notifyQueued = false;
  void _queueNotify() {
    if (_notifyQueued) return;
    _notifyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyQueued = false;
      notifyListeners();
    });
  }

  void setCurrentRoute(Route<dynamic>? route) {
    if (route == currentRoute) return;
    currentRoute = route;
    _queueNotify();
  }

  void register(Route<dynamic>? route, ShellHeaderSpec spec) {
    final key = route ?? _routeless;
    if (route == null) {
      _routelessSpec = spec;
    } else {
      _byRoute[route] = spec;
    }
    _order.remove(key);
    _order.add(key);
    _queueNotify();
  }

  /// Removes [expected] for [route] — only while it is still the stored
  /// spec. A same-route page swap builds (and registers) the new page
  /// before the old page disposes; an unconditional remove would erase
  /// the new page's header.
  void unregister(Route<dynamic>? route, ShellHeaderSpec? expected) {
    final key = route ?? _routeless;
    if (route == null) {
      if (expected != null && !identical(_routelessSpec, expected)) return;
      _routelessSpec = null;
    } else {
      if (expected != null && !identical(_byRoute[route], expected)) return;
      _byRoute.remove(route);
    }
    _order.remove(key);
    _queueNotify();
  }
}

/// Provides the [ShellHeaderRegistry] to the workspace subtree.
class ShellHeaderScope extends InheritedWidget {
  const ShellHeaderScope({
    super.key,
    required this.registry,
    required super.child,
  });
  final ShellHeaderRegistry registry;

  static ShellHeaderRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellHeaderScope>()?.registry;

  @override
  bool updateShouldNotify(ShellHeaderScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Registers this screen's title + primary actions with the shell
/// header and renders [child] unchanged. In a host without a shell scope
/// (unit tests, standalone dialogs) it renders the same compact one-line
/// header in place above the child, so the screen keeps its title row.
class ShellHeader extends StatefulWidget {
  const ShellHeader({
    super.key,
    required this.title,
    this.actions = const [],
    required this.child,
  });
  final Bilingual title;
  final List<ShellHeaderAction> actions;
  final Widget child;
  @override
  State<ShellHeader> createState() => _ShellHeaderState();
}

class _ShellHeaderState extends State<ShellHeader> {
  ShellHeaderRegistry? _registry;
  Route<dynamic>? _route;
  bool _registered = false;
  ShellHeaderSpec? _registeredSpec;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = ShellHeaderScope.maybeOf(context);
    final route = ModalRoute.of(context);
    if (!identical(registry, _registry) || route != _route) {
      if (_registered) _registry?.unregister(_route, _registeredSpec);
      _registered = false;
      _registeredSpec = null;
      _registry = registry;
      _route = route;
    }
    _sync();
  }

  @override
  void didUpdateWidget(ShellHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        !_sameActions(oldWidget.actions, widget.actions)) {
      _sync();
    }
  }

  bool _sameActions(List<ShellHeaderAction> a, List<ShellHeaderAction> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  void _sync() {
    final registry = _registry;
    if (registry == null) return;
    _registered = true;
    _registeredSpec = ShellHeaderSpec(
      title: widget.title,
      actions: widget.actions,
    );
    registry.register(_route, _registeredSpec!);
  }

  @override
  void dispose() {
    if (_registered) _registry?.unregister(_route, _registeredSpec);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_registry != null) return widget.child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(child: BilingualHeaderTitle(widget.title)),
                  for (final action in widget.actions)
                    if (action.form(narrow) != null) action.form(narrow)!,
                ],
              ),
            );
          },
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
