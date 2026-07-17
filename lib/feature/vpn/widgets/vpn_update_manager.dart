import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

class VpnUpdateManager extends StatefulWidget {
  final Widget child;

  const VpnUpdateManager({
    super.key,
    required this.child,
  });

  @override
  State<VpnUpdateManager> createState() => _VpnUpdateManagerState();
}

/// State for widget VpnUpdateManager.
class _VpnUpdateManagerState extends State<VpnUpdateManager> {
  Server? _selectedServer;
  RoutingProfile? _selectedRoutingProfile;
  List<String>? _excludedRoutes;
  LoggingSecurityType? _appliedLogSecurityType;
  bool _isLogConfigurationSyncInProgress = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final serverScope = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.selectedServer,
    );

    final updatedServer = serverScope.selectedServer;

    final routingScope = RoutingScope.controllerOf(
      context,
      aspect: RoutingScopeAspect.profiles,
    );

    final updatedRoutingProfileList = routingScope.routingList;

    final excludedRoutesController = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.routes,
    );

    final updatedExcludedRoutes = excludedRoutesController.excludedRoutes;

    final vpnController = VpnScope.vpnControllerOf(
      context,
      listen: false,
    );

    final loggingScope = AppLoggingScope.controllerOf(context);
    final logLevel = _mapSecurityTypeToLogLevel(loggingScope.securityType);

    _selectedServer ??= updatedServer;

    final wasDeleted =
        serverScope.servers.firstWhereOrNull(
          (element) => element.id == _selectedServer?.id,
        ) ==
        null;

    if (_selectedServer == null || (!wasDeleted && updatedServer == null)) {
      return;
    }

    if (wasDeleted && serverScope.servers.isEmpty && _selectedServer != updatedServer) {
      unawaited(_deleteStoredConfiguration(controller: vpnController));

      return;
    }

    if (serverScope.servers.isNotEmpty && updatedServer == null) {
      serverScope.fetchServers();

      return;
    }

    if (updatedServer == null) {
      return;
    }

    final updatedRoutingProfile = updatedRoutingProfileList.firstWhereOrNull(
      (element) => element.id == updatedServer.serverData.routingProfileId,
    );

    _selectedRoutingProfile ??= updatedRoutingProfile;

    if (updatedRoutingProfile == null) {
      routingScope.fetchProfiles();

      return;
    }

    _excludedRoutes ??= updatedExcludedRoutes;

    if (_excludedRoutes == null) {
      excludedRoutesController.fetchExcludedRoutes();

      return;
    }

    if (loggingScope.loading) {
      return;
    }

    final shouldRefreshConfiguration =
        _selectedServer != updatedServer ||
        _selectedRoutingProfile != updatedRoutingProfile ||
        !listEquals(_excludedRoutes, updatedExcludedRoutes);

    if (shouldRefreshConfiguration) {
      _refreshConfiguration(
        vpnController: vpnController,
        updatedServer: updatedServer,
        updatedRoutingProfile: updatedRoutingProfile,
        updatedExcludedRoutes: updatedExcludedRoutes,
        wasSelectedServerDeleted: wasDeleted,
        logLevel: logLevel,
      );

      if (!_isLogConfigurationSyncInProgress) {
        _appliedLogSecurityType = loggingScope.securityType;
      }

      return;
    }

    _syncLogConfigurationIfNeeded(
      securityType: loggingScope.securityType,
      server: updatedServer,
      routingProfile: updatedRoutingProfile,
      excludedRoutes: updatedExcludedRoutes,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// Stops the VPN and replaces its stored system configuration.
  Future<void> _updateStoredConfiguration({
    required VpnController controller,
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = excludedRoutes;

    await controller.stop();
    await controller.updateConfiguration(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
  }

  /// Deletes the stored system configuration and clears the local snapshot.
  Future<void> _deleteStoredConfiguration({
    required VpnController controller,
  }) async {
    _selectedServer = null;
    _selectedRoutingProfile = null;
    _excludedRoutes = null;
    await controller.deleteConfiguration();
  }

  /// Restarts the VPN with the latest server and routing values.
  Future<void> _restartVpn({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnController controller,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = excludedRoutes;
    await controller.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
  }

  /// Updates the stored profile when disconnected or the selected server was deleted.
  /// Otherwise restarts the VPN.
  void _refreshConfiguration({
    required VpnController vpnController,
    required Server updatedServer,
    required RoutingProfile updatedRoutingProfile,
    required List<String> updatedExcludedRoutes,
    required bool wasSelectedServerDeleted,
    required VpnConfigurationLogLevel logLevel,
  }) {
    final shouldUpdateStoredConfiguration =
        (_selectedServer?.id == updatedServer.id && vpnController.state == VpnState.disconnected) ||
        wasSelectedServerDeleted;

    if (shouldUpdateStoredConfiguration) {
      unawaited(
        _updateStoredConfiguration(
          controller: vpnController,
          server: updatedServer,
          routingProfile: updatedRoutingProfile,
          excludedRoutes: updatedExcludedRoutes,
          logLevel: logLevel,
        ),
      );
    } else {
      unawaited(
        _restartVpn(
          controller: vpnController,
          server: updatedServer,
          routingProfile: updatedRoutingProfile,
          excludedRoutes: updatedExcludedRoutes,
          logLevel: logLevel,
        ),
      );
    }
  }

  /// Applies a changed sensitive-data setting to the current VPN configuration.
  void _syncLogConfigurationIfNeeded({
    required LoggingSecurityType securityType,
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) {
    if (_isLogConfigurationSyncInProgress || _appliedLogSecurityType == securityType) {
      return;
    }

    if (_appliedLogSecurityType == null && securityType == LoggingSecurityType.full) {
      _appliedLogSecurityType = securityType;

      return;
    }

    _isLogConfigurationSyncInProgress = true;
    unawaited(
      _syncLogConfiguration(
        securityType: securityType,
        server: server,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      ),
    );
  }

  void _syncLatestLogConfigurationIfNeeded({
    required LoggingSecurityType synchronizedSecurityType,
  }) {
    if (!mounted) {
      return;
    }

    final securityType = AppLoggingScope.controllerOf(context, listen: false).securityType;
    final server = _selectedServer;
    final routingProfile = _selectedRoutingProfile;
    final excludedRoutes = _excludedRoutes;

    if (securityType == synchronizedSecurityType ||
        server == null ||
        routingProfile == null ||
        excludedRoutes == null) {
      return;
    }

    _syncLogConfigurationIfNeeded(
      securityType: securityType,
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
    );
  }

  /// Reapplies the VPN configuration with the requested logging level.
  Future<void> _syncLogConfiguration({
    required LoggingSecurityType securityType,
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) async {
    try {
      if (mounted) {
        final controller = VpnScope.vpnControllerOf(context, listen: false);
        final logLevel = _mapSecurityTypeToLogLevel(securityType);

        if (controller.state != VpnState.disconnected) {
          await controller.start(
            server: server,
            routingProfile: routingProfile,
            excludedRoutes: excludedRoutes,
            logLevel: logLevel,
          );
        } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
          await controller.updateConfiguration(
            server: server,
            routingProfile: routingProfile,
            excludedRoutes: excludedRoutes,
            logLevel: logLevel,
          );
        }
      }

      _appliedLogSecurityType = securityType;
    } finally {
      _isLogConfigurationSyncInProgress = false;
      _syncLatestLogConfigurationIfNeeded(synchronizedSecurityType: securityType);
    }
  }

  VpnConfigurationLogLevel _mapSecurityTypeToLogLevel(LoggingSecurityType securityType) => switch (securityType) {
    LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
    LoggingSecurityType.full => VpnConfigurationLogLevel.debug,
  };
}
