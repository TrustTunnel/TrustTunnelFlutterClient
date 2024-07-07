import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vpn_plugin_platform_interface.dart';

/// An implementation of [VpnPluginPlatform] that uses method channels.
class MethodChannelVpnPlugin extends VpnPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('vpn_plugin');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
