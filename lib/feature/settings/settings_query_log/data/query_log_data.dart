import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/model/network_protocol.dart';
import 'package:vpn/data/model/routing_mode.dart';

part 'query_log_data.freezed.dart';

@freezed
class QueryLogData with _$QueryLogData {
  const factory QueryLogData({
    required DateTime dateTime,
    required NetworkProtocol networkProtocol,
    required RoutingMode routingMode,
    required String originIpAddress,
    required String vpnServerIpAddress,
    required String ipAddressDomain,
  }) = _QueryLogData;
}
