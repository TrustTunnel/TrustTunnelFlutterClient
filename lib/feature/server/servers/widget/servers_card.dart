import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/server/server_details/widgets/server_details_popup.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card_connection_button.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
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
  late VpnController _vpnController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _vpnController = VpnScope.vpnControllerOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final vpnConnectionState = _vpnController.hasPendingStart ? VpnState.connecting : _vpnController.state;
    final vpnManagerState = _vpnController.currentlyConnectedServerId == widget.server.id
        ? vpnConnectionState
        : VpnState.disconnected;

    return CustomListTileSeparated(
      title: widget.server.serverData.name,
      titleStyle: context.textTheme.titleSmall,
      subtitle: widget.server.serverData.ipAddress,
      onTileTap: () => _pushServerDetailsScreen(
        context,
        server: widget.server,
      ),
      trailing: ServersCardConnectionButton(
        vpnManagerState: vpnManagerState,
        onPressed: () {
          final isCurrentlyConnecting =
              (_vpnController.state != VpnState.disconnected || _vpnController.hasPendingStart);
          if (_vpnController.currentlyConnectedServerId == widget.server.id && isCurrentlyConnecting) {
            _vpnController.disconnect();
          } else {
            _vpnController.selectAndConnectToServer(widget.server.id);
          }
        },
      ),
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
