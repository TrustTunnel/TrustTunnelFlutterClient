import 'dart:convert';

import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_log_action.dart';
import 'package:trusttunnel/data/model/vpn_log_protocol.dart';
import 'package:vpn_plugin/models/connection_protocol.dart';
import 'package:vpn_plugin/models/query_log_action.dart';
import 'package:vpn_plugin/models/query_log_row.dart';

class VpnLogConverter extends Converter<QueryLogRow, VpnLog> {
  @override
  VpnLog convert(QueryLogRow input) => VpnLog(
    action: _parseAction(input.action),
    protocol: _parseProtocol(input.protocol),
    source: input.source,
    destination: input.destination,
    domain: input.domain,
    timeStamp: input.stamp.toLocal(),
  );

  VpnLogAction _parseAction(QueryLogAction platformAction) => switch (platformAction) {
    QueryLogAction.bypass => VpnLogAction.bypass,
    QueryLogAction.tunnel => VpnLogAction.tunnel,
    QueryLogAction.reject => VpnLogAction.reject,
  };

  VpnLogProtocol _parseProtocol(ConnectionProtocol platformProtocol) => switch (platformProtocol) {
    ConnectionProtocol.udp => VpnLogProtocol.udp,
    ConnectionProtocol.tcp => VpnLogProtocol.tcp,
  };
}
