import 'dart:typed_data';

import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

abstract class LogsLocalSource {
  Future<ExportLogsArchive> archiveData();

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

  Future<void> deleteLogs();
}
