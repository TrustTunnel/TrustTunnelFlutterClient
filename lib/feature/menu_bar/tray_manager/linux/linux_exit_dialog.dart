import 'package:flutter/services.dart';

/// Linux returns true for Quit and false for staying open (also if already open).
/// Like on Windows, native display failures are channel errors, not cancel results.
enum LinuxExitDialogResult {
  quit,
  cancel,
}

final class LinuxExitDialog {
  static const MethodChannel _channel = MethodChannel('trusttunnel/linux_exit_dialog');

  const LinuxExitDialog._();

  static Future<LinuxExitDialogResult> show({
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
      throw StateError('Linux exit dialog returned no result');
    }

    return quit ? LinuxExitDialogResult.quit : LinuxExitDialogResult.cancel;
  }
}
