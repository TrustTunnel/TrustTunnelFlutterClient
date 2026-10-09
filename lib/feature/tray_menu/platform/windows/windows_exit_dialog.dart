import 'package:flutter/services.dart';

/// Windows returns true for Quit and false for staying open (also if already open).
/// Unlike macOS, native display failures are channel errors, not cancel results.
enum WindowsExitDialogResult {
  quit,
  cancel,
}

final class WindowsExitDialog {
  static const MethodChannel _channel = MethodChannel('trusttunnel/windows_exit_dialog');

  const WindowsExitDialog._();

  /// Closes the exit dialog for the correct installer launch.
  ///
  /// This method is used in situations where the installer begins an update while the exit dialog is already open.
  static Future<void> closeForCorrectInstallerLaunch() => _channel.invokeMethod<void>('cancelForInstaller');

  static Future<WindowsExitDialogResult> show({
    required String title,
    required String message,
    required String quitButtonText,
    required String dontQuitButtonText,
  }) async {
    final quit = await _channel.invokeMethod<bool>(
      'show',
      {
        'title': title,
        'message': message,
        'quitButtonText': quitButtonText,
        'dontQuitButtonText': dontQuitButtonText,
      },
    );

    if (quit == null) {
      throw StateError('Windows exit dialog returned no result');
    }

    return quit ? WindowsExitDialogResult.quit : WindowsExitDialogResult.cancel;
  }
}
