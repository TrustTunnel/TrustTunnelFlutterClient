import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_state.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

/// Restores the last VPN connection when automatic connection on launch is enabled.
class AutoConnectOnLaunchSettingsScope extends StatefulWidget {
  final Widget child;

  const AutoConnectOnLaunchSettingsScope({
    required this.child,
    super.key,
  });

  @override
  State<AutoConnectOnLaunchSettingsScope> createState() => _AutoConnectOnLaunchSettingsScopeState();
}

class _AutoConnectOnLaunchSettingsScopeState extends State<AutoConnectOnLaunchSettingsScope> {
  late final AutoConnectOnLaunchSettingsController _controller;
  Future<void>? _connectToLastServerFuture;

  @override
  void initState() {
    super.initState();

    _controller = AutoConnectOnLaunchSettingsController(
      repository: context.repositoryFactory.autoConnectOnLaunchSettingsRepository,
    );

    _controller.fetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleConnectToLastServerIfNeeded();
  }

  @override
  Widget build(BuildContext context) => StateConsumer<AutoConnectOnLaunchSettingsController, AutoConnectOnLaunchState>(
    controller: _controller,
    listener: (_, _, _, _) => _scheduleConnectToLastServerIfNeeded(),
    builder: (_, _, child) => child!,
    child: widget.child,
  );

  /// Starts at most one connection attempt while dependencies update.
  void _scheduleConnectToLastServerIfNeeded() {
    if (_connectToLastServerFuture != null) {
      return;
    }

    final future = _connectToLastServerIfNeeded();
    _connectToLastServerFuture = future;
    unawaited(
      future.whenComplete(() {
        _connectToLastServerFuture = null;
      }),
    );
  }

  /// Connects once to the saved server after settings and server data are ready.
  /// Invalid saved configuration is marked as handled without connecting.
  Future<void> _connectToLastServerIfNeeded() async {
    // Wait until settings are loaded and skip an already handled launch.
    final state = _controller.state;
    if (state.initial || state.loading || state.connectOnLaunchHandled) {
      return;
    }

    final loggingController = AppLoggingScope.controllerOf(context);
    if (loggingController.loading) {
      return;
    }

    // Wait for servers, or finish when auto-connect has no usable target.
    final serversController = ServersScope.controllerOf(context);
    if (!state.enabled || state.lastServerId == null || serversController.servers.isEmpty) {
      if (!serversController.loading) {
        _controller.markConnectOnLaunchHandled();
      }

      return;
    }

    // Resolve the server saved by the previous successful selection.
    final server = serversController.servers.firstWhereOrNull(
      (server) => server.id == state.lastServerId,
    );
    if (server == null) {
      _controller.markConnectOnLaunchHandled();

      return;
    }

    // Resolve the routing profile required by the saved server.
    final routingProfile =
        RoutingScope.controllerOf(
          context,
          listen: false,
        ).routingList.firstWhereOrNull(
          (profile) => profile.id == server.serverData.routingProfileId,
        );
    if (routingProfile == null) {
      _controller.markConnectOnLaunchHandled();

      return;
    }

    // Read the remaining connection settings without subscribing to updates.
    final excludedRoutes = ExcludedRoutesScope.controllerOf(
      context,
      listen: false,
    ).excludedRoutes;
    final vpnController = VpnScope.vpnControllerOf(context, listen: false);

    // Mark the launch handled before handing the connection to the VPN controller.
    _controller.markConnectOnLaunchHandled();
    await vpnController.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: switch (loggingController.securityType) {
        LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
        LoggingSecurityType.full => VpnConfigurationLogLevel.debug,
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
