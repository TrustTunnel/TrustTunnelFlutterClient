import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';
import 'package:trusttunnel/feature/tray_menu/platform/macos/macos_exit_dialog.dart';
import 'package:trusttunnel/feature/tray_menu/platform/windows/windows_exit_dialog.dart';

/// Handles platform exit requests using the VPN state and queue owned by the scope.
mixin VpnScopeExitHandlingMixin<T extends StatefulWidget> on State<T> {
  /// On Windows, `stop()` only queues service work, so `disconnected` may never arrive if it fails.
  /// Limit the wait to avoid leaving the app exit request pending forever.
  static const _windowsDisconnectOnExitTimeout = Duration(seconds: 5);

  /// The pending exit request for Windows (the same reason as with the timeout)
  Future<AppExitResponse>? _windowsExitRequest;

  @protected
  bool get shouldShowExitDialog;

  @protected
  bool get isVpnDisconnectedForExit;

  @protected
  AppWindowController? get appWindowController;

  @protected
  void beginVpnExit();

  /// Clears only the exit flag; cancelled connection requests stay cancelled.
  @protected
  void cancelVpnExit();

  @protected
  Future<void> stopVpnForExit({Duration? timeout});

  @protected
  Future<void> notifyVpnOperationError();

  /// Handles the app exit requested event.
  ///
  /// This type of error handling is necessary here because if the `onExitRequested` handler throws an exception,
  /// Flutter will log it but will not count it as a refusal to exit.
  /// If no one explicitly returns `cancel`, the result will be an exit.
  Future<AppExitResponse> handleAppExitRequested() async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final pendingExitRequest = _windowsExitRequest;
      if (pendingExitRequest != null) {
        return pendingExitRequest;
      }

      try {
        final exitRequest = _handleWindowsExitRequested().catchError((
          Object error,
          StackTrace stackTrace,
        ) async {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
          await notifyVpnOperationError();

          return AppExitResponse.cancel;
        });
        _windowsExitRequest = exitRequest;

        final response = await exitRequest;
        if (response == AppExitResponse.cancel && mounted) {
          cancelVpnExit();
        }

        return response;
      } finally {
        _windowsExitRequest = null;
      }
    }

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      try {
        final response = await _handleMacosExitRequested();
        if (response == AppExitResponse.cancel && mounted) {
          cancelVpnExit();
        }

        return response;
      } catch (error, stackTrace) {
        if (mounted) {
          cancelVpnExit();
        }
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
        await notifyVpnOperationError();

        return AppExitResponse.cancel;
      }
    }

    beginVpnExit();

    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _handleMacosExitRequested() async {
    final appWindowController = this.appWindowController;
    if (appWindowController == null) {
      throw StateError('AppWindowController must be provided on macOS');
    }

    if (shouldShowExitDialog) {
      final localization = Localization.ln;
      final result =
          await MacosExitDialog.show(
            title: localization.exitDialogTitle,
            message: localization.exitDialogDescription,
            quitButtonText: localization.quit,
            dontQuitButtonText: localization.dontQuit,
          ).onError((_, _) async {
            // Here, we ignore the error and the stack trace, since these are native dialogs,
            // and we don't need to know the full stack trace anyway, as the relevant section will be visible
            // (showing that the error occurred in them).
            await notifyVpnOperationError();

            return MacosExitDialogResult.cancel;
          });
      if (!mounted || result != MacosExitDialogResult.quit) {
        return AppExitResponse.cancel;
      }
    }

    beginVpnExit();
    await stopVpnForExit();
    await appWindowController.setPreventClose(false);

    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _handleWindowsExitRequested() async {
    if (shouldShowExitDialog) {
      if (!mounted) {
        return AppExitResponse.cancel;
      }
      final localization = Localization.ln;
      WindowsExitDialogResult result;

      result =
          await WindowsExitDialog.show(
            title: localization.exitDialogTitle,
            message: localization.exitDialogDescription,
            quitButtonText: localization.quit,
            dontQuitButtonText: localization.dontQuit,
          ).onError((_, _) async {
            // Here, we ignore the error and the stack trace, since these are native dialogs,
            // and we don't need to know the full stack trace anyway, as the relevant section will be visible
            // (showing that the error occurred in them).
            await notifyVpnOperationError();

            return WindowsExitDialogResult.cancel;
          });

      if (!mounted || result != WindowsExitDialogResult.quit) {
        return AppExitResponse.cancel;
      }
    }
    if (!mounted) {
      return AppExitResponse.cancel;
    }

    beginVpnExit();
    final disconnected = await _stopWindowsVpnWithWaitForDisconnection();
    if (disconnected || (mounted && isVpnDisconnectedForExit)) {
      final window = appWindowController;
      if (window is WindowsAppWindowController) {
        await window.prepareToExit();
      }

      return AppExitResponse.exit;
    }

    await notifyVpnOperationError();

    return AppExitResponse.cancel;
  }

  Future<bool> _stopWindowsVpnWithWaitForDisconnection() =>
      stopVpnForExit(timeout: _windowsDisconnectOnExitTimeout).then(
        (_) => true,
        onError: (_) => false,
      );
}
