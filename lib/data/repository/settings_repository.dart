import 'dart:async';

import 'package:trusttunnel/data/datasources/settings_datasource.dart';

abstract class SettingsRepository {
  Future<void> setExcludedRoutes(List<String> routes);

  Future<List<String>> getExcludedRoutes();

  Future<List<String>> getDefaultExcludedRoutes();
}

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsDataSource _settingsDataSource;

  SettingsRepositoryImpl({
    required this._settingsDataSource,
  });

  @override
  Future<List<String>> getExcludedRoutes() => _settingsDataSource.getExcludedRoutes();

  @override
  Future<List<String>> getDefaultExcludedRoutes() => _settingsDataSource.getDefaultExcludedRoutes();

  @override
  Future<void> setExcludedRoutes(List<String> routes) => _settingsDataSource.setExcludedRoutes(routes);
}
