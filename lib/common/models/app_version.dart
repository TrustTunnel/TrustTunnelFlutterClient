import 'package:flutter/foundation.dart';

@immutable
final class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
  });

  static AppVersion parse(String value) {
    final RegExpMatch? match = RegExp(r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$').firstMatch(value);

    if (match == null) {
      throw FormatException('Invalid application version', value);
    }

    return AppVersion(
      major: int.parse(match[1]!),
      minor: int.parse(match[2]!),
      patch: int.parse(match[3]!),
    );
  }

  @override
  int compareTo(AppVersion other) {
    for (final (int, int) pair in [(major, other.major), (minor, other.minor), (patch, other.patch)]) {
      final int result = pair.$1.compareTo(pair.$2);

      if (result != 0) {
        return result;
      }
    }

    return 0;
  }

  @override
  String toString() => '$major.$minor.$patch';
}
