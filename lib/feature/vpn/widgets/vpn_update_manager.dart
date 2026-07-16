import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
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
  bool _initialLogConfigurationSynced = false;
  bool _isInitialLogConfigurationSyncInProgress = false;

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
      _initialLogConfigurationSynced = true;
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

    final shouldRefreshConfiguration =
        _selectedServer != updatedServer ||
        _selectedRoutingProfile != updatedRoutingProfile ||
        !listEquals(_excludedRoutes, updatedExcludedRoutes);

    if (shouldRefreshConfiguration) {
      _initialLogConfigurationSynced = true;

      _refreshConfiguration(
        vpnController: vpnController,
        updatedServer: updatedServer,
        updatedRoutingProfile: updatedRoutingProfile,
        updatedExcludedRoutes: updatedExcludedRoutes,
        wasSelectedServerDeleted: wasDeleted,
      );

      return;
    }

    if (loggingScope.loading) {
      return;
    }

    _syncInitialLogConfigurationIfNeeded(
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
  }) async {
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = excludedRoutes;

    await controller.stop();
    await controller.updateConfiguration(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
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
  }) async {
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = excludedRoutes;
    await controller.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
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
        ),
      );
    } else {
      unawaited(
        _restartVpn(
          controller: vpnController,
          server: updatedServer,
          routingProfile: updatedRoutingProfile,
          excludedRoutes: updatedExcludedRoutes,
        ),
      );
    }
  }

  /// Starts one-time synchronization of the existing VPN profile when needed.
  void _syncInitialLogConfigurationIfNeeded({
    required LoggingSecurityType securityType,
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) {
    if (_initialLogConfigurationSynced || _isInitialLogConfigurationSyncInProgress) {
      return;
    }

    _isInitialLogConfigurationSyncInProgress = true;
    unawaited(
      _syncInitialLogConfiguration(
        securityType: securityType,
        server: server,
        routingProfile: routingProfile,
        excludedRoutes: excludedRoutes,
      ).whenComplete(() {
        _isInitialLogConfigurationSyncInProgress = false;
      }),
    );
  }

  /// Applies error-only logging to the existing VPN profile in stripped mode.
  Future<void> _syncInitialLogConfiguration({
    required LoggingSecurityType securityType,
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) async {
    if (_initialLogConfigurationSynced || !mounted) {
      return;
    }

    if (securityType == LoggingSecurityType.stripped) {
      final controller = VpnScope.vpnControllerOf(context, listen: false);

      if (controller.state != VpnState.disconnected) {
        await controller.start(
          server: server,
          routingProfile: routingProfile,
          excludedRoutes: excludedRoutes,
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
        await controller.updateConfiguration(
          server: server,
          routingProfile: routingProfile,
          excludedRoutes: excludedRoutes,
        );
      }
    }

    _initialLogConfigurationSynced = true;
  }
}
