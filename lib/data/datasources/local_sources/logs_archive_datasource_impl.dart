import 'dart:io';
import 'dart:typed_data';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trusttunnel/data/datasources/logs_archive_datasource.dart';
import 'package:trusttunnel/data/model/logs_archive.dart';

final class LogsArchiveDataSourceImpl implements LogsArchiveDataSource {
  static const _archivePrefix = 'trusttunnel_';

  final DateTime Function() _getCurrentDateTime;
  final Duration _staleAge;

  LogsArchiveDataSourceImpl({
    DateTime Function()? getCurrentDateTime,
    Duration staleAge = const Duration(days: 1),
  }) : _getCurrentDateTime = getCurrentDateTime ?? DateTime.now,
       _staleAge = staleAge;

  @override
  Future<LogsArchive> createArchive({
    required String name,
    required Map<String, List<int>> files,
  }) async {
    final archivedBytes = await ArchiveUtil.archive(
      files.map((name, bytes) => MapEntry(name, Uint8List.fromList(bytes))),
    );
    final bytes = Uint8List.fromList(archivedBytes);
    final tempDirectory = await getTemporaryDirectory();
    final file = File(p.join(tempDirectory.path, name));
    await file.writeAsBytes(bytes, flush: true);

    return LogsArchive(file: file, bytes: bytes);
  }

  @override
  Future<void> deleteArchive(File archive) async {
    final archiveExists = await archive.exists();
    if (archiveExists) {
      await archive.delete();
    }
  }

  @override
  Future<void> cleanupStaleArchives() async {
    final tempDirectory = await getTemporaryDirectory();
    await for (final entity in tempDirectory.list()) {
      if (entity is! File) {
        continue;
      }
      final name = p.basename(entity.path);
      if (!name.startsWith(_archivePrefix) || !name.endsWith('.zip')) {
        continue;
      }
      final lastModified = await entity.lastModified();
      if (_getCurrentDateTime().difference(lastModified) < _staleAge) {
        continue;
      }
      await entity.delete();
    }
  }
}
