import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/extensions/theme_extensions.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/widgets/buttons/custom_icon_button.dart';
import 'package:trusttunnel/widgets/rotating_wrapper.dart';

class ServersCardConnectionButton extends StatelessWidget {
  final VpnState vpnManagerState;
  final VoidCallback onPressed;
  final String serverId;

  const ServersCardConnectionButton({
    super.key,
    required this.serverId,
    required this.vpnManagerState,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    bool pending = isPendingResult(vpnManagerState);

    return Theme(
      data: context.theme.copyWith(
        iconButtonTheme: pending
            ? context.theme.extension<CustomFilledIconButtonTheme>()!.iconButtonInProgress
            : context.theme.extension<CustomFilledIconButtonTheme>()!.iconButton,
      ),
      child: pending
          ? RotatingWidget(
              duration: const Duration(seconds: 1),
              child: CustomIconButton.square(
                icon: AssetIcons.update,
                onPressed: onPressed,
                size: 24,
                selected: true,
              ),
            )
          : CustomIconButton.square(
              icon: AssetIcons.powerSettingsNew,
              onPressed: onPressed,
              size: 24,
              selected: vpnManagerState == VpnState.connected,
            ),
    );
  }

  bool isPendingResult(VpnState state) => state != VpnState.connected && state != VpnState.disconnected;
}
