import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/certificate.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

/// {@template server}
/// A fully resolved VPN server configuration used by the app.
///
/// `Server` combines server connection credentials and transport parameters
/// with the associated []. This is a convenient domain model for
/// UI and business logic where you need both server details and routing rules
/// in one place.
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class ServerData {
  /// User-visible server name.
  final String name;

  /// Server IP address (usually IPv4/IPv6 literal as stored by the app).
  final String ipAddress;

  /// Server host name used for TLS (SNI / certificate verification).
  final String domain;

  /// Username used for authentication.
  final String username;

  /// Password used for authentication.
  final String password;

  /// Transport protocol used to communicate with the server.
  final VpnProtocol vpnProtocol;

  /// DNS upstream addresses associated with this server.
  ///
  /// The list is expected to be treated as immutable by callers.
  final List<String> dnsServers;

  /// Routing profile applied when connecting to this server.
  final String routingProfileId;

  /// Whether this server is marked as the currently selected one.
  final bool selected;

  final Certificate? certificate;

  final bool ipv6;

  final String? tlsPrefix;

  final String? customSni;

  /// {@macro server}
  const ServerData({
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.username,
    required this.password,
    required this.vpnProtocol,
    required this.dnsServers,
    required this.routingProfileId,
    required this.ipv6,
    this.certificate,
    this.tlsPrefix,
    this.customSni,
    this.selected = false,
  });

  const ServerData.empty({
    this.name = '',
    this.ipAddress = '',
    this.domain = '',
    this.username = '',
    this.password = '',
    this.vpnProtocol = VpnProtocol.http2,
    this.dnsServers = const [],
    this.routingProfileId = '',
    this.ipv6 = true,
    this.certificate,
    this.tlsPrefix,
    this.customSni,
    this.selected = false,
  });

  @override
  int get hashCode => Object.hash(
    name,
    ipAddress,
    domain,
    username,
    password,
    vpnProtocol,
    Object.hashAll(dnsServers),
    routingProfileId,
    selected,
    certificate,
    ipv6,
    tlsPrefix,
    customSni,
  );

  @override
  String toString() =>
      'ServerData('
      'name: $name, '
      'ipAddress: $ipAddress, '
      'domain: $domain, '
      'customSni: $customSni, '
      'username: $username, '
      'vpnProtocol: $vpnProtocol, '
      'dnsServers: $dnsServers, '
      'routingProfile: $routingProfileId, '
      'selected: $selected,'
      'ipv6: $ipv6,'
      'tlsPrefix: $tlsPrefix,'
      'certificate: $certificate,'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ServerData &&
        other.name == name &&
        other.ipAddress == ipAddress &&
        other.domain == domain &&
        other.username == username &&
        other.password == password &&
        other.vpnProtocol == vpnProtocol &&
        listEquals(other.dnsServers, dnsServers) &&
        other.routingProfileId == routingProfileId &&
        other.selected == selected &&
        other.ipv6 == ipv6 &&
        other.tlsPrefix == tlsPrefix &&
        other.certificate == certificate &&
        other.customSni == customSni;
  }

  /// Creates a copy of this server with the given fields replaced.
  ///
  /// Fields that are not provided retain their original values.
  ServerData copyWith({
    String? name,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    VpnProtocol? vpnProtocol,
    List<String>? dnsServers,
    String? routingProfileId,
    bool? selected,
    bool? ipv6,
    ValueData<Certificate>? certificate,
    ValueData<String>? tlsPrefix,
    ValueData<String>? customSni,
  }) => ServerData(
    name: name ?? this.name,
    ipAddress: ipAddress ?? this.ipAddress,
    domain: domain ?? this.domain,
    username: username ?? this.username,
    password: password ?? this.password,
    vpnProtocol: vpnProtocol ?? this.vpnProtocol,
    dnsServers: dnsServers ?? this.dnsServers,
    routingProfileId: routingProfileId ?? this.routingProfileId,
    selected: selected ?? this.selected,
    ipv6: ipv6 ?? this.ipv6,
    certificate: certificate != null ? certificate.value : this.certificate,
    tlsPrefix: tlsPrefix != null ? tlsPrefix.value : this.tlsPrefix,
    customSni: customSni != null ? customSni.value : this.customSni,
  );
}
