import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:window_manager/window_manager.dart';

final class MacOSAppWindowController implements AppWindowController {
  static const MethodChannel _mainWindowChannel = MethodChannel('trusttunnel/macos_main_window');

  MacOSAppWindowController()
    : assert(
        defaultTargetPlatform == TargetPlatform.macOS,
        'MacOSAppWindowController is only supported on macOS',
      );

  @override
  Future<void> showMainWindow() async => await _mainWindowChannel.invokeMethod<void>('show');

  @override
  Future<void> hideMainWindow() async => await _mainWindowChannel.invokeMethod<void>('hide');

  /// Configure the main window for macOS.
  ///
  /// - [minimumWindowSize] is the minimum size of the window.
  /// - [defaultWindowSize] is the default size of the window.
  /// - [isDebugMode] is a flag to indicate if the app is running in debug mode.
  /// If true, the window will be configured without minimum size.
  @override
  Future<void> configureMainWindow({
    required Size minimumWindowSize,
    required Size defaultWindowSize,
    required bool isDebugMode,
  }) async {
    final shouldShowMainWindowOnLaunch = await _shouldShowMainWindowOnLaunch();

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

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await windowManager.show();
          await windowManager.focus();
        });
      },
    );
  }

  Future<bool> _shouldShowMainWindowOnLaunch() async =>
      await _mainWindowChannel.invokeMethod<bool>('shouldShowMainWindowOnLaunch') ?? true;

  double _clampWindowDimension({
    required double defaultDimension,
    required double minimumDimension,
    required double visibleDimension,
  }) => defaultDimension
      .clamp(
        minimumDimension,
        math.max(minimumDimension, visibleDimension),
      )
      .toDouble();
}
