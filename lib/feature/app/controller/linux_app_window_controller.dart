import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:window_manager/window_manager.dart';

final class LinuxAppWindowController implements AppWindowController {
  LinuxAppWindowController()
    : assert(
        defaultTargetPlatform == TargetPlatform.linux,
        'LinuxAppWindowController is only supported on Linux',
      );

  @override
  Future<void> showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hideMainWindow() => windowManager.hide();

  @override
  Future<void> setPreventClose(bool preventClose) => windowManager.setPreventClose(preventClose);

  @override
  Future<void> configureMainWindow({
    required Size minimumWindowSize,
    required Size defaultWindowSize,
    required bool isDebugMode,
  }) async {
    await windowManager.ensureInitialized();
    // The default geometry (defaultWindowSize) is set natively in
    // linux/my_application.cc; the minimum size is enforced here through
    // window_manager, mirroring the Windows controller (which also skips it
    // in debug mode to keep unresized debug windows free to move/shrink).
    if (!isDebugMode) {
      await windowManager.setMinimumSize(minimumWindowSize);
    }
    // Intercept the close request so the exit confirmation flow can run
    // before the window is destroyed.
    await setPreventClose(true);
  }
}
