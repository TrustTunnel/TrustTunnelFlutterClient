import 'package:trusttunnel/data/model/logs_archive.dart';

final class LogsExportDestinationCancelledException implements Exception {
  const LogsExportDestinationCancelledException();
}

abstract interface class LogsExportDestinationDataSource {
  Future<void> saveArchive(LogsArchive archive);
}
