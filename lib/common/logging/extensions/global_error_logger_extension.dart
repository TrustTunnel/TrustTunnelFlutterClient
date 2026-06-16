import 'package:adguard_logger/adguard_logger.dart';

class GlobalErrorLoggerExtension extends LoggerExtension<GlobalErrorLoggerExtension> {
  void onUncaughtError(Object error, StackTrace? stackTrace) => logError(
    'Global error captured',
    error: error,
    stackTrace: stackTrace,
    additionalTags: ['global error'],
  );
}
