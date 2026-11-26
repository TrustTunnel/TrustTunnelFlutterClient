import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/common/utils/tls_profile_encoder.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server_data.dart';
import 'package:trusttunnel/data/model/tls_authentication_type.dart';

final class VpnLoggingPayload {
  final VpnLoggingServerPayload serverPayload;
  final VpnLoggingRoutingProfilePayload routingProfilePayload;
  final List<String> excludedRoutes;

  const VpnLoggingPayload({
    required this.serverPayload,
    required this.routingProfilePayload,
    required this.excludedRoutes,
  });

  /// Creates a diagnostic payload with the routing profile's stored data and ID.
  factory VpnLoggingPayload.fromModels({
    required ServerData server,
    required RoutingProfile routingProfile,
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
  final VpnLoggingTlsAuthentication tlsAuthentication;
  final String? certificate;
  final String vpnProtocol;
  final String tlsProfile;
  final bool allowIpv6Connections;

  const VpnLoggingServerPayload({
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.customSni,
    required this.username,
    required this.dnsServers,
    required this.tlsAuthentication,
    required this.certificate,
    required this.vpnProtocol,
    required this.tlsProfile,
    required this.allowIpv6Connections,
  });

  factory VpnLoggingServerPayload.fromModel(ServerData server) => VpnLoggingServerPayload(
    name: server.name,
    ipAddress: server.ipAddress,
    domain: server.domain,
    customSni: server.customSni,
    username: server.username,
    dnsServers: List.unmodifiable(server.dnsServers),
    tlsAuthentication: switch (server.tlsAuthenticationType) {
      TlsAuthenticationType.clientRandom => VpnLoggingClientRandom(value: server.tlsPrefix),
      TlsAuthenticationType.clientRandomAuthKey => VpnLoggingClientRandomAuthKey(value: server.clientRandomAuthKey),
    },
    certificate: server.certificate?.data,
    vpnProtocol: server.vpnProtocol.name,
    tlsProfile: const TlsProfileEncoder()
        .convert(
          server.tlsFingerprint,
        )
        .value,
    allowIpv6Connections: server.ipv6,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'ipAddress': ipAddress,
    'domain': domain,
    'customSni': customSni,
    'username': username,
    'dnsServers': dnsServers,
    ...tlsAuthentication.toJson(),
    'certificate': certificate,
    'vpnProtocol': vpnProtocol,
    'tlsProfile': tlsProfile,
    'allowIpv6Connections': allowIpv6Connections,
  };
}

sealed class VpnLoggingTlsAuthentication {
  final String? value;

  const VpnLoggingTlsAuthentication({required this.value});

  Map<String, Object?> toJson();
}

final class VpnLoggingClientRandom extends VpnLoggingTlsAuthentication {
  const VpnLoggingClientRandom({required super.value});

  @override
  Map<String, Object?> toJson() => {
    'tlsAuthenticationType': TlsAuthenticationType.clientRandom.name,
    'clientRandom': value,
    'clientRandomAuthKey': null,
  };
}

final class VpnLoggingClientRandomAuthKey extends VpnLoggingTlsAuthentication {
  const VpnLoggingClientRandomAuthKey({required super.value});

  @override
  Map<String, Object?> toJson() => {
    'tlsAuthenticationType': TlsAuthenticationType.clientRandomAuthKey.name,
    'clientRandom': null,
    'clientRandomAuthKey': value,
  };
}

final class VpnLoggingRoutingProfilePayload {
  /// The stored ID of the routing profile.
  final String id;
  final String name;
  final String mode;
  final List<String> bypassRules;
  final List<String> vpnRules;

  /// Creates a diagnostic record for the profile with the specified [id].
  const VpnLoggingRoutingProfilePayload({
    required this.id,
    required this.name,
    required this.mode,
    required this.bypassRules,
    required this.vpnRules,
  });

  /// Copies the profile ID, stored name, mode, and rules into a diagnostic record.
  factory VpnLoggingRoutingProfilePayload.fromModel(RoutingProfile routingProfile) => VpnLoggingRoutingProfilePayload(
    id: routingProfile.id,
    name: routingProfile.data.name.value,
    mode: routingProfile.data.defaultMode.name,
    bypassRules: List.unmodifiable(routingProfile.data.bypassRules),
    vpnRules: List.unmodifiable(routingProfile.data.vpnRules),
  );

  /// Serializes the record with `isDefault` set for the built-in profile ID.
  Map<String, Object?> toJson() => {
    'id': id,
    'isDefault': id == RoutingProfileUtils.defaultRoutingProfileId,
    'name': name,
    'mode': mode,
    'bypassRules': bypassRules,
    'vpnRules': vpnRules,
  };
}
