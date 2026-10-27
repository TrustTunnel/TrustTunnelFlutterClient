abstract final class ServerNameUtils {
  /// Finds a free name using the same normalization as server validation.
  /// Builds numbered candidates from the trimmed [baseName].
  static String findAvailable({
    required String baseName,
    required Iterable<String> otherNames,
    required String Function(String name, int number) numberedName,
    String? preferredName,
  }) {
    final normalizedNames = otherNames.map((name) => name.trim().toLowerCase()).toSet();
    final baseNameTrimmed = baseName.trim();

    final baseCandidate = preferredName ?? baseNameTrimmed;
    if (!normalizedNames.contains(baseCandidate.trim().toLowerCase())) {
      return baseCandidate;
    }

    for (int number = 2; ; number++) {
      final candidate = numberedName(baseNameTrimmed, number);
      if (!normalizedNames.contains(candidate.trim().toLowerCase())) {
        return candidate;
      }
    }
  }
}
