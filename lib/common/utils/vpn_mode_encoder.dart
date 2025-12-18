import 'dart:convert';

import 'package:trusttunnel/data/model/routing_mode.dart';
import 'package:vpn_plugin/models/vpn_mode.dart';

class VpnModeEncoder extends Converter<RoutingMode, VpnMode> {
  @override
  VpnMode convert(RoutingMode routingMode) => switch (routingMode) {
    RoutingMode.vpn => VpnMode.general,
    RoutingMode.bypass => VpnMode.selective,
  };
}
