import 'dart:ui';

abstract interface class AppWindowController {
  Future<void> showMainWindow();

  Future<void> hideMainWindow();

  Future<void> configureMainWindow({
    required Size minimumWindowSize,
    required Size defaultWindowSize,
    required bool isDebugMode,
  });
}
