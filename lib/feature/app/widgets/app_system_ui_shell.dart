import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/app/widgets/app_custom_macos_title_bar.dart';
import 'package:trusttunnel/feature/app/widgets/app_custom_windows_title_bar.dart';

class AppSystemUIShell extends StatelessWidget {
  final Widget child;

  const AppSystemUIShell({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows) {
      return child;
    }

    return Column(
      children: [
        if (defaultTargetPlatform == TargetPlatform.windows)
          const AppCustomWindowsTitleBar()
        else
          const AppCustomMacOSTitleBar(),
        Expanded(
          child: child,
        ),
      ],
    );
  }
}
