part of 'server_details_bloc.dart';

@freezed
class ServerDetailsEvent with _$ServerDetailsEvent {
  const factory ServerDetailsEvent.init() = _Init;

  const factory ServerDetailsEvent.dataChanged({
    String? serverName,
    String? vpnServerIpAddress,
    String? ipAddressDomain,
    String? username,
    String? password,
    VpnProtocol? protocol,
    // TODO add routingProfile
    // RoutingProfile routingProfile,
    List<String>? dnsServers,
  }) = _DataChanged;

  const factory ServerDetailsEvent.changeLoadingStatus({
    required ServerDetailsLoadingStatus loadingStatus,
  }) = _ChangeLoadingStatus;

  const factory ServerDetailsEvent.addServer() = _AddServer;
}
