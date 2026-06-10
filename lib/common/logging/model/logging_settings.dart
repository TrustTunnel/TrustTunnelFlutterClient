import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';

@immutable
final class LoggingSettings {
  final LoggingLevel level;
  final LoggingSecurityType securityType;

  const LoggingSettings({
    required this.level,
    required this.securityType,
  });

  static const defaults = LoggingSettings(
    level: LoggingLevel.defaultLevel,
    securityType: LoggingSecurityType.stripped,
  );

  bool get isDebug => level == LoggingLevel.debug;

  bool get isFullSecurity => securityType == LoggingSecurityType.full;

  LoggingSettings copyWith({
    LoggingLevel? level,
    LoggingSecurityType? securityType,
  }) => LoggingSettings(
    level: level ?? this.level,
    securityType: securityType ?? this.securityType,
  );

  @override
  String toString() => 'LoggingSettings(level: ${level.value}, securityType: ${securityType.value})';

  @override
  int get hashCode => Object.hashAll([
    level,
    securityType,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LoggingSettings && other.level == level && other.securityType == securityType;
}
