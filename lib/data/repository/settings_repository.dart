import 'dart:async';

import 'package:vpn_plugin/platform_api.g.dart';

abstract class SettingsRepository {
  Future<List<VpnRequest>> getAllRequests();

  Future<void> setExcludedRoutes(String routes);

  Future<String> getExcludedRoutes();
}

class SettingsRepositoryImpl implements SettingsRepository {
  final PlatformApi _platformApi;

  SettingsRepositoryImpl({
    required PlatformApi platformApi,
  }) : _platformApi = platformApi;

  @override
  Future<List<VpnRequest>> getAllRequests() async {
    final List<VpnRequest?> requests = await _platformApi.getAllRequests();

    return requests.cast<VpnRequest>();
  }

  @override
  Future<String> getExcludedRoutes() => _platformApi.getExcludedRoutes();

  @override
  Future<void> setExcludedRoutes(String routes) => _platformApi.setExcludedRoutes(routes);
}
