import 'dart:typed_data';

import 'package:trusttunnel/data/datasources/logs_local_source.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

abstract interface class ExportLogsRepository {
  Future<ExportLogsArchive> createArchive();

  Future<void> deleteLogs();

  Future<String?> pickFilePath({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    ExportFileType type = ExportFileType.any,
    List<String>? allowedExtensions,
    Uint8List? data,
  });

  Future<String> saveRawFile({
    required Uint8List data,
    required String path,
  });

  Future<void> clearTempFiles();
}

final class ExportLogsRepositoryImpl implements ExportLogsRepository {
  final LogsLocalSource _localSource;

  ExportLogsRepositoryImpl({
    required LogsLocalSource localSource,
  }) : _localSource = localSource;

  @override
  Future<ExportLogsArchive> createArchive() => _localSource.createArchive();

  @override
  Future<void> deleteLogs() => _localSource.deleteLogs();

  @override
  Future<String?> pickFilePath({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    ExportFileType type = ExportFileType.any,
    List<String>? allowedExtensions,
    Uint8List? data,
  }) => _localSource.pickFilePath(
    dialogTitle: dialogTitle,
    fileName: fileName,
    initialDirectory: initialDirectory,
    type: type,
    allowedExtensions: allowedExtensions,
    data: data,
  );

  @override
  Future<String> saveRawFile({
    required Uint8List data,
    required String path,
  }) => _localSource.saveRawFile(data: data, path: path);

  @override
  Future<void> clearTempFiles() => _localSource.clearTempFiles();
}
