import 'dart:convert';
import 'dart:io';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/data/datasources/app_state_logging_datasource.dart';
import 'package:trusttunnel/data/datasources/logs_local_source.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_file_type.dart';
import 'package:trusttunnel/feature/settings/logs_manager/model/export_logs_archive.dart';
import 'package:vpn_plugin/models/logs/log_platform_files.dart';
import 'package:vpn_plugin/vpn_plugin.dart';

final class LogsLocalSourceImpl implements LogsLocalSource {
  static const _logTempKey = '_logTempKey';

  final FileLogAppender _logAppender;
  final AppStateLoggingDataSource _appStateLoggingDataSource;
  final FilePicker _filePicker;
  final VpnPlugin _vpnPlugin;
  final SharedPreferences _sharedPreferences;

  LogsLocalSourceImpl({
    required FileLogAppender logAppender,
    required AppStateLoggingDataSource appStateLoggingDataSource,
    required FilePicker filePicker,
    required VpnPlugin vpnPlugin,
    required SharedPreferences sharedPreferences,
  }) : _logAppender = logAppender,
       _appStateLoggingDataSource = appStateLoggingDataSource,
       _vpnPlugin = vpnPlugin,
       _sharedPreferences = sharedPreferences,
       _filePicker = filePicker;

  @override
  Future<ExportLogsArchive> createArchive() async {
    final logPaths = await _vpnPlugin.fetchLogsPath();
    final logFiles = <String, Uint8List>{};

    for (final group in LogPlatformFiles.platform(defaultTargetPlatform).value) {
      final regex = RegExp(r'.*' + group + r'(\.\d+)?\.log');
      final selectedPaths = logPaths.where(regex.hasMatch).toList();

      final lines = selectedPaths.isEmpty
          ? <String>[]
          : (await _vpnPlugin.exportLogsFor(selectedPaths)).map((r) => r.toString()).toList();

      logFiles['$group.log'] = utf8.encode(lines.join(Platform.lineTerminator));
    }

    final snapshot = await _appStateLoggingDataSource.collectSnapshot();
    logFiles['app_state.log'] = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
    );

    final archivedData = await _logAppender.archiveData(
      additionalFiles: logFiles,
    );

    return ExportLogsArchive(
      data: archivedData,
      name: _generateArchiveName(),
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
    final file = await File(path).create(recursive: true);
    await file.writeAsBytes(data, mode: FileMode.writeOnly, flush: true);
    final tempLogs = _sharedPreferences.getStringList(_logTempKey);
    await _sharedPreferences.setStringList(_logTempKey, [...?tempLogs, path]);

    return path;
  }

  @override
  Future<void> deleteLogs() => Future.wait([
    clearTempFiles(),
    _logAppender.clearAllLogs(),
    _vpnPlugin.clearLogs(),
  ]);

  @override
  Future<void> clearTempFiles() async {
    final tempFiles = _sharedPreferences.getStringList(_logTempKey)?.map((path) => File(path)) ?? [];

    for (final file in tempFiles) {
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _sharedPreferences.remove(_logTempKey);

    await _filePicker.clearTemporaryFiles();
  }

  String _generateArchiveName() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:\-]'), '').replaceAll(RegExp(r'\..*'), '');

    return 'trusttunnel_${defaultTargetPlatform.name}_logs_$timestamp.zip';
  }
}
