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
  final int serverId;

  const ServersCardConnectionButton({
    super.key,
    required this.serverId,
    required this.vpnManagerState,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Theme(
    data: context.theme.copyWith(
      iconButtonTheme: vpnManagerState == VpnState.connecting
          ? context.theme.extension<CustomFilledIconButtonTheme>()!.iconButtonInProgress
          : context.theme.extension<CustomFilledIconButtonTheme>()!.iconButton,
    ),
    child: vpnManagerState == VpnState.connecting
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
