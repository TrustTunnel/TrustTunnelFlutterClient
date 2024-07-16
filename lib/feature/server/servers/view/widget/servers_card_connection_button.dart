import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vpn/common/assets/asset_icons.dart';
import 'package:vpn/common/extensions/context_extensions.dart';
import 'package:vpn/common/extensions/theme_extensions.dart';
import 'package:vpn/feature/server/servers/bloc/servers_bloc.dart';
import 'package:vpn/view/buttons/icon_button_svg.dart';
import 'package:vpn/view/custom_svg_picture.dart';

class ServersCardConnectionButton extends StatefulWidget {
  final bool isActive;
  final Object server;

  const ServersCardConnectionButton({
    super.key,
    required this.isActive,
    required this.server,
  });

  @override
  State<ServersCardConnectionButton> createState() =>
      _ServersCardConnectionButtonState();
}

class _ServersCardConnectionButtonState
    extends State<ServersCardConnectionButton> {
  // TODO store active server in bloc's state
  bool isActive = false;

  @override
  Widget build(BuildContext context) => Theme(
        data: context.theme.copyWith(
          iconButtonTheme: context.theme
              .extension<CustomFilledIconButtonTheme>()!
              .iconButton,
        ),
        child: IconButtonSvg.square(
          icon: AssetIcons.powerSettingsNew,
          onPressed: () => _changeServerConnectionStatus(context),
          size: 24,
          color: context.colors.staticWhite,
        ),
      );

  void _changeServerConnectionStatus(BuildContext context) {
    setState(() => isActive = !isActive);
    final serversBloc = context.read<ServersBloc>();
    widget.isActive
        ? serversBloc.add(ServersEvent.disconnectServer(server: widget.server))
        : serversBloc.add(ServersEvent.connectServer(server: widget.server));
  }
}
