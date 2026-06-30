import 'package:flutter/services.dart';

import 'model/share_payload.dart';
import 'share_method_channel_encoder.dart';
import 'share_platform.dart';

final class MethodChannelSharePlatform extends SharePlatform {
  static const MethodChannel _channel = MethodChannel('adg_share');

  final ShareMethodChannelEncoder _encoder;
  MethodChannelSharePlatform({
    ShareMethodChannelEncoder encoder = const ShareMethodChannelEncoder(),
  }) : _encoder = encoder;

  @override
  Future<Map<Object?, Object?>?> share(SharePayload request) =>
      _channel.invokeMapMethod<Object?, Object?>('share', _encoder.convert(request));
}
