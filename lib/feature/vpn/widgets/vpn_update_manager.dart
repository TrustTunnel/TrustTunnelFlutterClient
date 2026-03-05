import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_aspect.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_aspect.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vpnController = VpnScope.vpnControllerOf(
      context,
      listen: false,
    );

    if (vpnController.state == VpnState.disconnected) {
      return;
    }

    final updatedServer = ServersScope.controllerOf(context, aspect: ServersScopeAspect.selectedServer).selectedServer;

    if (_selectedServer != updatedServer && updatedServer == null) {
      vpnController.stop();
      _selectedServer = null;
      _selectedRoutingProfile = null;
      _excludedRoutes = null;

      return;
    }

    final updatedRoutingProfileList = RoutingScope.controllerOf(
      context,
      aspect: RoutingScopeAspect.profiles,
    ).routingList;

    final updatedExcludedRoutes = ExcludedRoutesScope.controllerOf(
      context,
      aspect: ExcludedRoutesAspect.data,
    ).excludedRoutes;

    final updatedRoutingProfile = updatedRoutingProfileList.firstWhere(
      (element) => element.id == _selectedRoutingProfile?.id,
    );

    if (_selectedServer != updatedServer ||
        _selectedRoutingProfile != updatedRoutingProfile ||
        !listEquals(_excludedRoutes, updatedExcludedRoutes)) {
      _runUpdatedInfo(
        controller: vpnController,
        server: updatedServer!,
        routingProfile: updatedRoutingProfile,
        excludedRoutes: updatedExcludedRoutes,
      );
    }
  }

  /* #endregion */

  @override
  Widget build(BuildContext context) => widget.child;

  void _runUpdatedInfo({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnController controller,
  }) {
    controller.updateConfiguration(server: server, routingProfile: routingProfile, excludedRoutes: excludedRoutes);

    _selectedServer = server;
    _selectedRoutingProfile = routingProfile;
    _excludedRoutes = excludedRoutes;
  }

  @override
  void dispose() {
    // Permanent removal of a tree stent
    super.dispose();
  }
}
