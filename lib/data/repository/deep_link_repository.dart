import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/datasources/server_datasource.dart';
import 'package:trusttunnel/data/model/server_data.dart';

abstract class DeepLinkRepository {
  Future<ServerData> parseDataFromLink({
    required String deepLink,
  });
}

class DeepLinkRepositoryImpl implements DeepLinkRepository {
  final ServerDataSource _serverDataSource;

  const DeepLinkRepositoryImpl({
    required ServerDataSource serverDataSource,
  }) : _serverDataSource = serverDataSource;

  @override
  Future<ServerData> parseDataFromLink({
    required String deepLink,
  }) => _serverDataSource.getServerByBase64(
    base64: deepLink,
    routingProfileId: RoutingProfileUtils.defaultRoutingProfileId,
  );
}
