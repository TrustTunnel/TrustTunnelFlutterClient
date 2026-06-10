import 'package:trusttunnel/common/logging/model/logging_settings.dart';

abstract class LoggingSettingsDataSource {
  Future<LoggingSettings> getSettings();

  Future<void> setSettings(LoggingSettings settings);
}
