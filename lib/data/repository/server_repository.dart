import 'dart:async';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/server_data.dart';

abstract class ServerRepository {
  Future<Server> addNewServer({required ServerData request});

  Future<List<Server>> getAllServers();

  Future<Server?> getServerById({required String id});

  Future<Server> getServerByBase64({
    required String base64,
    required String name,
  });

  Future<void> setSelectedServerId({required String id});

  Future<void> setNewServer({required String id, required ServerData request});

  Future<void> removeServer({required String serverId});
}

class ServerRepositoryImpl implements ServerRepository {
  final ServerDataSource _serverDataSource;

  ServerRepositoryImpl({
    required ServerDataSource serverDataSource,
  }) : _serverDataSource = serverDataSource;

  @override
  Future<Server> addNewServer({required ServerData request}) async {
    final server = await _serverDataSource.addNewServer(
      request: request,
    );

    return server;
  }

  @override
  Future<List<Server>> getAllServers() async {
    final servers = await _serverDataSource.getAllServers();

    return servers;
  }

  @override
  Future<void> setNewServer({required String id, required ServerData request}) =>
      _serverDataSource.setNewServer(id: id, request: request);

  @override
  Future<void> setSelectedServerId({required String id}) => _serverDataSource.setSelectedServerId(id: id);

  @override
  Future<void> removeServer({required String serverId}) => _serverDataSource.removeServer(serverId: serverId);

  @override
  Future<Server?> getServerById({required String id}) => _serverDataSource.getServerById(id: id);

  @override
  Future<Server> getServerByBase64({required String base64, required String name}) async {
    await _serverDataSource.getServerByBase64(base64: base64, name: name);
    throw UnimplementedError();
  }
}
