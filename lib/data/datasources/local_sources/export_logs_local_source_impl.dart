import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/export_logs_local_source.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';

final class ExportLogsLocalSourceImpl implements ExportLogsLocalSource {
  final FileLogAppender _logAppender;
  final AppStateLoggingDataSource _appStateLoggingDataSource;
  final FilePicker _filePicker;

  ExportLogsLocalSourceImpl({
    required FileLogAppender logAppender,
    required AppStateLoggingDataSource appStateLoggingDataSource,
    required FilePicker filePicker,
  }) : _logAppender = logAppender,
       _appStateLoggingDataSource = appStateLoggingDataSource,
       _filePicker = filePicker;

  @override
  Future<ExportLogsArchive> archiveData() async {
    final snapshot = await _appStateLoggingDataSource.collectSnapshot();
    final formattedState = const JsonEncoder.withIndent('  ').convert(snapshot.toJson());

    final archivedData = await _logAppender.archiveData(
      lastModifiedDuration: const Duration(days: 1),
      additionalFiles: {
        'app_state.txt': utf8.encode(formattedState),
      },
    );

    final archiveName = _generateArchiveName();

    return ExportLogsArchive(
      data: archivedData,
      name: archiveName,
    );
  }

  @override
  Future<String?> pickFilePath({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    ExportFileType type = ExportFileType.any,
    List<String>? allowedExtensions,
    Uint8List? data,
  }) async {
    final isMobile = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };

    return _filePicker.saveFile(
      fileName: fileName,
      bytes: isMobile ? data : null,
    );
  }

  @override
  Future<String> saveRawFile({
    required Uint8List data,
    required String path,
  }) async {
    await File(path).writeAsBytes(data, flush: true);

    return path;
  }

  String _generateArchiveName() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').replaceAll(RegExp(r'\..*'), '');

    return 'trusttunnel_${defaultTargetPlatform.name}_logs_$timestamp.zip';
  }
}
