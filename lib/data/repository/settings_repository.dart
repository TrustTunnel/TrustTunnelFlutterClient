import 'dart:async';

import 'package:trusttunnel/data/datasources/settings_datasource.dart';

abstract class SettingsRepository {
  Future<void> setExcludedRoutes(List<String> routes);

  Future<List<String>> getExcludedRoutes();
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
}
