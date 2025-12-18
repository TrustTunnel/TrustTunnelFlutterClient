import 'dart:convert';

import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:vpn_plugin/models/upstream_protocol.dart';

class UpStreamProtocolEncoder extends Converter<VpnProtocol, UpStreamProtocol> {
  @override
  UpStreamProtocol convert(VpnProtocol protocol) => switch (protocol) {
    VpnProtocol.http2 => UpStreamProtocol.http2,
    VpnProtocol.quic => UpStreamProtocol.http3,
  };
}
