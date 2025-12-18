import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card_connection_button.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/widgets/common/custom_list_tile_separated.dart';

class ServersCard extends StatefulWidget {
  final Server server;

  const ServersCard({
    super.key,
    required this.server,
  });

  @override
  State<ServersCard> createState() => _ServersCardState();
}

class _ServersCardState extends State<ServersCard> {
  late VpnState _vpnStatus;

  late Server? _pickedServer;

  @override
  void initState() {
    super.initState();
    _vpnStatus = VpnScope.vpnControllerOf(context, listen: false).state;
    _pickedServer = ServersScope.controllerOf(context, listen: false).selectedServer;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vpnStatus = VpnScope.vpnControllerOf(context).state;
    _pickedServer = ServersScope.controllerOf(context).selectedServer;
  }

  @override
  Widget build(BuildContext context) {
    final vpnManagerState = _pickedServer?.id == widget.server.id ? _vpnStatus : VpnState.disconnected;

    return CustomListTileSeparated(
      title: widget.server.name,
      titleStyle: context.textTheme.titleSmall,
      subtitle: widget.server.ipAddress,
      onTileTap: () => _pushServerDetailsScreen(
        context,
        server: widget.server,
      ),
      trailing: ServersCardConnectionButton(
        vpnManagerState: vpnManagerState,
        onPressed: () {
          if (vpnManagerState != VpnState.disconnected && widget.server.id == _pickedServer?.id) {
            _disconnectFromVpn(context);
            _changeServer(context, null);
          } else {
            _connectToVpn(context, widget.server);
            _changeServer(context, widget.server.id);
          }
        },
        serverId: widget.server.id,
      ),
    );
  }

  void _changeServer(BuildContext context, int? serverId) =>
      ServersScope.controllerOf(context, listen: false).pickServer(serverId);
  Future<void> _disconnectFromVpn(BuildContext context) {
    final controller = VpnScope.vpnControllerOf(context);

    return controller.stop();
  }

  Future<void> _connectToVpn(
    BuildContext context,
    Server server,
  ) async {
    final controller = VpnScope.vpnControllerOf(context, listen: false);
    final excludedRoutes = ExcludedRoutesScope.controllerOf(context, listen: false).excludedRoutes;

    await controller.start(
      server: server,
      routingProfile: server.routingProfile,
      excludedRoutes: excludedRoutes,
    );
  }

  void _pushServerDetailsScreen(
    BuildContext context, {
    required Server server,
  }) => context.push(
    ServerDetailsPopUp(
      serverId: server.id,
    ),
  );
}
