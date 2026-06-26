import 'package:flutter/services.dart';

enum ExitDialogResult {
  quit,
  dontQuit,
}

final class MacosExitDialog {
  static const MethodChannel _channel = MethodChannel('trusttunnel/macos_exit_dialog');

  const MacosExitDialog._();

  static Future<ExitDialogResult> show({
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

      return quit == true ? ExitDialogResult.quit : ExitDialogResult.dontQuit;
    } on MissingPluginException {
      return ExitDialogResult.dontQuit;
    }
  }
}
