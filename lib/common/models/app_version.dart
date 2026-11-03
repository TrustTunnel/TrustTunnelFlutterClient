import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

@immutable
final class AppVersion implements Comparable<AppVersion> {
  static final RegExp _versionPattern = RegExp(
    r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );
  static final RegExp _numericIdentifierPattern = RegExp(r'^[0-9]+$');

  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? buildMetadata;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.buildMetadata,
  });

  static AppVersion parse(String value) {
    final RegExpMatch? match = _versionPattern.firstMatch(value);

    if (match == null || match.end != value.length) {
      throw FormatException('Invalid application version', value);
    }

    final String? preRelease = match[4];
    final bool invalidPreRelease =
        preRelease != null &&
        preRelease
            .split('.')
            .any(
              (identifier) =>
                  (identifier.length > 1) &&
                  identifier.startsWith('0') &&
                  _numericIdentifierPattern.hasMatch(identifier),
            );

    if (invalidPreRelease) {
      throw FormatException('Invalid application version', value);
    }

    return AppVersion(
      major: int.parse(match[1]!),
      minor: int.parse(match[2]!),
      patch: int.parse(match[3]!),
      preRelease: preRelease,
      buildMetadata: match[5],
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

    final String? preRelease = this.preRelease;
    final String? otherPreRelease = other.preRelease;

    if (preRelease == null) {
      return otherPreRelease == null ? 0 : 1;
    }

    if (otherPreRelease == null) {
      return -1;
    }

    final List<String> identifiers = preRelease.split('.');
    final List<String> otherIdentifiers = otherPreRelease.split('.');
    final int commonLength = {identifiers.length, otherIdentifiers.length}.min;

    for (int index = 0; index < commonLength; index++) {
      final String identifier = identifiers[index];
      final String otherIdentifier = otherIdentifiers[index];
      final bool isNumeric = _numericIdentifierPattern.hasMatch(identifier);
      final bool otherIsNumeric = _numericIdentifierPattern.hasMatch(otherIdentifier);
      final int result;

      if (isNumeric && otherIsNumeric) {
        final int lengthComparison = identifier.length.compareTo(otherIdentifier.length);
        result = lengthComparison != 0 ? lengthComparison : identifier.compareTo(otherIdentifier);
      } else if (isNumeric != otherIsNumeric) {
        result = isNumeric ? -1 : 1;
      } else {
        result = identifier.compareTo(otherIdentifier);
      }

      if (result != 0) {
        return result;
      }
    }

    return identifiers.length.compareTo(otherIdentifiers.length);
  }

  @override
  String toString() =>
      '$major.$minor.$patch'
      '${preRelease == null ? '' : '-$preRelease'}'
      '${buildMetadata == null ? '' : '+$buildMetadata'}';
}
