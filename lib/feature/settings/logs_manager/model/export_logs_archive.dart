import 'dart:typed_data';

final class ExportLogsArchive {
  final Uint8List data;
  final String name;

  const ExportLogsArchive({
    required this.data,
    required this.name,
  });

  @override
  String toString() => 'ExportLogsArchive(name: $name, size: ${data.length} bytes)';
}
