import 'package:vpn_plugin/platform_api.g.dart';

extension VpnProtocolX on VpnProtocol {
  String get stringValue => name.toUpperCase();
}

extension RoutingModeX on RoutingMode {
  String get stringValue => name;
}
