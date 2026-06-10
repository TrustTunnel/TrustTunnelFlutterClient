import 'dart:convert';
import 'dart:io';

import 'package:trusttunnel/common/logging/app_logger.dart';
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/log_storage_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_archive_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_export_destination_datasource.dart';
import 'package:trusttunnel/data/model/logs_archive.dart';

abstract interface class ExportLogsRepository {
  Future<File> exportLogs();

  Future<void> deleteLogs();

  Future<void> deleteTemporaryArchive(File archive);
}

final class ExportLogsCancelledException implements Exception {
  const ExportLogsCancelledException();
}

final class ExportLogsFailedException implements Exception {
  final Object originalError;

  const ExportLogsFailedException(this.originalError);
}

final class DeleteLogsFailedException implements Exception {
  final Object originalError;

  const DeleteLogsFailedException(this.originalError);
}

final class ExportLogsRepositoryImpl implements ExportLogsRepository {
  final AppLogger _logger;
  final AppStateLoggingDataSource _appStateLoggingDataSource;
  final LogStorageDataSource _logStorageDataSource;
  final LogsArchiveDataSource _archiveDataSource;
  final LogsExportDestinationDataSource _destinationDataSource;
  final DateTime Function() _getCurrentDateTime;

  ExportLogsRepositoryImpl({
    required AppLogger logger,
    required AppStateLoggingDataSource appStateLoggingDataSource,
    required LogStorageDataSource logStorageDataSource,
    required LogsArchiveDataSource archiveDataSource,
    required LogsExportDestinationDataSource destinationDataSource,
    DateTime Function()? getCurrentDateTime,
  }) : _logger = logger,
       _appStateLoggingDataSource = appStateLoggingDataSource,
       _logStorageDataSource = logStorageDataSource,
       _archiveDataSource = archiveDataSource,
       _destinationDataSource = destinationDataSource,
       _getCurrentDateTime = getCurrentDateTime ?? DateTime.now;

  @override
  Future<File> exportLogs() async {
    LogsArchive? archive;

    try {
      await _archiveDataSource.cleanupStaleArchives();

      final snapshot = await _appStateLoggingDataSource.collectSnapshot();
      final sanitizedSnapshot = _logger.sanitizePayload(snapshot.toJson())! as Map<String, Object?>;

      final appLog = await _logStorageDataSource.readCombinedLogs();

      archive = await _archiveDataSource.createArchive(
        name: _archiveName(),
        files: {
          'app.log': utf8.encode(appLog),
          'app_state.txt': utf8.encode(const JsonEncoder.withIndent('  ').convert(sanitizedSnapshot)),
        },
      );
      await _destinationDataSource.saveArchive(archive);

      return archive.file;
    } on LogsExportDestinationCancelledException {
      if (archive != null) {
        await _archiveDataSource.deleteArchive(archive.file);
      }
      throw const ExportLogsCancelledException();
    } on Object catch (error) {
      if (archive != null) {
        await _archiveDataSource.deleteArchive(archive.file);
      }
      throw ExportLogsFailedException(error);
    }
  }

  @override
  Future<void> deleteLogs() async {
    try {
      await _logStorageDataSource.deleteLogs();
    } on Object catch (error) {
      throw DeleteLogsFailedException(error);
    }
  }

  @override
  Future<void> deleteTemporaryArchive(File archive) => _archiveDataSource.deleteArchive(archive);

  String _archiveName() {
    final currentDateTime = _getCurrentDateTime();

    return 'trusttunnel_${Platform.operatingSystem}_logs_'
        '${currentDateTime.year}${_formatDateTime(currentDateTime.month)}${_formatDateTime(currentDateTime.day)}'
        'T${_formatDateTime(currentDateTime.hour)}${_formatDateTime(currentDateTime.minute)}${_formatDateTime(currentDateTime.second)}'
        '${currentDateTime.millisecond.toString().padLeft(3, '0')}.zip';
  }

  String _formatDateTime(int value) => value.toString().padLeft(2, '0');
}
