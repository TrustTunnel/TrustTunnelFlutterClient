import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';

class LoggingSettingsDataSourceImpl implements LoggingSettingsDataSource {
  static const _loggingLevelKey = 'logging_level';

  static const _securityTypeKey = 'security_type';

  final SharedPreferences _preferences;

  LoggingSettingsDataSourceImpl({required SharedPreferences preferences}) : _preferences = preferences;

  @override
  Future<LoggingLevel> getLoggingLevel() async {
    final rawLevel = _preferences.getString(_loggingLevelKey);

    return LoggingLevel.values.firstWhere(
      (level) => level.value == rawLevel,
      orElse: () => LoggingLevel.defaultLevel,
    );
  }

  @override
  Future<LoggingSecurityType> getSecurityType() async {
    final rawType = _preferences.getString(_securityTypeKey);

    return LoggingSecurityType.values.firstWhere(
      (type) => type.value == rawType,
      orElse: () => LoggingSecurityType.stripped,
    );
  }

  @override
  Future<void> setLoggingLevel(LoggingLevel level) => _preferences.setString(_loggingLevelKey, level.value);

  @override
  Future<void> setSecurityType(LoggingSecurityType securityType) =>
      _preferences.setString(_securityTypeKey, securityType.value);
}
