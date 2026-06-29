import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class MacosMainWindowApi {
  static const _mainWindowChannel = MethodChannel('trusttunnel/macos_main_window');

  static Future<void> show() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    await _mainWindowChannel.invokeMethod<void>('show');
  }
}
