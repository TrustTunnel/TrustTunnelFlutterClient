import 'package:adguard_logger/adguard_logger.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/sanitizer/log_sanitizer.dart';

class AppLogger extends Logger {
  LogSanitizer sanitizer;

  AppLogger({
    this.sanitizer = const LogSanitizer(),
    LoggingLevel listenableLevel = LoggingLevel.defaultLevel,
    super.extensions,
  }) : super(
         listenableLevel: _toAdguardLevel(listenableLevel),
       );

  static LogLevel _toAdguardLevel(LoggingLevel level) => switch (level) {
    LoggingLevel.defaultLevel => LogLevel.info,
    LoggingLevel.debug => LogLevel.trace,
  };

  @override
  void log(
    String message, {
    required LogLevel level,
    Object? error,
    StackTrace? stackTrace,
    LogDateTime? timeLog,
    LogTrace? trace,
    List<String>? additionalTags,
  }) {
    final sanitizedMessage = sanitizer.sanitize<String>(message) ?? '';
    final sanitizedError = sanitizer.sanitizeError(error);
    final sanitizedStackTrace = sanitizer.sanitizeStackTrace(stackTrace);
    final sanitizedTags = additionalTags?.map((tag) => sanitizer.sanitize<String>(tag)).whereType<String>().toList();

    super.log(
      sanitizedMessage,
      error: sanitizedError,
      stackTrace: sanitizedStackTrace,
      additionalTags: sanitizedTags,
      level: level,
      timeLog: timeLog,
      trace: trace,
    );
  }

  void updateSettings({
    LoggingLevel? loggingLevel,
    LogSanitizer? sanitizer,
  }) {
    if (loggingLevel != null) {
      listenableLevel = _toAdguardLevel(loggingLevel);
    }

    if (sanitizer != null) {
      this.sanitizer = sanitizer;
    }
  }
}
