import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';

abstract class LoggingSettingsRepository {
  Future<void> setLoggingLevel(LoggingLevel level);

  Future<void> setSecurityType(LoggingSecurityType securityType);

  Future<LoggingLevel> getLoggingLevel();

  Future<LoggingSecurityType> getSecurityType();
}

class LoggingSettingsRepositoryImpl implements LoggingSettingsRepository {
  final LoggingSettingsDataSource _dataSource;

  LoggingSettingsRepositoryImpl({
    required LoggingSettingsDataSource dataSource,
  }) : _dataSource = dataSource;

  @override
  Future<LoggingLevel> getLoggingLevel() => _dataSource.getLoggingLevel();

  @override
  Future<LoggingSecurityType> getSecurityType() => _dataSource.getSecurityType();

  @override
  Future<void> setLoggingLevel(LoggingLevel level) => _dataSource.setLoggingLevel(level);

  @override
  Future<void> setSecurityType(LoggingSecurityType securityType) => _dataSource.setSecurityType(securityType);
}
