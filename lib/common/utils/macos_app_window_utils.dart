import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

final class MacOSAppWindowUtils {
  static const _mainWindowChannel = MethodChannel('trusttunnel/macos_main_window');

  static Future<void> showMainWindow() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _throwUnsupportedError();
    }

    await _mainWindowChannel.invokeMethod<void>('show');
  }

  static Future<void> hideMainWindow() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _throwUnsupportedError();
    }

    await _mainWindowChannel.invokeMethod<void>('hide');
  }

  /// Configure the main window for macOS.
  ///
  /// - [minimumWindowSize] is the minimum size of the window.
  /// - [defaultWindowSize] is the default size of the window.
  /// - [isDebugMode] is a flag to indicate if the app is running in debug mode.
  /// If true, the window will be configured without minimum size.
  static Future<void> configureMainWindow({
    required Size minimumWindowSize,
    required Size defaultWindowSize,
    required bool isDebugMode,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _throwUnsupportedError();
    }

    final shouldShowMainWindowOnLaunch = await MacOSAppWindowUtils._shouldShowMainWindowOnLaunch();

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);

    final display = await screenRetriever.getPrimaryDisplay();
    final visibleSize = display.visibleSize ?? display.size;
    final defaultSize = Size(
      _clampWindowDimension(
        defaultDimension: defaultWindowSize.width,
        minimumDimension: minimumWindowSize.width,
        visibleDimension: visibleSize.width,
      ),
      _clampWindowDimension(
        defaultDimension: defaultWindowSize.height,
        minimumDimension: minimumWindowSize.height,
        visibleDimension: visibleSize.height,
      ),
    );
    final windowOptions = isDebugMode
        ? WindowOptions(
            center: true,
            size: defaultSize,
          )
        : WindowOptions(
            center: true,
            minimumSize: minimumWindowSize,
            size: defaultSize,
          );

    await windowManager.waitUntilReadyToShow(
      windowOptions,
      () async {
        await windowManager.setTitleBarStyle(TitleBarStyle.hidden);

        if (!shouldShowMainWindowOnLaunch) {
          return;
        }

        await windowManager.show();
        await windowManager.focus();
      },
    );
  }

  static Future<bool> _shouldShowMainWindowOnLaunch() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _throwUnsupportedError();
    }

    return await _mainWindowChannel.invokeMethod<bool>('shouldShowMainWindowOnLaunch') ?? true;
  }

  static double _clampWindowDimension({
    required double defaultDimension,
    required double minimumDimension,
    required double visibleDimension,
  }) => defaultDimension
      .clamp(
        minimumDimension,
        math.max(minimumDimension, visibleDimension),
      )
      .toDouble();

  static Never _throwUnsupportedError() => throw UnsupportedError('MacOSAppWindowUtils is only supported on macOS');
}
