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
