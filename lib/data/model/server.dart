import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vpn/data/model/vpn_protocol.dart';

part 'server.freezed.dart';

@freezed
class Server with _$Server {
  const Server._();

  const factory Server({
    required int id,
    required String name,
    required String ipAddress,
    required String domain,
    required String login,
    required String password,
    required VpnProtocol vpnProtocol,
    required int routingProfileId,
    required List<String> dnsServers,
  }) = _Server;
}
