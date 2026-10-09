import 'package:flutter/services.dart';

/// {@template tray_callback_api}
/// Interface for receiving callbacks from native tray menu.
/// {@endtemplate}
abstract class TrayCallbackApi {
  /// Called when a menu item with [id] is clicked.
  void Function(String id) get onMenuItemClicked;

  /// Reports native Shell errors independently of user menu actions.
  void Function(PlatformException error)? get onError;
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
    final errorChannel = BasicMessageChannel<Object?>(
      '$channelPrefix/trayCallbackApi/onError$suffix',
      _codec,
      binaryMessenger: binaryMessenger,
    );

    if (api == null) {
      channel.setMessageHandler(null);
      errorChannel.setMessageHandler(null);

      return;
    }

    errorChannel.setMessageHandler((Object? message) async {
      if (message is List<Object?> && message.length == 3 && message[0] is String) {
        api.onError?.call(
          PlatformException(
            code: message[0]! as String,
            message: message[1] as String?,
            details: message[2],
          ),
        );
      }

      return <Object?>[];
    });

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
