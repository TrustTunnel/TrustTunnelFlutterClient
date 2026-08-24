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

class _VpnUpdateManagerState extends State<VpnUpdateManager> {
  Server? _selectedServer;
  RoutingProfile? _selectedRoutingProfile;
  List<String>? _excludedRoutes;
  VpnConfigurationLogLevel? _selectedLogLevel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final serverScope = ServersScope.controllerOf(
      context,
      aspect: ServersScopeAspect.selectedServer,
    );

    final updatedServer = serverScope.selectedServer;

    final loggingController = AppLoggingScope.controllerOf(context);
    final currentNeededVpnConfigurationLogLevel = switch (loggingController.securityType) {
      LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
      LoggingSecurityType.full => switch (loggingController.loggingLevel) {
        LoggingLevel.defaultLevel => VpnConfigurationLogLevel.info,
        LoggingLevel.debug => VpnConfigurationLogLevel.debug,
      },
    };

    _selectedLogLevel ??= currentNeededVpnConfigurationLogLevel;

    final updatedRoutingProfileList = RoutingScope.controllerOf(
      context,
      aspect: RoutingScopeAspect.profiles,
    ).routingList;

    final excludedRoutesController = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.routes,
    );

    final updatedExcludedRoutes = excludedRoutesController.excludedRoutes;

    final vpnController = VpnScope.vpnControllerOf(
      context,
      listen: false,
    );

    _selectedServer ??= updatedServer;

    bool wasDeleted =
        serverScope.servers.firstWhereOrNull(
          (element) => element.id == _selectedServer?.id,
        ) ==
        null;

    if (_selectedServer == null || (!wasDeleted && updatedServer == null)) {
      return;
    }

    if (serverScope.servers.isNotEmpty && updatedServer == null) {
      serverScope.fetchServers();

      return;
    }

    final updatedRoutingProfile = updatedRoutingProfileList.firstWhereOrNull(
      (element) => element.id == updatedServer?.serverData.routingProfileId,
    );

    _selectedRoutingProfile ??= updatedRoutingProfile;

    if (updatedRoutingProfile == null) {
      serverScope.fetchServers();

      return;
    }

    _excludedRoutes ??= updatedExcludedRoutes;

    if (_excludedRoutes == null) {
      excludedRoutesController.fetchExcludedRoutes();

      return;
    }

    final bool isConfigurationChanged =
        _selectedServer != updatedServer ||
        _selectedRoutingProfile != updatedRoutingProfile ||
        _selectedLogLevel != currentNeededVpnConfigurationLogLevel ||
        !listEquals(_excludedRoutes, updatedExcludedRoutes);

    if (isConfigurationChanged) {
      if ((_selectedServer?.id == updatedServer?.id && vpnController.state == VpnState.disconnected) || wasDeleted) {
        if (wasDeleted && serverScope.servers.isEmpty) {
          _deleteConfig(controller: vpnController);

          return;
        }

        _updateStoredConfiguration(
          controller: vpnController,
          server: updatedServer!,
          routingProfile: updatedRoutingProfile,
          excludedRoutes: updatedExcludedRoutes,
          logLevel: currentNeededVpnConfigurationLogLevel,
        );
      } else {
        _restartVpnService(
          controller: vpnController,
          server: updatedServer!,
          routingProfile: updatedRoutingProfile,
          excludedRoutes: updatedExcludedRoutes,
          logLevel: currentNeededVpnConfigurationLogLevel,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

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
    _selectedLogLevel = logLevel;

    await controller.stop();
    await controller.updateConfiguration(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
  }

  Future<void> _deleteConfig({
    required VpnController controller,
  }) async {
    _selectedServer = null;
    _selectedRoutingProfile = null;
    _excludedRoutes = null;
    _selectedLogLevel = null;
    await controller.deleteConfiguration();
  }

  Future<void> _restartVpnService({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnController controller,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = excludedRoutes;
    _selectedLogLevel = logLevel;
    await controller.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
  }
}
