import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/controller/widget/state_consumer.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_controller.dart';
import 'package:trusttunnel/feature/settings/launch_and_connection/controller/auto_connect_on_launch_state.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

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
    unawaited(_connectToLastServerIfNeeded());
  }

  @override
  Widget build(BuildContext context) => StateConsumer<AutoConnectOnLaunchSettingsController, AutoConnectOnLaunchState>(
    controller: _controller,
    listener: (_, _, _, _) => unawaited(_connectToLastServerIfNeeded()),
    builder: (_, _, child) => child!,
    child: widget.child,
  );

  Future<void> _connectToLastServerIfNeeded() async {
    final state = _controller.state;
    if (state.initial || state.loading || state.connectOnLaunchHandled) {
      return;
    }

    final serversController = ServersScope.controllerOf(context);
    if (!state.enabled || state.lastServerId == null || serversController.servers.isEmpty) {
      if (!serversController.loading) {
        await _controller.markConnectOnLaunchHandled();
      }

      return;
    }

    final server = serversController.servers.firstWhereOrNull(
      (server) => server.id == state.lastServerId,
    );
    if (server == null) {
      await _controller.markConnectOnLaunchHandled();

      return;
    }

    final routingProfile =
        RoutingScope.controllerOf(
          context,
          listen: false,
        ).routingList.firstWhereOrNull(
          (profile) => profile.id == server.serverData.routingProfileId,
        );
    if (routingProfile == null) {
      await _controller.markConnectOnLaunchHandled();

      return;
    }

    final excludedRoutes = ExcludedRoutesScope.controllerOf(
      context,
      listen: false,
    ).excludedRoutes;
    final vpnController = VpnScope.vpnControllerOf(context, listen: false);

    await _controller.markConnectOnLaunchHandled();
    await vpnController.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
