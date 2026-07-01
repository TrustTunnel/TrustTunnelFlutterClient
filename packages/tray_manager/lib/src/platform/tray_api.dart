import 'package:flutter/services.dart';

/// {@template tray_api}
/// Low-level platform channel API for tray operations.
///
/// Communicates with the native macOS plugin via [BasicMessageChannel].
/// Use [TrayManagerApi] for a higher-level interface.
/// {@endtemplate}
class TrayApi {
  /// Message codec for platform channel communication.
  static const MessageCodec<Object?> _codec = StandardMessageCodec();

  /// Platform-specific channel prefix.
  final String _channelPrefix;

  /// Optional custom binary messenger for testing.
  final BinaryMessenger? _binaryMessenger;

  /// Optional suffix appended to channel names.
  final String _messageChannelSuffix;

  TrayApi(
    this._channelPrefix, {
    BinaryMessenger? binaryMessenger,
    String messageChannelSuffix = '',
  }) : _binaryMessenger = binaryMessenger,
       _messageChannelSuffix = messageChannelSuffix.isNotEmpty ? '.$messageChannelSuffix' : '';

  /// Initializes the native tray with menu [items].
  Future<void> initTray(List<Map<String, Object?>> items) async {
    final String channelName = '$_channelPrefix/trayApi/initTray$_messageChannelSuffix';
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      channelName,
      _codec,
      binaryMessenger: _binaryMessenger,
    );

    final Object? reply = await channel.send(<Object?>[items]);
    _throwIfErrorReply(reply, channelName);
  }

  /// Updates the native tray menu with new [items].
  Future<void> updateMenu(List<Map<String, Object?>> items) async {
    final String channelName = '$_channelPrefix/trayApi/updateMenu$_messageChannelSuffix';
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      channelName,
      _codec,
      binaryMessenger: _binaryMessenger,
    );

    final Object? reply = await channel.send(<Object?>[items]);
    _throwIfErrorReply(reply, channelName);
  }

  /// Disposes the native tray icon and menu.
  Future<void> disposeTray() async {
    final String channelName = '$_channelPrefix/trayApi/disposeTray$_messageChannelSuffix';
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      channelName,
      _codec,
      binaryMessenger: _binaryMessenger,
    );

    final Object? reply = await channel.send(null);
    _throwIfErrorReply(reply, channelName);
  }

  /// Sets the tray icon from PNG bytes.
  ///
  /// [isMonochrome] enables template mode on macOS.
  Future<void> setTrayIconPng(
    Uint8List iconPng,
    bool isMonochrome,
  ) async {
    final String channelName = '$_channelPrefix/trayApi/setTrayIconPng$_messageChannelSuffix';
    final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
      channelName,
      _codec,
      binaryMessenger: _binaryMessenger,
    );

    final Object? reply = await channel.send(<Object?>[iconPng, isMonochrome]);
    _throwIfErrorReply(reply, channelName);
  }
}

void _throwIfErrorReply(Object? reply, String channelName) {
  if (reply == null) {
    throw PlatformException(
      code: 'channel-error',
      message: 'Unable to establish connection on channel: "$channelName".',
    );
  }

  if (reply is List<Object?> && reply.length > 1) {
    throw PlatformException(
      code: reply[0]! as String,
      message: reply[1] as String?,
      details: reply[2],
    );
  }
}
