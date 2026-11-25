abstract class RoutingDetailsService {
  /// Returns the first free name from [formatName], starting with index zero.
  ///
  /// Compares names after removing leading and trailing spaces and converting to lowercase.
  /// If all formatted candidates are blank or in use, adds a number to the base name.
  String getNewProfileName({
    required Iterable<String> occupiedNames,
    required String Function(int number) formatName,
  });
}

class RoutingDetailsServiceImpl implements RoutingDetailsService {
  @override
  String getNewProfileName({
    required Iterable<String> occupiedNames,
    required String Function(int number) formatName,
  }) {
    final normalizedNames = occupiedNames.map((name) => name.trim().toLowerCase()).toSet();
    final baseName = formatName(0).trim();
    for (int number = 0; number <= normalizedNames.length; number++) {
      final name = number == 0 ? baseName : formatName(number);
      final normalizedName = name.trim().toLowerCase();
      if (normalizedName.isNotEmpty && !normalizedNames.contains(normalizedName)) {
        return name;
      }
    }

    final prefix = baseName.isEmpty ? '' : '$baseName ';
    for (int number = 1; number <= normalizedNames.length; number++) {
      final name = '$prefix$number';
      if (!normalizedNames.contains(name.toLowerCase())) {
        return name;
      }
    }

    // All occupied names matched earlier candidates, so the next name is free.
    return '$prefix${normalizedNames.length + 1}';
  }
}
