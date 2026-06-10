import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/logging/app_logger.dart';

final class LoggingNavigatorObserver extends NavigatorObserver {
  final AppLogger _logger;
  final String _navigatorName;

  LoggingNavigatorObserver({
    required AppLogger logger,
    required String navigatorName,
  }) : _logger = logger,
       _navigatorName = navigatorName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigationEvent(
      action: 'push',
      route: route,
      previousRoute: previousRoute,
      message: 'Navigation push: from=${_routeName(previousRoute)}, to=${_routeName(route)}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigationEvent(
      action: 'pop',
      route: route,
      previousRoute: previousRoute,
      message: 'Navigation pop: from=${_routeName(route)}, to=${_routeName(previousRoute)}',
    );
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logNavigationEvent(
      action: 'remove',
      route: route,
      previousRoute: previousRoute,
      message: 'Navigation remove: route=${_routeName(route)}, previous=${_routeName(previousRoute)}',
    );
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    _logger.logDebug(
      'Navigation replace: from=${_routeName(oldRoute)}, to=${_routeName(newRoute)}',
      additionalTags: ['navigation', _navigatorName, 'replace'],
    );
  }

  @override
  void didStartUserGesture(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    _logger.logDebug(
      'Navigation user gesture started: from=${_routeName(route)}, to=${_routeName(previousRoute)}',
      additionalTags: ['navigation', _navigatorName, 'gesture'],
    );
  }

  @override
  void didStopUserGesture() {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    _logger.logDebug(
      'Navigation user gesture stopped',
      additionalTags: ['navigation', _navigatorName, 'gesture'],
    );
  }

  void _logNavigationEvent({
    required String action,
    required Route<dynamic> route,
    required Route<dynamic>? previousRoute,
    required String message,
  }) {
    if (!_logger.isDebugLoggingEnabled) {
      return;
    }

    _logger.logDebug(
      message,
      additionalTags: ['navigation', _navigatorName, action],
    );

    _logger.logDebug(
      'Navigation $action details: route=${_routeDescription(route)}, previous=${_routeDescription(previousRoute)}',
      additionalTags: ['navigation', _navigatorName, action, 'details'],
    );
  }

  String _routeName(Route<dynamic>? route) {
    if (route == null) {
      return 'none';
    }

    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      return name;
    }

    return route.runtimeType.toString();
  }

  String _routeDescription(Route<dynamic>? route) {
    if (route == null) {
      return 'none';
    }

    final routeDescription = {
      'name': route.settings.name,
      'type': route.runtimeType.toString(),
      'isFirst': route.isFirst,
      'isCurrent': route.isCurrent,
      'isActive': route.isActive,
    };

    return routeDescription.toString();
  }
}
