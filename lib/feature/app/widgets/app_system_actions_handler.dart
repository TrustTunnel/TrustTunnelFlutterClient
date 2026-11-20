import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:window_manager/window_manager.dart';

/// Handles application-level system actions.
///
/// MaterialApp.builder places it above the navigator so shortcuts also cover every route and Flutter dialog.
///
/// Add rules for other platforms as separate branches in the platform switch below,
/// and register native window listeners only on platforms that need them.
class AppSystemActionsHandler extends StatefulWidget {
  final Widget child;

  const AppSystemActionsHandler({
    required this.child,
    super.key,
  });

  @override
  State<AppSystemActionsHandler> createState() => _AppSystemActionsHandlerState();
}

class _AppSystemActionsHandlerState extends State<AppSystemActionsHandler> with WindowListener {
  final TargetPlatform _platform = defaultTargetPlatform;

  @override
  void initState() {
    super.initState();
    if (_platform == TargetPlatform.macOS || _platform == TargetPlatform.linux) {
      windowManager.addListener(this);
    }
  }

  @override
  Widget build(BuildContext context) => switch (_platform) {
    TargetPlatform.macOS => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): _hideMainWindow,
      },
      child: widget.child,
    ),
    _ => widget.child,
  };

  @override
  Future<void> onWindowClose() async {
    if (_platform == TargetPlatform.macOS) {
      _hideMainWindow();
      return;
    }

    if (_platform == TargetPlatform.linux) {
      // Asks VpnScope (via AppLifecycleListener.onExitRequested) to run the
      // exit confirmation and stop the VPN. The window is destroyed only when
      // the exit is approved.
      final response = await ServicesBinding.instance.handleRequestAppExit();
      if (response == AppExitResponse.exit) {
        await windowManager.destroy();
      }
      return;
    }
  }

  void _hideMainWindow() => unawaited(context.dependencyFactory.appWindowController.hideMainWindow());

  @override
  void dispose() {
    if (_platform == TargetPlatform.macOS || _platform == TargetPlatform.linux) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
