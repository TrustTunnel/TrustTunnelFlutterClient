import 'package:flutter/services.dart';

/// macOS returns true for Quit and false for staying open (also if already open).
/// Native code has no unavailable result; a missing channel or null reply throws.
enum MacosExitDialogResult {
  quit,
  cancel,
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
      throw StateError('macOS exit dialog returned no result');
    }

    return quit ? MacosExitDialogResult.quit : MacosExitDialogResult.cancel;
  }
}
