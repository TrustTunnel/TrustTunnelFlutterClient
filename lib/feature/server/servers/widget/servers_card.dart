import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card_connection_button.dart';
import 'package:trusttunnel/feature/server/servers/widget/servers_card_menu_button.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_controller.dart';
import 'package:trusttunnel/widgets/common/custom_list_tile_separated.dart';

class ServersCard extends StatefulWidget {
  final Server server;
  final VoidCallback? onShare;
  final VoidCallback onCopyLink;
  final VoidCallback onDuplicate;
  final VoidCallback onEdit;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<bool>? onSelectionToggle;
  final VoidCallback? onLongPress;

  const ServersCard({
    super.key,
    required this.server,
    required this.onCopyLink,
    required this.onDuplicate,
    required this.onEdit,
    this.onShare,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionToggle,
    this.onLongPress,
  });

  @override
  State<ServersCard> createState() => _ServersCardState();
}

class _ServersCardState extends State<ServersCard> {
  late VpnScopeController _vpnController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _vpnController = VpnScope.vpnControllerOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final vpnConnectionState = _vpnController.state;
    final vpnManagerState = _vpnController.activeServerId == widget.server.id
        ? vpnConnectionState
        : VpnState.disconnected;

    return CustomListTileSeparated(
      title: widget.server.serverData.name,
      titleStyle: context.textTheme.titleSmall,
      subtitle: widget.server.serverData.ipAddress,
      onTileTap: widget.selectionMode ? _toggleSelection : widget.onEdit,
      onLongPress: widget.onLongPress,
      leading: widget.selectionMode ? _buildSelectionControl() : null,
      showVerticalDivider: !widget.selectionMode,
      actionBeforeDivider: widget.selectionMode
          ? null
          : ServersCardMenuButton(
              onShare: widget.onShare,
              onCopyLink: widget.onCopyLink,
              onDuplicate: widget.onDuplicate,
            ),
      trailing: widget.selectionMode
          ? null
          : ServersCardConnectionButton(
              vpnManagerState: vpnManagerState,
              onPressed: () {
                final isCurrentlyConnecting = _vpnController.state != VpnState.disconnected;
                if (_vpnController.activeServerId == widget.server.id && isCurrentlyConnecting) {
                  _vpnController.disconnect();
                } else {
                  _vpnController.selectAndConnectToServer(widget.server.id);
                }
              },
            ),
    );
  }

  Widget _buildSelectionControl() => SizedBox(
    width: 40,
    height: 48,
    child: Center(
      child: Checkbox(
        value: widget.selected,
        onChanged: (_) => _toggleSelection(),
      ),
    ),
  );

  void _toggleSelection() => widget.onSelectionToggle?.call(!widget.selected);
}
