import 'package:flutter/material.dart';
import 'package:trusttunnel/common/assets/asset_icons.dart';
import 'package:window_manager/window_manager.dart';

class AppWindowsCaptionIcon extends StatelessWidget {
  final WindowsCaptionButton button;
  final bool maximized;
  final Color color;

  const AppWindowsCaptionIcon({
    required this.button,
    required this.maximized,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (button) {
      WindowsCaptionButton.minimize => AssetIcons.windowsMinimize,
      WindowsCaptionButton.maximize => maximized ? AssetIcons.windowsRestore : AssetIcons.windowsMaximize,
      WindowsCaptionButton.close => AssetIcons.windowsExit,
    };

    return Icon(
      icon,
      color: color,
      size: 10,
      applyTextScaling: false,
    );
  }
}
