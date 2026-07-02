import 'package:trusttunnel/data/datasources/auto_connect_on_launch_settings_datasource.dart';

abstract class AutoConnectOnLaunchSettingsRepository {
  Future<bool> isEnabled();

  Future<void> enable();

  Future<void> disable();

  Future<String?> getLastServerId();

  Future<void> setLastServerId(String? serverId);
}

class AutoConnectOnLaunchSettingsRepositoryImpl implements AutoConnectOnLaunchSettingsRepository {
  final AutoConnectOnLaunchSettingsDataSource _dataSource;

  AutoConnectOnLaunchSettingsRepositoryImpl({
    required AutoConnectOnLaunchSettingsDataSource dataSource,
  }) : _dataSource = dataSource;

  @override
  Future<String?> getLastServerId() => _dataSource.getLastServerId();

  @override
  Future<bool> isEnabled() => _dataSource.isEnabled();

  @override
  Future<void> enable() => _dataSource.enable();

  @override
  Future<void> disable() => _dataSource.disable();

  @override
  Future<void> setLastServerId(String? serverId) => _dataSource.setLastServerId(serverId);
}
