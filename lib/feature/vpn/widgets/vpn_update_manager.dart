import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

/// Observes saved configuration changes and asks the VPN scope to apply them. VPN commands belong to VpnScope.
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
  late VpnController _vpnController;
  Listenable? _sources;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sources != null) {
      return;
    }
    _vpnController = VpnScope.vpnControllerOf(context, listen: false);
    _sources = Listenable.merge([
      ServersScope.controllerOf(context, listen: false),
      RoutingScope.controllerOf(context, listen: false),
      AppLoggingScope.controllerOf(context, listen: false),
      ExcludedRoutesScope.controllerOf(context, listen: false),
      _vpnController,
    ])..addListener(_onConfigurationChanged);
    _onConfigurationChanged();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onConfigurationChanged() => unawaited(_vpnController.synchronizeConfiguration());

  @override
  void dispose() {
    _sources?.removeListener(_onConfigurationChanged);
    super.dispose();
  }
}
