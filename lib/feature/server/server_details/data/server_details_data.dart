import 'package:vpn/data/model/vpn_protocol.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_details_data.freezed.dart';

@freezed
class ServerDetailsData with _$ServerDetailsData {
  const ServerDetailsData._();

  const factory ServerDetailsData({
    @Default('') String serverName,
    @Default('') String vpnServerIpAddress,
    @Default('') String ipAddressDomain,
    @Default('') String username,
    @Default('') String password,
    @Default(VpnProtocol.http2) VpnProtocol protocol,
    // TODO add routingProfile
    // required RoutingProfile routingProfile,
    @Default(<String>[]) List<String> dnsServers,
  }) = _ServerDetailsData;
}
