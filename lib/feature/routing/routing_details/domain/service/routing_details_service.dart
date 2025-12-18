import 'dart:math' as math;

import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/feature/routing/routing_details/model/routing_details_data.dart';

abstract class RoutingDetailsService {
  RoutingDetailsData toRoutingDetailsData({required RoutingProfile routingProfile});

  String getNewProfileName(Set<String> occupiedNames);
}

class RoutingDetailsServiceImpl implements RoutingDetailsService {
  @override
  RoutingDetailsData toRoutingDetailsData({required RoutingProfile routingProfile}) => RoutingDetailsData(
    defaultMode: routingProfile.defaultMode,
    bypassRules: routingProfile.bypassRules,
    vpnRules: routingProfile.vpnRules,
  );

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
