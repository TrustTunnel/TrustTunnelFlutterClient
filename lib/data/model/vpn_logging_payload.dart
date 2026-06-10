import 'package:trusttunnel/data/model/routing_profile_data.dart';
import 'package:trusttunnel/data/model/server_data.dart';

final class VpnLoggingPayload {
  final VpnLoggingServerPayload serverPayload;
  final VpnLoggingRoutingProfilePayload routingProfilePayload;
  final List<String> excludedRoutes;

  const VpnLoggingPayload({
    required this.serverPayload,
    required this.routingProfilePayload,
    required this.excludedRoutes,
  });

  factory VpnLoggingPayload.fromModels({
    required ServerData server,
    required RoutingProfileData routingProfile,
    required List<String> excludedRoutes,
  }) => VpnLoggingPayload(
    serverPayload: VpnLoggingServerPayload.fromModel(server),
    routingProfilePayload: VpnLoggingRoutingProfilePayload.fromModel(routingProfile),
    excludedRoutes: List.unmodifiable(excludedRoutes),
  );

  Map<String, Object?> toJson() => {
    'server': serverPayload.toJson(),
    'routingProfile': routingProfilePayload.toJson(),
    'excludedRoutes': excludedRoutes,
  };
}

final class VpnLoggingServerPayload {
  final String name;
  final String ipAddress;
  final String domain;
  final String? customSni;
  final String username;
  final List<String> dnsServers;
  final String? tlsPrefix;
  final String? certificate;
  final String vpnProtocol;
  final bool ipv6;

  const VpnLoggingServerPayload({
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.customSni,
    required this.username,
    required this.dnsServers,
    required this.tlsPrefix,
    required this.certificate,
    required this.vpnProtocol,
    required this.ipv6,
  });

  factory VpnLoggingServerPayload.fromModel(ServerData server) => VpnLoggingServerPayload(
    name: server.name,
    ipAddress: server.ipAddress,
    domain: server.domain,
    customSni: server.customSni,
    username: server.username,
    dnsServers: List.unmodifiable(server.dnsServers),
    tlsPrefix: server.tlsPrefix,
    certificate: server.certificate?.data,
    vpnProtocol: server.vpnProtocol.name,
    ipv6: server.ipv6,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'ipAddress': ipAddress,
    'domain': domain,
    'customSni': customSni,
    'username': username,
    'dnsServers': dnsServers,
    'tlsPrefix': tlsPrefix,
    'certificate': certificate,
    'vpnProtocol': vpnProtocol,
    'ipv6': ipv6,
  };
}

final class VpnLoggingRoutingProfilePayload {
  final String name;
  final String mode;
  final List<String> bypassRules;
  final List<String> vpnRules;

  const VpnLoggingRoutingProfilePayload({
    required this.name,
    required this.mode,
    required this.bypassRules,
    required this.vpnRules,
  });

  factory VpnLoggingRoutingProfilePayload.fromModel(RoutingProfileData routingProfile) =>
      VpnLoggingRoutingProfilePayload(
        name: routingProfile.name,
        mode: routingProfile.defaultMode.name,
        bypassRules: List.unmodifiable(routingProfile.bypassRules),
        vpnRules: List.unmodifiable(routingProfile.vpnRules),
      );

  Map<String, Object?> toJson() => {
    'name': name,
    'mode': mode,
    'bypassRules': bypassRules,
    'vpnRules': vpnRules,
  };
}
