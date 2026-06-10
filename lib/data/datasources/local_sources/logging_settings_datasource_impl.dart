import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';

class LoggingSettingsDataSourceImpl implements LoggingSettingsDataSource {
  static const _levelKey = 'logging.level';
  static const _securityTypeKey = 'logging.security_type';

  final db.AppDatabase _database;

  const LoggingSettingsDataSourceImpl({
    required db.AppDatabase database,
  }) : _database = database;

  @override
  Future<LoggingSettings> getSettings() async {
    final rows = await _database.select(_database.appSettings).get();
    final values = <String, String>{};
    for (final row in rows) {
      values[row.settingKey] = row.value;
    }

    return LoggingSettings(
      level: LoggingLevel.parse(values[_levelKey]),
      securityType: LoggingSecurityType.parse(values[_securityTypeKey]),
    );
  }

  @override
  Future<void> setSettings(LoggingSettings settings) => _database.batch(
    (batch) => batch.insertAllOnConflictUpdate(
      _database.appSettings,
      [
        db.AppSettingsCompanion.insert(
          settingKey: _levelKey,
          value: settings.level.value,
        ),
        db.AppSettingsCompanion.insert(
          settingKey: _securityTypeKey,
          value: settings.securityType.value,
        ),
      ],
    ),
  );
}
