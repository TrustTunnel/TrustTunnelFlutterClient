
import 'package:vpn_plugin/models/logs/log_level.dart';

class LogRecord {
  final DateTime dateTime;
  final LogLevel level;
  final String message;

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
