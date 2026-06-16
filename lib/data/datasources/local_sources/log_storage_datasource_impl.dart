import 'package:adguard_logger/adguard_logger.dart';
import 'package:path/path.dart' as p;
import 'package:trusttunnel/data/datasources/log_storage_datasource.dart';

final class LogStorageDataSourceImpl implements LogStorageDataSource {
  final LogStorage _logStorage;
  final String _directoryPath;

  LogStorageDataSourceImpl({
    required LogStorage logStorage,
    required String directoryPath,
  }) : _logStorage = logStorage,
       _directoryPath = directoryPath;

  @override
  Future<String> readCombinedLogs() async {
    final buffer = StringBuffer();
    final fileNames = await _logStorage.readFileNames(_directoryPath);

    for (final fileName in fileNames) {
      final fullPath = p.join(_directoryPath, fileName);
      final content = await _logStorage.readLogData(fullPath);
      if (content != null && content.isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(content);
      }
    }

    return buffer.toString();
  }

  @override
  Future<void> deleteLogs() async {
    final fileNames = await _logStorage.readFileNames(_directoryPath);

    for (final fileName in fileNames) {
      final fullPath = p.join(_directoryPath, fileName);
      await _logStorage.deleteData(fullPath);
    }
  }
}
