import 'package:flutter/services.dart';

enum WindowsExitDialogResult {
  quit,
}

final class WindowsExitDialog {
  static const MethodChannel _channel = MethodChannel('trusttunnel/windows_exit_dialog');

  const WindowsExitDialog._();

  static Future<WindowsExitDialogResult?> show({
    required String title,
    required String message,
    required String quitButtonText,
    required String dontQuitButtonText,
  }) async {
    try {
      final quit = await _channel.invokeMethod<bool>(
        'show',
        {
          'title': title,
          'message': message,
          'quitButtonText': quitButtonText,
          'dontQuitButtonText': dontQuitButtonText,
        },
      );

      return quit == true ? WindowsExitDialogResult.quit : null;
    } on MissingPluginException {
      return null;
    }
  }
}
