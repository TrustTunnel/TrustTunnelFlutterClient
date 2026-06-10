import 'package:trusttunnel/common/logging/model/app_log_metadata.dart';

/// Builds log file names and keeps metadata sorted like files on disk.
final class AppLogFileNamesBuilder {
  static final _sequencePattern = RegExp(r'_(\d+)\.log$');

  final String baseName;

  const AppLogFileNamesBuilder({
    required this.baseName,
  });

  String nextId({
    required DateTime currentDateTime,
    required Iterable<String> existingIds,
  }) {
    final date = _formatDate(currentDateTime.toUtc());
    final prefix = '${baseName}_$date';
    final ids = existingIds.where((id) => id.startsWith(prefix)).toSet();
    var suffix = 0;
    var id = '$prefix.log';
    while (ids.contains(id)) {
      suffix++;
      id = '${prefix}_$suffix.log';
    }

    return id;
  }

  int compare(AppLogMetadata first, AppLogMetadata second) {
    final byDate = first.createdAt.compareTo(second.createdAt);
    if (byDate != 0) {
      return byDate;
    }

    final bySequence = _fileSequence(first.id).compareTo(_fileSequence(second.id));

    return bySequence == 0 ? first.id.compareTo(second.id) : bySequence;
  }

  static String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static int _fileSequence(String id) => int.tryParse(_sequencePattern.firstMatch(id)?.group(1) ?? '') ?? 0;
}
