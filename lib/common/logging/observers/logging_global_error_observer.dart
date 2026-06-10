import 'package:trusttunnel/common/logging/app_logger.dart';

abstract interface class GlobalErrorObserver {
  void onUncaughtError(Object error, StackTrace? stackTrace);
}

class LoggingGlobalErrorObserver implements GlobalErrorObserver {
  final AppLogger _logger;

  const LoggingGlobalErrorObserver({
    required AppLogger logger,
  }) : _logger = logger;

  @override
  void onUncaughtError(Object error, StackTrace? stackTrace) => _logger.logError(
    'Global error captured',
    error: error,
    stackTrace: stackTrace,
    additionalTags: ['global error'],
  );
}
