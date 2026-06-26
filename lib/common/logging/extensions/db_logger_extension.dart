import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';

class DBLoggerExtension extends LoggerExtension<DBLoggerExtension> {
  final int slowQueryThresholdMs;

  DBLoggerExtension({
    this.slowQueryThresholdMs = 200,
  });

  /// Runs a database [operation], timing it and logging the result.
  ///
  /// Mutating operations (INSERT, UPDATE, DELETE, etc.) are always logged.
  /// Non-mutating operations (SELECT) are only logged when they exceed
  /// [slowQueryThresholdMs].
  Future<T> runOperation<T>(
    String description,
    Future<T> Function() operation, {
    bool mutating = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await operation();
      stopwatch.stop();

      final elapsed = stopwatch.elapsedMilliseconds;
      if (mutating || elapsed >= slowQueryThresholdMs) {
        logDebug(
          'DB $description completed in $elapsed ms',
          additionalTags: ['database'],
        );
      }

      return result;
    } on Object catch (error, stackTrace) {
      stopwatch.stop();
      logError(
        'DB $description failed after ${stopwatch.elapsedMilliseconds} ms',
        error: error.runtimeType,
        stackTrace: stackTrace,
        additionalTags: const ['database', 'error'],
      );
      rethrow;
    }
  }
}
