import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/datasources/logs_export_destination_datasource.dart';
import 'package:trusttunnel/data/model/logs_archive.dart';

final class LogsExportDestinationDataSourceImpl implements LogsExportDestinationDataSource {
  final FilePicker _filePicker;

  const LogsExportDestinationDataSourceImpl({
    required FilePicker filePicker,
  }) : _filePicker = filePicker;

  @override
  Future<void> saveArchive(LogsArchive archive) async {
    final isMobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };

    final outputPath = await _filePicker.saveFile(
      fileName: archive.name,
      bytes: isMobile ? archive.bytes : null,
    );
    if (outputPath == null) {
      throw const LogsExportDestinationCancelledException();
    }

    if (!isMobile) {
      await File(outputPath).writeAsBytes(archive.bytes, flush: true);
    }
  }
}
