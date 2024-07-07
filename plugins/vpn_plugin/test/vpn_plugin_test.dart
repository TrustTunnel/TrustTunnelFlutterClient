import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_plugin/vpn_plugin.dart';
import 'package:vpn_plugin/vpn_plugin_platform_interface.dart';
import 'package:vpn_plugin/vpn_plugin_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockVpnPluginPlatform
    with MockPlatformInterfaceMixin
    implements VpnPluginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final VpnPluginPlatform initialPlatform = VpnPluginPlatform.instance;

  test('$MethodChannelVpnPlugin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelVpnPlugin>());
  });

  test('getPlatformVersion', () async {
    VpnPlugin vpnPlugin = VpnPlugin();
    MockVpnPluginPlatform fakePlatform = MockVpnPluginPlatform();
    VpnPluginPlatform.instance = fakePlatform;

    expect(await vpnPlugin.getPlatformVersion(), '42');
  });
}
