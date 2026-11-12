import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';

@immutable
final class VpnConfiguration {
  final Server server;
  final RoutingProfile routingProfile;
  final List<String> excludedRoutes;
  final List<String> excludedApps;
  final VpnConfigurationLogLevel logLevel;

  VpnConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    this.excludedApps = const [],
    required this.logLevel,
  }) : server = server.copyWith(
         serverData: server.serverData.copyWith(
           // Selection is metadata and must not participate in configuration equality.
           selected: false,
           dnsServers: List.unmodifiable(server.serverData.dnsServers),
         ),
       ),
       routingProfile = routingProfile.copyWith(
         data: routingProfile.data.copyWith(
           bypassRules: List.unmodifiable(routingProfile.data.bypassRules),
           vpnRules: List.unmodifiable(routingProfile.data.vpnRules),
         ),
       ),
       excludedRoutes = List.unmodifiable(excludedRoutes);

  @override
  int get hashCode => Object.hashAll([
    server,
    routingProfile,
    Object.hashAll(excludedRoutes),
    Object.hashAll(excludedApps),
    logLevel,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VpnConfiguration &&
          server == other.server &&
          routingProfile == other.routingProfile &&
          listEquals(excludedRoutes, other.excludedRoutes) &&
          listEquals(excludedApps, other.excludedApps) &&
          logLevel == other.logLevel;
}
