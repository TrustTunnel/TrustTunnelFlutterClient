import 'package:flutter/services.dart';

enum MacosExitDialogResult {
  quit,
  dontQuit,
}

final class MacosExitDialog {
  static const MethodChannel _channel = MethodChannel('trusttunnel/macos_exit_dialog');

  const MacosExitDialog._();

  static Future<MacosExitDialogResult> show({
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

      return quit == true ? MacosExitDialogResult.quit : MacosExitDialogResult.dontQuit;
    } on MissingPluginException {
      return MacosExitDialogResult.dontQuit;
    }
  }
}
