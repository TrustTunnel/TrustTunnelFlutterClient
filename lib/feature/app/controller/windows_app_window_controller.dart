import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/tray_menu/platform/windows/windows_exit_dialog.dart';
import 'package:window_manager/window_manager.dart';

final class WindowsAppWindowController implements AppWindowController {
  static const _mainWindowChannel = MethodChannel('trusttunnel/windows_main_window');
  static const _installerExitChannel = MethodChannel('trusttunnel/windows_update');
  WindowsAppWindowController()
    : assert(
        defaultTargetPlatform == TargetPlatform.windows,
        'WindowsAppWindowController is only supported on Windows',
      );

  /// Report the error and exit the application by invoking native method.
  static Future<void> failLaunch(Object error, StackTrace stackTrace) async {
    try {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Windows startup',
        ),
      );
    } finally {
      await _mainWindowChannel.invokeMethod<void>('failLaunch');
    }
  }

  /// It is used to ensure that the exit is only performed once.
  /// It is set when the installer exit is requested and cleared when the exit is complete.
  Future<void>? _installerExit;

  @override
  Future<void> showMainWindow() async => await _mainWindowChannel.invokeMethod<void>('show');

  @override
  Future<void> hideMainWindow() async => await _mainWindowChannel.invokeMethod<void>('hide');

  @override
  Future<void> setPreventClose(bool preventClose) async => await windowManager.setPreventClose(preventClose);

  /// Sizes describe the entire window in logical pixels, including its native
  /// border and Flutter title bar. The plugin converts outer bounds at the
  /// current DPI; the title bar occupies part of the remaining client area.
  @override
  Future<void> configureMainWindow({
    required Size minimumWindowSize,
    required Size defaultWindowSize,
    required bool isDebugMode,
  }) async {
    await windowManager.ensureInitialized();
    // Flutter repeats WM_CLOSE after VpnScope has approved exit. Do not block it.
    await setPreventClose(false);
    await windowManager.configureWindowsTitleBar();

    Size windowSize = defaultWindowSize;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final visibleSize = display.visibleSize ?? display.size;
      windowSize = Size(
        defaultWindowSize.width.clamp(minimumWindowSize.width, math.max(minimumWindowSize.width, visibleSize.width)),
        defaultWindowSize.height.clamp(
          minimumWindowSize.height,
          math.max(minimumWindowSize.height, visibleSize.height),
        ),
      );
    } catch (error, stackTrace) {
      // Report without rethrowing so startup can continue with the default bounds.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Windows startup',
        ),
      );
    }
    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: windowSize,
        minimumSize: isDebugMode ? null : minimumWindowSize,
      ),
    );

    await windowManager.centerWindowsWindow();
    await _mainWindowChannel.invokeMethod<void>('configure');
    // The title bar reports readiness after its layout and native hit regions
    // have been installed. The runner additionally waits for a rendered frame.
  }

  Future<void> prepareToExit() async => await _mainWindowChannel.invokeMethod<void>('prepareToExit');

  /// Initializes the installer exit handler.
  ///
  /// The standard flow isn't suitable for the installer:
  /// it can minimize the window to the system tray or run a custom exit script that prompts the user to confirm the VPN disconnection.
  ///
  /// Handles only setup's exit request. Ordinary window close keeps its usual behavior.
  Future<void> initializeInstallerExitHandler() async {
    _installerExitChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'exitForUpdate':
          _installerExit ??= _exitForInstaller();
          await _installerExit;
        case 'shutdownCancelled':
          _installerExit = null;
          await _mainWindowChannel.invokeMethod<void>('cancelUpdateExit');
        default:
          throw MissingPluginException('Unknown installer exit method: ${call.method}');
      }
    });
    await _installerExitChannel.invokeMethod<void>('ready');
  }

  Future<void> _exitForInstaller() async {
    try {
      FocusManager.instance.primaryFocus?.unfocus();
      await prepareToExit();
      await WindowsExitDialog.closeForCorrectInstallerLaunch();

      await _installerExitChannel.invokeMethod<void>('completeExit');
    } catch (error, stackTrace) {
      // Leave the process alive if exit preparation failed. Setup aborts preparation on
      // timeout and releases the launch lock.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Windows installer exit',
        ),
      );

      rethrow;
    }
  }
}
