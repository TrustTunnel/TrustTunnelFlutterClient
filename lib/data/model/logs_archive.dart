import 'package:flutter/foundation.dart';

@immutable
final class LogsArchive {
  final String name;
  final Uint8List bytes;

  const LogsArchive({
    required this.name,
    required this.bytes,
  });

  @override
  String toString() => 'LogsArchive(name: $name, bytes: ${bytes.length} bytes)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is LogsArchive && other.name == name && other.bytes == bytes;
  }

  @override
  int get hashCode => Object.hashAll([
    name.hashCode,
    bytes.hashCode,
  ]);
}
