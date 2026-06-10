import 'dart:io';

import 'package:trusttunnel/data/model/logs_archive.dart';

abstract interface class LogsArchiveDataSource {
  Future<LogsArchive> createArchive({
    required String name,
    required Map<String, List<int>> files,
  });

  Future<void> deleteArchive(File archive);

  Future<void> cleanupStaleArchives();
}
