import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

/// Manages the synchronization of the VPN configuration with the server and routing profile.
///
/// It handles monitoring changes in a non-“classic” way (not in a scope-style way)
/// because our core functionality doesn’t depend directly on the tree and runs,
/// in a sort of way, in the background (when the app is minimized and only the tray menu is visible).
///
/// So here, we listen for the necessary sources directly to avoid depending on Flutter’s frame planning.
class VpnUpdateManager extends StatefulWidget {
  final Widget child;

  const VpnUpdateManager({
    super.key,
    required this.child,
  });

  @override
  State<VpnUpdateManager> createState() => _VpnUpdateManagerState();
}

class _VpnUpdateManagerState extends State<VpnUpdateManager> {
  Server? _selectedServer;
  RoutingProfile? _selectedRoutingProfile;
  List<String>? _excludedRoutes;
  VpnConfigurationLogLevel? _selectedLogLevel;

  late ServersScopeController _serversScopeController;
  late RoutingScopeController _routingScopeController;
  late AppLoggingScopeController _loggingScopeController;
  late ExcludedRoutesScopeController _excludedRoutesScopeController;
  late VpnController _vpnController;
  Listenable? _sources;
  Future<void> _queue = Future<void>.value();
  bool _initialized = false;
  bool _disposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sources != null) {
      return;
    }

    _serversScopeController = ServersScope.controllerOf(context, listen: false);
    _routingScopeController = RoutingScope.controllerOf(context, listen: false);
    _loggingScopeController = AppLoggingScope.controllerOf(context, listen: false);
    _excludedRoutesScopeController = ExcludedRoutesScope.controllerOf(context, listen: false);
    _vpnController = VpnScope.vpnControllerOf(context, listen: false);

    _sources = Listenable.merge([
      _serversScopeController,
      _routingScopeController,
      _loggingScopeController,
      _excludedRoutesScopeController,
    ])..addListener(_enqueueUpdate);

    _enqueueUpdate();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// Enqueues the update of the VPN configuration because we don't want to end up with several conflicting updates.
  void _enqueueUpdate() {
    if (_disposed) {
      return;
    }
    _queue = _runQueuedUpdate(_queue);
  }

  Future<void> _runQueuedUpdate(Future<void> previousUpdate) async {
    try {
      await previousUpdate;
      if (_disposed) {
        return;
      }

      await _runUpdate();
    } catch (error, stackTrace) {
      // Also catch failures in error notification so later queued updates can still run.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
        ),
      );
    }
  }

  Future<void> _runUpdate() async {
    try {
      await _synchronizeConfiguration();
    } catch (error, stackTrace) {
      // Report globally without rethrowing: a failed background update must notify the UI and keep the queue usable.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'VPN configuration',
        ),
      );
      if (!mounted) {
        return;
      }
      await _vpnController.notifyOnOperationError();
    }
  }

  Future<void> _synchronizeConfiguration() async {
    // Loading states can temporarily omit selection; never apply partial data.
    if (_serversScopeController.loading ||
        _routingScopeController.loading ||
        _loggingScopeController.loading ||
        _excludedRoutesScopeController.loading ||
        _serversScopeController.error != null ||
        _routingScopeController.error != null ||
        _excludedRoutesScopeController.error != null ||
        _loggingScopeController.error != null) {
      return;
    }

    final server = _serversScopeController.selectedServer;
    final profile = _routingScopeController.routingList.firstWhereOrNull(
      (item) => item.id == server?.serverData.routingProfileId,
    );
    // The editor's draft must not enter a running VPN configuration.
    final routes = _excludedRoutesScopeController.initialExcludedRoutes;

    final logLevel = switch (_loggingScopeController.securityType) {
      LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
      LoggingSecurityType.full => switch (_loggingScopeController.loggingLevel) {
        LoggingLevel.defaultLevel => VpnConfigurationLogLevel.info,
        LoggingLevel.debug => VpnConfigurationLogLevel.debug,
      },
    };

    if (!_initialized) {
      if (server != null && profile == null) {
        return;
      }
      _initialized = true;
      _selectedServer = server;
      _selectedRoutingProfile = profile;
      _excludedRoutes = List.of(routes);
      _selectedLogLevel = logLevel;

      return;
    }

    // Importing the first server establishes the baseline, as before; choosing
    // another server later retains the existing restart behaviour.
    if (_selectedServer == null && server != null && profile != null) {
      _selectedServer = server;
      _selectedRoutingProfile = profile;
      _excludedRoutes = List.of(routes);
      _selectedLogLevel = logLevel;

      return;
    }

    final isSelectedServerInList = _serversScopeController.servers.any((server) => server.id == _selectedServer!.id);
    final wasDeleted = _selectedServer != null && !isSelectedServerInList;
    if (wasDeleted && _serversScopeController.servers.isEmpty) {
      await _deleteConfig(controller: _vpnController);

      return;
    }

    if (server == null || profile == null) {
      return;
    }

    final changed =
        _selectedServer != server ||
        _selectedRoutingProfile != profile ||
        _selectedLogLevel != logLevel ||
        !listEquals(_excludedRoutes, routes);
    if (!changed) {
      return;
    }

    if ((_selectedServer?.id == server.id && _vpnController.state == VpnState.disconnected) || wasDeleted) {
      await _updateStoredConfiguration(
        controller: _vpnController,
        server: server,
        routingProfile: profile,
        excludedRoutes: routes,
        logLevel: logLevel,
      );
    } else {
      await _restartVpnService(
        controller: _vpnController,
        server: server,
        routingProfile: profile,
        excludedRoutes: routes,
        logLevel: logLevel,
      );
    }
  }

  Future<void> _updateStoredConfiguration({
    required VpnController controller,
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    await controller.stop();
    await controller.updateConfiguration(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = List.of(excludedRoutes);
    _selectedLogLevel = logLevel;
  }

  Future<void> _deleteConfig({
    required VpnController controller,
  }) async {
    await controller.deleteConfiguration();
    _selectedServer = null;
    _selectedRoutingProfile = null;
    _excludedRoutes = null;
    _selectedLogLevel = null;
  }

  Future<void> _restartVpnService({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnController controller,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    await controller.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = List.of(excludedRoutes);
    _selectedLogLevel = logLevel;
  }

  @override
  void dispose() {
    _disposed = true;
    _sources?.removeListener(_enqueueUpdate);
    super.dispose();
  }
}
