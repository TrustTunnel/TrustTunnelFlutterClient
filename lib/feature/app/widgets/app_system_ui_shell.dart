import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/feature/app/widgets/app_custom_macos_title_bar.dart';

class AppSystemUIShell extends StatelessWidget {
  final Widget child;

  const AppSystemUIShell({
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return Column(
        children: [
          const AppCustomMacOSTitleBar(),
          Expanded(
            child: child,
          ),
        ],
      );
    }

    return child;
  }
}
