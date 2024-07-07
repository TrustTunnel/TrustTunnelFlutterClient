import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'vpn_plugin_method_channel.dart';

abstract class VpnPluginPlatform extends PlatformInterface {
  /// Constructs a VpnPluginPlatform.
  VpnPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static VpnPluginPlatform _instance = MethodChannelVpnPlugin();

  /// The default instance of [VpnPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelVpnPlugin].
  static VpnPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [VpnPluginPlatform] when
  /// they register themselves.
  static set instance(VpnPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
