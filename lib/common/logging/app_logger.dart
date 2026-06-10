import 'dart:io';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/file_appender/app_log_file_appender.dart';
import 'package:trusttunnel/common/logging/model/logging_settings.dart';
import 'package:trusttunnel/common/logging/sanitizer/log_sanitizer.dart';

class AppLogger extends Logger {
  final LogSanitizer _sanitizer;

  LoggingSettings _settings;
  Future<void>? _initialization;
  bool _initialized = false;
  late final AppLogFileAppender _appLogAppender;

  AppLogger({
    LoggingSettings settings = LoggingSettings.defaults,
    LogSanitizer sanitizer = const LogSanitizer(),
    super.extensions,
  }) : _settings = settings,
       _sanitizer = sanitizer,
       super(listenableLevel: _toAdguardLevel(settings.level));

  LoggingSettings get settings => _settings;

  AppLogFileAppender get appLogAppender {
    _ensureInitialized();

    return _appLogAppender;
  }

  String get appLogBaseName => 'app';

  bool get isDebugLoggingEnabled => _settings.isDebug;

  Future<void> initialize() => _initialization ??= _initialize();

  void updateSettings(LoggingSettings settings) {
    _settings = settings;
    listenableLevel = _toAdguardLevel(settings.level);
  }

  Object? sanitizePayload(Object? payload) => _sanitizer.sanitizePayload(payload, _settings.securityType);

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
    final sanitizedMessage = _sanitizer.sanitizeText(message, _settings.securityType);
    final sanitizedError = _sanitizer.sanitizeError(error, _settings.securityType);
    final sanitizedStackTrace = _sanitizer.sanitizeStackTrace(stackTrace, _settings.securityType);
    final sanitizedTags = _sanitizer.sanitizeTags(additionalTags, _settings.securityType);
    final resolvedTime = timeLog ?? LogDateTime(dateTime: DateTime.now());
    final resolvedTrace = trace ?? LogTrace.current();

    if (_initialized && level.compareTo(listenableLevel) >= 0) {
      _appLogAppender.add(
        LogRecord(
          message: sanitizedMessage,
          level: level,
          error: sanitizedError,
          stackTrace: sanitizedStackTrace,
          timeLog: resolvedTime,
          trace: resolvedTrace,
          additionalTags: sanitizedTags,
        ),
      );
    }

    super.log(
      sanitizedMessage,
      level: level,
      error: sanitizedError,
      stackTrace: sanitizedStackTrace,
      timeLog: resolvedTime,
      trace: resolvedTrace,
      additionalTags: sanitizedTags,
    );
  }

  Future<void> _initialize() async {
    final consoleAppender = ConsoleLogAppender();
    consoleAppender.attachToLogger(this);

    final logDirectory = await _getLogsDirectory();
    final appLogAppender = AppLogFileAppender(
      directoryPath: logDirectory.path,
      baseName: appLogBaseName,
    );
    _appLogAppender = appLogAppender;
    _initialized = true;
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError('AppLogger is not initialized.');
    }
  }

  static Future<Directory> _getLogsDirectory() async {
    // TODO: for future Windows support, we should use the APPDATA environment variable to get the logs directory.
    // Kondrashov Stepan <s.kondraschov@adguard.com>, 05 June 2026
    final applicationSupportDirectory = await getApplicationSupportDirectory();
    final rootDirectory = Directory(
      p.join(applicationSupportDirectory.path, 'Logs'),
    );

    final rootDirectoryExists = await rootDirectory.exists();
    if (!rootDirectoryExists) {
      await rootDirectory.create(recursive: true);
    }

    return rootDirectory;
  }

  static LogLevel _toAdguardLevel(LoggingLevel level) => switch (level) {
    LoggingLevel.defaultLevel => LogLevel.info,
    LoggingLevel.debug => LogLevel.trace,
  };
}
