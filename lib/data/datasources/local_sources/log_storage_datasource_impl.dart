import 'dart:io';

import 'package:trusttunnel/common/logging/app_logger.dart';
import 'package:trusttunnel/data/datasources/log_storage_datasource.dart';

final class LogStorageDataSourceImpl implements LogStorageDataSource {
  final AppLogger _logger;

  const LogStorageDataSourceImpl({
    required AppLogger logger,
  }) : _logger = logger;

  @override
  Future<String> readCombinedLogs() => _logger.appLogAppender.synchronize((snapshot) async {
    final buffer = StringBuffer();
    for (final path in snapshot.orderedLogPaths) {
      final file = File(path);
      final fileExists = await file.exists();
      if (!fileExists) {
        continue;
      }
      final content = await file.readAsString();
      if (content.isEmpty) {
        continue;
      }
      buffer.write(content);
      if (!content.endsWith(Platform.lineTerminator)) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  });

  @override
  Future<void> deleteLogs() => _logger.appLogAppender.synchronize(
    (snapshot) async {
      for (final path in [...snapshot.orderedLogPaths, snapshot.metadataPath]) {
        final file = File(path);
        final fileExists = await file.exists();
        if (fileExists) {
          await file.delete();
        }
      }
    },
    resetAfter: true,
  );
}
