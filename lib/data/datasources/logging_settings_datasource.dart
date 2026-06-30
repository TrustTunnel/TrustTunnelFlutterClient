import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';

abstract class LoggingSettingsDataSource {
  Future<void> setLoggingLevel(LoggingLevel level);

  Future<void> setSecurityType(LoggingSecurityType securityType);

  Future<LoggingLevel> getLoggingLevel();

  Future<LoggingSecurityType> getSecurityType();
}
