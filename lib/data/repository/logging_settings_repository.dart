import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';

abstract class LoggingSettingsRepository {
  Future<LoggingSettings> getSettings();

  Future<void> setSettings(LoggingSettings settings);
}

class LoggingSettingsRepositoryImpl implements LoggingSettingsRepository {
  final LoggingSettingsDataSource _dataSource;

  LoggingSettingsRepositoryImpl({
    required LoggingSettingsDataSource dataSource,
  }) : _dataSource = dataSource;

  @override
  Future<LoggingSettings> getSettings() => _dataSource.getSettings();

  @override
  Future<void> setSettings(LoggingSettings settings) => _dataSource.setSettings(settings);
}
