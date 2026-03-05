import 'dart:math' as math;

abstract class RoutingDetailsService {
  String getNewProfileName(Set<String> occupiedNames);
}

class RoutingDetailsServiceImpl implements RoutingDetailsService {
  @override
  String getNewProfileName(Set<String> occupiedNames) {
    final profileNames = occupiedNames.where((name) => name.startsWith('Profile')).map((name) {
      final profileNumber = name.split('Profile ').elementAtOrNull(1);
      if (profileNumber == null) return null;

      return int.tryParse(profileNumber);
    });

    final generatedNames = profileNames.whereType<int>();
    if (generatedNames.isEmpty && !occupiedNames.contains('Profile')) return 'Profile';
    final maxProfileNumber = generatedNames.fold(0, math.max) + 1;

    return 'Profile $maxProfileNumber';
  }
}
