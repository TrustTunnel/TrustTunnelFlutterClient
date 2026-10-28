import 'package:flutter/widgets.dart';

class NavigationRouteObserver extends NavigatorObserver {
  final ValueChanged<Route<dynamic>> _onTopRouteChanged;

  NavigationRouteObserver({required this._onTopRouteChanged});

  Route<dynamic>? _currentRoute;

  String? get currentName => _currentRoute?.settings.name;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _currentRoute = topRoute;
    _onTopRouteChanged(topRoute);
  }
}
