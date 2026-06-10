import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:trusttunnel/common/logging/file_appender/app_log_file_storage.dart';
import 'package:trusttunnel/common/logging/model/app_log_storage_snapshot.dart';

/// Buffers app logs and writes them into rotated log files.
final class AppLogFileAppender extends BaseLogAppender {
  static const _metadataFileName = '.metadata';

  final String directoryPath;
  final String baseName;
  final int rotationSizeLimit;
  final int rotationFileLimit;
  final Duration containmentDuration;
  final Duration bufferFlushDelay;
  final LoggerBaseFormatter formatter;
  final AppLogFileStorage _storage;

  Future<void> _tail = Future<void>.value();
  final List<LogRecord> _buffer = [];
  Timer? _flushTimer;
  Object? _pendingWriteError;
  StackTrace? _pendingWriteStackTrace;

  AppLogFileAppender({
    required this.directoryPath,
    required this.baseName,
    this.rotationSizeLimit = 1024 * 1024 * 30,
    this.rotationFileLimit = 1024 * 1024 * 3,
    this.containmentDuration = const Duration(days: 7),
    this.bufferFlushDelay = const Duration(milliseconds: 250),
    this.formatter = const DataLoggerFormatter(),
    DateTime Function()? getCurrentDateTime,
  }) : _storage = AppLogFileStorage(
         directoryPath: directoryPath,
         metadataFileName: _metadataFileName,
         baseName: baseName,
         rotationSizeLimit: rotationSizeLimit,
         rotationFileLimit: rotationFileLimit,
         containmentDuration: containmentDuration,
         getCurrentDateTime: getCurrentDateTime ?? DateTime.now,
       );

  String get metadataPath => _storage.metadataPath;

  void add(LogRecord record) => handle(record).ignore();

  @override
  Future<void> handle(LogRecord record) => _enqueue(() => _bufferRecord(record));

  /// Flushes logs, exposes files to [action], and optionally forgets storage state.
  Future<T> synchronize<T>(
    Future<T> Function(AppLogStorageSnapshot snapshot) action, {
    bool resetAfter = false,
  }) => _enqueue(() async {
    _throwPendingWriteError();
    await _flushBuffer();
    await _storage.ensureReady();

    try {
      final result = await action(_storage.snapshot());

      return result;
    } finally {
      if (resetAfter) {
        _reset();
      }
    }
  });

  /// Runs file operations one by one.
  Future<T> _enqueue<T>(FutureOr<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  /// Adds a record to the timed flush buffer.
  void _bufferRecord(LogRecord record) {
    _buffer.add(record);
    _flushTimer?.cancel();
    _flushTimer = Timer(bufferFlushDelay, _enqueueBackgroundFlush);
  }

  /// Writes buffered records to disk now.
  Future<void> _flushBuffer() async {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_buffer.isEmpty) {
      return;
    }

    try {
      await _storage.ensureReady();

      final records = List<LogRecord>.of(_buffer);
      _buffer.clear();
      await _storage.append(_formatLines(formatter, records));
    } on Object {
      _storage.markStale();
      rethrow;
    }
  }

  void _enqueueBackgroundFlush() {
    _enqueue(() async {
      try {
        await _flushBuffer();
      } on Object catch (error, stackTrace) {
        _pendingWriteError ??= error;
        _pendingWriteStackTrace ??= stackTrace;
      }
    }).ignore();
  }

  List<AppLogFormattedLogLine> _formatLines(
    LoggerBaseFormatter formatter,
    List<LogRecord> records,
  ) {
    final lines = <AppLogFormattedLogLine>[];
    for (final record in records) {
      final line = '${formatter.format(record)}${Platform.lineTerminator}';
      lines.add((line: line, byteLength: utf8.encode(line).length));
    }
    return lines;
  }

  void _reset() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _storage.reset();
  }

  void _throwPendingWriteError() {
    final pendingWriteError = _pendingWriteError;
    if (pendingWriteError == null) {
      return;
    }

    final pendingWriteStackTrace = _pendingWriteStackTrace ?? StackTrace.current;
    _pendingWriteError = null;
    _pendingWriteStackTrace = null;

    Error.throwWithStackTrace(pendingWriteError, pendingWriteStackTrace);
  }
}
