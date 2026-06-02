import 'dart:async';

import 'package:trusttunnel/data/datasources/settings_datasource.dart';

abstract class SettingsRepository {
  Future<void> setExcludedRoutes(List<String> routes);

  Future<List<String>> getExcludedRoutes();

  Future<void> setPerAppProxy(bool enabled);
  Future<bool> getPerAppProxy();

  Future<void> setBypassApps(bool bypass);
  Future<bool> getBypassApps();

  Future<void> setProxyApps(List<String> apps);
  Future<List<String>> getProxyApps();
}

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsDataSource _settingsDataSource;

  SettingsRepositoryImpl({
    required SettingsDataSource settingsDataSource,
  }) : _settingsDataSource = settingsDataSource;

  @override
  Future<List<String>> getExcludedRoutes() => _settingsDataSource.getExcludedRoutes();

  @override
  Future<void> setExcludedRoutes(List<String> routes) => _settingsDataSource.setExcludedRoutes(routes);

  @override
  Future<void> setPerAppProxy(bool enabled) => _settingsDataSource.setPerAppProxy(enabled);

  @override
  Future<bool> getPerAppProxy() => _settingsDataSource.getPerAppProxy();

  @override
  Future<void> setBypassApps(bool bypass) => _settingsDataSource.setBypassApps(bypass);

  @override
  Future<bool> getBypassApps() => _settingsDataSource.getBypassApps();

  @override
  Future<void> setProxyApps(List<String> apps) => _settingsDataSource.setProxyApps(apps);

  @override
  Future<List<String>> getProxyApps() => _settingsDataSource.getProxyApps();
}
