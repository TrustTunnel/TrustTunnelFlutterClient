import 'dart:async';
import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/raw/add_server_request.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class ServerRepository {
  Future<Server> addNewServer({required AddServerRequest request});

  Future<List<Server>> getAllServers();

  Future<Server?> getServerById({required int id});

  Future<void> setSelectedServerId({required int id});

  Future<void> setNewServer({required int id, required AddServerRequest request});

  Future<void> removeServer({required int serverId});
}

class ServerRepositoryImpl implements ServerRepository {
  final ServerDataSource _serverDataSource;
  final RoutingDataSource _routingDataSource;

  ServerRepositoryImpl({
    required ServerDataSource serverDataSource,
    required RoutingDataSource routingDataSource,
  }) : _serverDataSource = serverDataSource,
       _routingDataSource = routingDataSource;

  @override
  Future<Server> addNewServer({required AddServerRequest request}) async {
    final server = await _serverDataSource.addNewServer(
      request: request,
    );

    final profile = await _routingDataSource.getProfileById(
      id: request.routingProfileId,
    );

    return Server(
      id: server.id,
      name: server.name,
      ipAddress: server.ipAddress,
      domain: server.domain,
      username: server.username,
      password: server.password,
      vpnProtocol: server.vpnProtocol,
      dnsServers: server.dnsServers,
      routingProfile: profile,
    );
  }

  @override
  Future<List<Server>> getAllServers() async {
    final profiles = await _routingDataSource.getAllProfiles();
    final servers = await _serverDataSource.getAllServers();
    final profilesMap = Map.fromEntries(profiles.map((e) => MapEntry(e.id, e)));

    return servers
        .map(
          (e) => Server(
            id: e.id,
            name: e.name,
            ipAddress: e.ipAddress,
            domain: e.domain,
            username: e.username,
            password: e.password,
            vpnProtocol: e.vpnProtocol,
            dnsServers: e.dnsServers,
            routingProfile: profilesMap[e.routingProfileId]!,
            selected: e.selected,
          ),
        )
        .toList();
  }

  @override
  Future<void> setNewServer({required int id, required AddServerRequest request}) =>
      _serverDataSource.setNewServer(id: id, request: request);

  @override
  Future<void> setSelectedServerId({required int id}) => _serverDataSource.setSelectedServerId(id: id);

  @override
  Future<void> removeServer({required int serverId}) => _serverDataSource.removeServer(serverId: serverId);

  @override
  Future<Server?> getServerById({required int id}) async {
    final server = await _serverDataSource.getServerById(id: id);
    final profile = await _routingDataSource.getProfileById(id: server.routingProfileId);

    return Server(
      id: server.id,
      name: server.name,
      ipAddress: server.ipAddress,
      domain: server.domain,
      username: server.username,
      password: server.password,
      vpnProtocol: server.vpnProtocol,
      dnsServers: server.dnsServers,
      routingProfile: profile,
      selected: server.selected,
    );
  }
}
