import 'package:flutter/foundation.dart';

@immutable
final class AppLogStorageSnapshot {
  final List<String> orderedLogPaths;
  final String metadataPath;

  const AppLogStorageSnapshot({
    required this.orderedLogPaths,
    required this.metadataPath,
  });
}
