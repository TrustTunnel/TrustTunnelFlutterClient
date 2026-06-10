import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'method_channel_share_platform.dart';
import 'model/share_payload.dart';

/// Internal transport for invoking the platform share implementation.
abstract class SharePlatform extends PlatformInterface {
  SharePlatform() : super(token: _token);

  static final Object _token = Object();

  static SharePlatform _instance = MethodChannelSharePlatform();

  static SharePlatform get instance => _instance;

  static set instance(SharePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<Map<Object?, Object?>?> share(SharePayload request);
}
