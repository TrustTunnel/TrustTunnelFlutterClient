import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trusttunnel/common/logging/file_appender/app_log_file_names_builder.dart';
import 'package:trusttunnel/common/logging/model/app_log_metadata.dart';
import 'package:trusttunnel/common/logging/model/app_log_storage_snapshot.dart';

typedef AppLogFormattedLogLine = ({int byteLength, String line});

/// Reads, writes and reconciles log files with their metadata index.
final class AppLogFileStorage {
  final String _directoryPath;
  final String _metadataFileName;
  final int _rotationSizeLimit;
  final int _rotationFileLimit;
  final Duration _containmentDuration;
  final DateTime Function() _getCurrentDateTime;
  final AppLogFileNamesBuilder _logFileNamesBuilder;

  List<AppLogMetadata> _metadata = [];
  String? _currentPath;
  bool _initialized = false;

  AppLogFileStorage({
    required String directoryPath,
    required String metadataFileName,
    required String baseName,
    required int rotationSizeLimit,
    required int rotationFileLimit,
    required Duration containmentDuration,
    required DateTime Function() getCurrentDateTime,
  }) : _directoryPath = directoryPath,
       _metadataFileName = metadataFileName,
       _rotationSizeLimit = rotationSizeLimit,
       _rotationFileLimit = rotationFileLimit,
       _containmentDuration = containmentDuration,
       _getCurrentDateTime = getCurrentDateTime,
       _logFileNamesBuilder = AppLogFileNamesBuilder(baseName: baseName);

  String get metadataPath => p.join(_directoryPath, _metadataFileName);

  bool isLogFile({
    required String name,
    required String baseName,
  }) => name.startsWith('${baseName}_') && name.endsWith('.log');

  /// Loads metadata and makes it match real log files.
  Future<void> ensureReady() async {
    if (_initialized) {
      return;
    }

    final directory = Directory(_directoryPath);
    final directoryExists = await directory.exists();
    if (!directoryExists) {
      await directory.create(recursive: true);
    }

    _metadata = await _readMetadata();
    await _reconcileMetadataWithFiles();
    await _cleanUpRotatedFiles();
    _currentPath = _metadata.isEmpty ? null : p.join(_directoryPath, _metadata.last.id);
    await _writeMetadata();
    _initialized = true;
  }

  /// Appends formatted lines and updates rotation metadata.
  Future<void> append(List<AppLogFormattedLogLine> lines) async {
    if (lines.isEmpty) {
      return;
    }

    await ensureReady();

    final writes = <String, StringBuffer>{};
    for (final (:line, :byteLength) in lines) {
      _rotateIfNeeded(byteLength);
      writes.putIfAbsent(_currentPath!, StringBuffer.new).write(line);
      _increaseCurrentFileLength(byteLength);
    }

    try {
      for (final MapEntry(:key, :value) in writes.entries) {
        await File(key).writeAsString(
          value.toString(),
          mode: FileMode.writeOnlyAppend,
          flush: true,
        );
      }
      await _cleanUpRotatedFiles();
      await _writeMetadata();
    } on Object {
      markStale();
      rethrow;
    }
  }

  AppLogStorageSnapshot snapshot() => AppLogStorageSnapshot(
    orderedLogPaths: List.unmodifiable(_metadata.map((item) => p.join(_directoryPath, item.id))),
    metadataPath: metadataPath,
  );

  void markStale() {
    _initialized = false;
  }

  void reset() {
    _metadata = [];
    _currentPath = null;
    _initialized = false;
  }

  Future<List<AppLogMetadata>> _readMetadata() async {
    final file = File(metadataPath);
    final fileExists = await file.exists();
    if (!fileExists) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final raw = jsonDecode(content) as List<Object?>;

      return raw.whereType<Map<String, Object?>>().map(AppLogMetadata.fromJson).toList()
        ..sort(_logFileNamesBuilder.compare);
    } on Object {
      return [];
    }
  }

  Future<void> _reconcileMetadataWithFiles() async {
    final directory = Directory(_directoryPath);
    final files = await directory
        .list()
        .where(
          (entity) =>
              entity is File && isLogFile(name: p.basename(entity.path), baseName: _logFileNamesBuilder.baseName),
        )
        .cast<File>()
        .toList();
    final metadataById = <String, AppLogMetadata>{};
    for (final item in _metadata) {
      metadataById[item.id] = item;
    }

    _metadata =
        await Future.wait(
            files.map((file) async {
              final id = p.basename(file.path);
              final stat = await file.stat();

              return AppLogMetadata(
                id: id,
                createdAt: metadataById[id]?.createdAt ?? stat.modified,
                lengthInBytes: stat.size,
              );
            }),
          )
          ..sort(_logFileNamesBuilder.compare);
  }

  void _rotateIfNeeded(int incomingBytes) {
    if (!_mustRotate(incomingBytes)) {
      return;
    }

    _currentPath = _nextLogPath();
    _metadata.add(
      AppLogMetadata(
        id: p.basename(_currentPath!),
        createdAt: _getCurrentDateTime(),
        lengthInBytes: 0,
      ),
    );
  }

  bool _mustRotate(int incomingBytes) {
    if (_currentPath == null || _metadata.isEmpty) {
      return true;
    }

    final current = _metadata.last;

    final isRotationFileLimitExceeded = current.lengthInBytes + incomingBytes >= _rotationFileLimit;
    final isSameUtcDay = _isSameUtcDay(current.createdAt, _getCurrentDateTime());

    return isRotationFileLimitExceeded || !isSameUtcDay;
  }

  String _nextLogPath() {
    final id = _logFileNamesBuilder.nextId(
      currentDateTime: _getCurrentDateTime(),
      existingIds: _metadata.map((item) => item.id),
    );

    return p.join(_directoryPath, id);
  }

  void _increaseCurrentFileLength(int byteLength) {
    final currentId = p.basename(_currentPath!);
    final currentIndex = _metadata.indexWhere((item) => item.id == currentId);
    _metadata[currentIndex] = _metadata[currentIndex].copyWith(
      lengthInBytes: _metadata[currentIndex].lengthInBytes + byteLength,
    );
  }

  Future<void> _cleanUpRotatedFiles() async {
    final oldestAllowed = _getCurrentDateTime().subtract(_containmentDuration);
    final expired = _metadata.where((item) => item.createdAt.isBefore(oldestAllowed)).toList();
    for (final item in expired) {
      await _deleteLog(item);
    }

    var totalSize = _metadata.fold<int>(0, (sum, item) => sum + item.lengthInBytes);
    while (_metadata.length > 1 && totalSize > _rotationSizeLimit) {
      final oldest = _metadata.first;
      totalSize -= oldest.lengthInBytes;
      await _deleteLog(oldest);
    }
  }

  Future<void> _deleteLog(AppLogMetadata metadata) async {
    final file = File(p.join(_directoryPath, metadata.id));
    final fileExists = await file.exists();
    if (fileExists) {
      await file.delete();
    }
    _metadata.remove(metadata);
    if (_currentPath != null && p.basename(_currentPath!) == metadata.id) {
      _currentPath = null;
    }
  }

  Future<void> _writeMetadata() => File(metadataPath).writeAsString(
    jsonEncode(_metadata.map((item) => item.toJson()).toList()),
    flush: true,
  );

  static bool _isSameUtcDay(DateTime first, DateTime second) {
    final a = first.toUtc();
    final b = second.toUtc();

    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
