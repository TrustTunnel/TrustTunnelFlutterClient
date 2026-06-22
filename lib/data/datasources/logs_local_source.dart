import 'dart:typed_data';

import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

abstract class LogsLocalSource {
  /// Collects raw log lines from the VPN plugin, encodes them grouped by
  /// platform log group name (e.g. "app", "vpn"), appends an `app_state.log`
  /// snapshot, and archives everything into a single ZIP.
  Future<ExportLogsArchive> createArchive();

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
