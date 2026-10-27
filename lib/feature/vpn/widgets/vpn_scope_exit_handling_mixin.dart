import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/platform/linux_exit_dialog.dart';
import 'package:trusttunnel/common/platform/macos_exit_dialog.dart';
import 'package:trusttunnel/common/platform/windows_exit_dialog.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/app/controller/windows_app_window_controller.dart';

/// Owns platform exit dialogs, the Flutter response waiter and its timeout.
mixin VpnScopeExitHandlingMixin<T extends StatefulWidget> on State<T> {
  /// On Windows, `stop()` only queues service work, so `disconnected` may never arrive if it fails.
  /// Limit the wait to avoid leaving the app exit request pending forever.
  static const _windowsDisconnectOnExitTimeout = Duration(seconds: 5);

  /// The pending exit request for Windows (the same reason as with the timeout)
  Future<AppExitResponse>? _windowsExitRequest;
  Future<AppExitResponse>? _linuxExitRequest;

  /// Waits for the controller to confirm disconnection or report that the exit stop failed.
  /// Keeping this resource here lets scope disposal finish the Flutter response synchronously.
  Completer<bool>? _exitStopCompleter;

  /// One timeout covers an in-flight start, the stop native operation and its native state confirmation.
  Timer? _exitStopTimer;

  @protected
  bool get shouldShowExitDialog;

  @protected
  bool get isVpnDisconnectedForExit;

  @protected
  AppWindowController? get appWindowController;

  @protected
  void onAppExiting();

  /// Clears only the exit flag; cancelled connection requests stay cancelled.
  @protected
  void cancelVpnExit();

  @protected
  void requestVpnStopForExit();

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
          logger.logError(
            'VPN exit failed',
            error: error,
            stackTrace: stackTrace,
          );
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
        logger.logError(
          'VPN exit failed',
          error: error,
          stackTrace: stackTrace,
        );
        await notifyVpnOperationError();

        return AppExitResponse.cancel;
      }
    if (defaultTargetPlatform == TargetPlatform.linux) {
      final pendingExitRequest = _linuxExitRequest;
      if (pendingExitRequest != null) {
        return pendingExitRequest;
      }

      try {
        final exitRequest = _handleLinuxExitRequested().catchError((
          Object error,
          StackTrace stackTrace,
        ) async {
          logger.logError(
            'VPN exit failed',
            error: error,
            stackTrace: stackTrace,
          );
          await notifyVpnOperationError();

          return AppExitResponse.cancel;
        });
        _linuxExitRequest = exitRequest;

        final response = await exitRequest;
        if (response == AppExitResponse.cancel && mounted) {
          cancelVpnExit();
        }

        return response;
      } finally {
        _linuxExitRequest = null;
      }
    }

    onAppExiting();

    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _handleLinuxExitRequested() async {
    if (shouldShowExitDialog) {
      if (!mounted) {
        return AppExitResponse.cancel;
      }
      final localization = Localization.ln;
      final LinuxExitDialogResult result =
          await LinuxExitDialog.show(
            title: localization.exitDialogTitle,
            message: localization.exitDialogDescription,
            quitButtonText: localization.quit,
            dontQuitButtonText: localization.dontQuit,
          ).onError((Object error, StackTrace stackTrace) async {
            logger.logError(
              'VPN exit dialog failed',
              error: error,
              stackTrace: stackTrace,
            );
            await notifyVpnOperationError();

            return LinuxExitDialogResult.cancel;
          });
      if (!mounted || result != LinuxExitDialogResult.quit) {
        return AppExitResponse.cancel;
      }
    }
    if (!mounted) {
      return AppExitResponse.cancel;
    }

    final stopped = await stopVpnForExit(timeout: const Duration(seconds: 3));
    if (!mounted) {
      return AppExitResponse.cancel;
    }

    if (stopped || isVpnDisconnectedForExit) {
      return AppExitResponse.exit;
    }

    return AppExitResponse.cancel;
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
          ).onError((Object error, StackTrace stackTrace) async {
            logger.logError(
              'VPN exit dialog failed',
              error: error,
              stackTrace: stackTrace,
            );
            await notifyVpnOperationError();

            return MacosExitDialogResult.cancel;
          });
      if (!mounted || result != MacosExitDialogResult.quit) {
        return AppExitResponse.cancel;
      }
    }

    final stopped = await stopVpnForExit();
    if (!stopped || !mounted) {
      return AppExitResponse.cancel;
    }
    await appWindowController.setPreventClose(false);

    return AppExitResponse.exit;
  }

  Future<AppExitResponse> _handleWindowsExitRequested() async {
    if (shouldShowExitDialog) {
      if (!mounted) {
        return AppExitResponse.cancel;
      }
      final localization = Localization.ln;
      final WindowsExitDialogResult result =
          await WindowsExitDialog.show(
            title: localization.exitDialogTitle,
            message: localization.exitDialogDescription,
            quitButtonText: localization.quit,
            dontQuitButtonText: localization.dontQuit,
          ).onError((Object error, StackTrace stackTrace) async {
            logger.logError(
              'VPN exit dialog failed',
              error: error,
              stackTrace: stackTrace,
            );
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

    final disconnected = await stopVpnForExit(timeout: _windowsDisconnectOnExitTimeout);

    if (!mounted) {
      return AppExitResponse.cancel;
    }

    if (disconnected || isVpnDisconnectedForExit) {
      final window = appWindowController;
      if (window is WindowsAppWindowController) {
        await window.prepareToExit();
      }

      return AppExitResponse.exit;
    }

    return AppExitResponse.cancel;
  }

  /// Technical waiting belongs to the widget lifecycle, not immutable VPN state.
  @protected
  Future<bool> stopVpnForExit({Duration? timeout}) async {
    final pending = _exitStopCompleter;
    if (pending != null) {
      return pending.future;
    }

    final completer = Completer<bool>();
    _exitStopCompleter = completer;

    if (timeout != null) {
      _exitStopTimer = Timer(timeout, _onExitStopTimeout);
    }

    requestVpnStopForExit();

    try {
      return await completer.future;
    } finally {
      _exitStopTimer?.cancel();
      _exitStopTimer = null;
      _exitStopCompleter = null;
    }
  }

  /// Receives the controller result without reporting a native operation error a second time in the mixin.
  @protected
  void completeVpnExitStop(bool stopped) {
    final completer = _exitStopCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(stopped);
    }
  }

  @protected
  void disposeVpnExitHandling() {
    _exitStopTimer?.cancel();
    completeVpnExitStop(false);
  }

  void _onExitStopTimeout() {
    // A timed-out exit must not submit a delayed stop after exit has been cancelled.
    cancelVpnExit();
    completeVpnExitStop(false);
    unawaited(notifyVpnOperationError());
  }
}
