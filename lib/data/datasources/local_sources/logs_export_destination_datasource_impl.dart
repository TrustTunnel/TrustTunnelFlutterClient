import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:trusttunnel/data/datasources/logs_export_destination_datasource.dart';
import 'package:trusttunnel/data/model/logs_archive.dart';

final class LogsExportDestinationDataSourceImpl implements LogsExportDestinationDataSource {
  final FilePicker _filePicker;

  const LogsExportDestinationDataSourceImpl({
    required FilePicker filePicker,
  }) : _filePicker = filePicker;

  @override
  Future<void> saveArchive(LogsArchive archive) async {
    final outputPath = await _filePicker.saveFile(
      fileName: p.basename(archive.file.path),
      bytes: !kIsWeb && (Platform.isAndroid || Platform.isIOS) ? archive.bytes : null,
    );
    if (outputPath == null) {
      throw const LogsExportDestinationCancelledException();
    }
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
      await File(outputPath).writeAsBytes(archive.bytes, flush: true);
    }
  }
}
