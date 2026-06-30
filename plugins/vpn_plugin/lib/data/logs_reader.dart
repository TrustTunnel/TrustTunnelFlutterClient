import 'dart:io';

import 'package:async/async.dart';
import 'package:vpn_plugin/domain/log_decoder.dart';
import 'package:vpn_plugin/models/logs/log_record.dart';

class LogsReader {
  final Map<String, AsyncCache<List<LogRecord>>> _cache = {};

  Future<List<LogRecord>> readLogs(String path) => (_cache[path] ??= AsyncCache.ephemeral()).fetch(
    () => _readLogsFromFile(path),
  );

  Future<List<LogRecord>> _readLogsFromFile(String path) =>
      File(path)
          .openRead()
          .transform(LogDecoder.stringSplitter)
          .map(LogDecoder.parseLine) 
          .toList();
}
