import 'package:trusttunnel/data/datasources/routing_datasource.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class DeepLinkRepository {
  Future<Server> addDataFromDeepLink({
    required String deepLink,
    required String serverName,
    required String profileName,
  });
}

class DeepLinkRepositoryImpl implements DeepLinkRepository {
  final RoutingDataSource _routingDataSource;
  final ServerDataSource _serverDataSource;

  const DeepLinkRepositoryImpl({
    required RoutingDataSource routingDataSource,
    required ServerDataSource serverDataSource,
  }) : _routingDataSource = routingDataSource,
       _serverDataSource = serverDataSource;

  @override
  Future<Server> addDataFromDeepLink({
    required String deepLink,
    required String serverName,
    required String profileName,
  }) async {
    final routingData = await _routingDataSource.getProfileDataByBase64(
      base64: deepLink,
      name: profileName,
    );

    final profile = await _routingDataSource.addNewProfile(routingData);

    final serverData = await _serverDataSource.getServerByBase64(
      base64: deepLink,
      routingProfileId: profile.id,
      name: serverName,
    );

    final server = await _serverDataSource.addNewServer(request: serverData);

    return server;
  }
}
