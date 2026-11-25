abstract class RoutingDetailsService {
  /// Returns the first free name from [formatName], starting with index zero.
  ///
  /// The formatter must return a distinct name for each index.
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
    for (int number = 0; number <= normalizedNames.length; number++) {
      final name = formatName(number);
      if (!normalizedNames.contains(name.trim().toLowerCase())) {
        return name;
      }
    }

    throw StateError('The profile name formatter did not produce a free name.');
  }
}
