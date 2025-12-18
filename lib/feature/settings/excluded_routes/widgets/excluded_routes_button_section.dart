import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_aspect.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

class ExcludedRoutesButtonSection extends StatefulWidget {
  const ExcludedRoutesButtonSection({
    super.key,
  });

  @override
  State<ExcludedRoutesButtonSection> createState() => _ExcludedRoutesButtonSectionState();
}

class _ExcludedRoutesButtonSectionState extends State<ExcludedRoutesButtonSection> {
  late bool _canSave;
  late List<String> _excludedRoutes;

  @override
  void initState() {
    super.initState();
    _canSave = ExcludedRoutesScope.controllerOf(context, listen: false).canSave;
    _excludedRoutes = ExcludedRoutesScope.controllerOf(context, listen: false).excludedRoutes;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dataUpdate = ExcludedRoutesScope.controllerOf(context, aspect: ExcludedRoutesAspect.data);
    _canSave = dataUpdate.canSave;
    _excludedRoutes = dataUpdate.excludedRoutes;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: context.isMobileBreakpoint ? CrossAxisAlignment.stretch : CrossAxisAlignment.end,
    children: [
      const Divider(),
      Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _canSave ? () => _saveExcludedRoutes(context) : null,
          child: Text(context.ln.save),
        ),
      ),
    ],
  );

  void _saveExcludedRoutes(BuildContext context) =>
      ExcludedRoutesScope.controllerOf(context, listen: false).submit(() => _onExcludedRoutesSaved(context));

  void _onExcludedRoutesSaved(BuildContext context) {
    if (Navigator.canPop(context)) {
      context.pop();
    }

    _onUpdated(
      VpnScope.vpnControllerOf(context, listen: false),
      ServersScope.controllerOf(context, listen: false),
      RoutingScope.controllerOf(context, listen: false),
      ExcludedRoutesScope.controllerOf(context, listen: false),
      _excludedRoutes,
    );
  }

  void _onUpdated(
    VpnController controller,
    ServersScopeController serverController,
    RoutingScopeController profileController,
    ExcludedRoutesScopeController excludedRoutesController,
    List<String> excludedRoutes,
  ) {
    excludedRoutesController.fetchExcludedRoutes();

    final selectedServer = serverController.servers.firstWhereOrNull(
      (server) => server.id == serverController.selectedServer?.id,
    );
    final profile = profileController.routingList.firstWhereOrNull(
      (profile) => profile.id == selectedServer?.routingProfile.id,
    );

    if (selectedServer != null && profile != null) {
      bool running = controller.state != VpnState.disconnected;

      if (running) {
        controller.start(
          server: selectedServer,
          routingProfile: profile,
          excludedRoutes: excludedRoutes,
        );
      }
    }
  }
}
