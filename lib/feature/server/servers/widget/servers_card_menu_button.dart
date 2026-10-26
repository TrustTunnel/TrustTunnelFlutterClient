import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/server/server_sharing/widgets/scope/server_sharing_scope.dart';
import 'package:trusttunnel/widgets/custom_icon.dart';

enum ServersCardMenuButtonAction {
  share,
  copyLink,
  duplicate,
}

class ServersCardMenuButton extends StatelessWidget {
  final VoidCallback? onShare;
  final VoidCallback onCopyLink;
  final VoidCallback onDuplicate;
  final double menuWidth;
  final double buttonWidth;

  const ServersCardMenuButton({
    required this.onCopyLink,
    required this.onDuplicate,
    this.onShare,
    this.menuWidth = 200,
    this.buttonWidth = 40,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final canShare = onShare != null;
    final isLoading = ServerSharingScope.controllerOf(context).loading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: PopupMenuButton<ServersCardMenuButtonAction>(
        tooltip: '',
        position: PopupMenuPosition.under,
        offset: Offset((menuWidth - buttonWidth) / 2 - 16, 0),
        constraints: BoxConstraints.tightFor(width: menuWidth),
        menuPadding: EdgeInsets.zero,
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(buttonWidth, 48)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: CustomIcon(
          icon: AssetIcons.moreVert,
          size: 24,
          color: context.colors.neutralLight,
        ),
        onSelected: _onSelected,
        itemBuilder: (context) => [
          PopupMenuItem<ServersCardMenuButtonAction>(
            value: canShare ? ServersCardMenuButtonAction.share : ServersCardMenuButtonAction.copyLink,
            enabled: !isLoading,
            height: 64,
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 24,
              bottom: 16,
            ),
            child: Row(
              spacing: 12,
              children: [
                CustomIcon(
                  icon: canShare ? AssetIcons.share : AssetIcons.copy,
                ),
                Text(
                  canShare ? context.ln.share : context.ln.copyLink,
                  style: context.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          PopupMenuItem<ServersCardMenuButtonAction>(
            value: ServersCardMenuButtonAction.duplicate,
            height: 64,
            padding: const EdgeInsets.only(
              left: 12,
              right: 12,
              top: 16,
              bottom: 24,
            ),
            child: Row(
              spacing: 12,
              children: [
                const CustomIcon(icon: AssetIcons.duplicate),
                Text(context.ln.duplicate, style: context.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSelected(ServersCardMenuButtonAction action) {
    switch (action) {
      case ServersCardMenuButtonAction.share:
        onShare?.call();
      case ServersCardMenuButtonAction.copyLink:
        onCopyLink();
      case ServersCardMenuButtonAction.duplicate:
        onDuplicate();
    }
  }
}
