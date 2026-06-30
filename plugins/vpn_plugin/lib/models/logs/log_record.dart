import 'package:vpn_plugin/models/logs/log_level.dart';

/// {@template log_record}
/// A single log entry produced by the VPN plugin.
///
/// Each record carries a [dateTime] stamp, a severity [level], and a
/// free-form [message] string.
/// {@endtemplate}
class LogRecord {
  /// The timestamp when this log entry was created.
  final DateTime dateTime;

  /// The severity level of this log entry.
  final LogLevel level;

  /// The log message body.
  final String message;

  /// Creates a [LogRecord] with the given [dateTime], [level], and [message].
  LogRecord({
    required this.dateTime,
    required this.level,
    required this.message,
  });

  @override
  int get hashCode => Object.hash(
    dateTime,
    level,
    message,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogRecord &&
          runtimeType == other.runtimeType &&
          dateTime == other.dateTime &&
          message == other.message &&
          level == other.level;

  @override
  String toString() => '[${dateTime.toIso8601String()}] [${level.name.toLowerCase()}] $message';
}
