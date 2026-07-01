import 'package:flutter/services.dart';

/// {@template tray_callback_api}
/// Interface for receiving callbacks from native tray menu.
/// {@endtemplate}
abstract class TrayCallbackApi {
  /// Called when a menu item with [id] is clicked.
  void Function(String id) get onMenuItemClicked;
}

/// {@template tray_callback_api_setup}
/// Sets up the platform channel for receiving tray menu click callbacks.
/// {@endtemplate}
class TrayCallbackApiSetup {
  /// Message codec for platform channel communication.
  static const MessageCodec<Object?> _codec = StandardMessageCodec();

  /// Sets up the callback channel for receiving menu item clicks.
  ///
  /// Pass `null` for [api] to unregister the handler.
  static void setUp(
    String channelPrefix,
    TrayCallbackApi? api, {
    BinaryMessenger? binaryMessenger,
    String messageChannelSuffix = '',
  }) {
    final String suffix = messageChannelSuffix.isNotEmpty ? '.$messageChannelSuffix' : '';

    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      '$channelPrefix/trayCallbackApi/onMenuItemClickedId$suffix',
      _codec,
      binaryMessenger: binaryMessenger,
    );

    if (api == null) {
      channel.setMessageHandler(null);

      return;
    }

    channel.setMessageHandler((Object? message) async {
      if (message == null || message is! List<Object?>) {
        return <Object?>[];
      }

      final List<Object?> args = message;
      final Object? token = args.isNotEmpty ? args[0] : null;
      if (token is! String) {
        return <Object?>[];
      }

      api.onMenuItemClicked(token);

      return <Object?>[];
    });
  }
}
