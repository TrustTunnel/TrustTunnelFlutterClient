import 'dart:io';

import 'package:flutter/foundation.dart';

@immutable
final class LogsArchive {
  final File file;
  final Uint8List bytes;

  const LogsArchive({
    required this.file,
    required this.bytes,
  });

  @override
  String toString() => 'LogsArchive(file: $file, bytes: ${bytes.length} bytes)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is LogsArchive && other.file == file && other.bytes == bytes;
  }

  @override
  int get hashCode => Object.hashAll([
    file.hashCode,
    bytes.hashCode,
  ]);
}
