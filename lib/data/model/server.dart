import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';

/// {@template server}
/// A fully resolved VPN server configuration used by the app.
///
/// `Server` combines server connection credentials and transport parameters
/// with the associated [RoutingProfile]. This is a convenient domain model for
/// UI and business logic where you need both server details and routing rules
/// in one place.
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class Server {
  /// Database identifier of the server record.
  final int id;

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
  final RoutingProfile routingProfile;

  /// Whether this server is marked as the currently selected one.
  final bool selected;

  /// {@macro server}
  const Server({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.domain,
    required this.username,
    required this.password,
    required this.vpnProtocol,
    required this.dnsServers,
    required this.routingProfile,
    this.selected = false,
  });

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ipAddress,
    domain,
    username,
    password,
    vpnProtocol,
    Object.hashAll(dnsServers),
    routingProfile,
    selected,
  );

  @override
  String toString() =>
      'Server('
      'id: $id, '
      'name: $name, '
      'ipAddress: $ipAddress, '
      'domain: $domain, '
      'username: $username, '
      'vpnProtocol: $vpnProtocol, '
      'dnsServers: $dnsServers, '
      'routingProfile: $routingProfile, '
      'selected: $selected'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Server &&
        other.id == id &&
        other.name == name &&
        other.ipAddress == ipAddress &&
        other.domain == domain &&
        other.username == username &&
        other.password == password &&
        other.vpnProtocol == vpnProtocol &&
        listEquals(other.dnsServers, dnsServers) &&
        other.routingProfile == routingProfile &&
        other.selected == selected;
  }

  /// Creates a copy of this server with the given fields replaced.
  ///
  /// Fields that are not provided retain their original values.
  Server copyWith({
    int? id,
    String? name,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    VpnProtocol? vpnProtocol,
    List<String>? dnsServers,
    RoutingProfile? routingProfile,
    bool? selected,
  }) => Server(
    id: id ?? this.id,
    name: name ?? this.name,
    ipAddress: ipAddress ?? this.ipAddress,
    domain: domain ?? this.domain,
    username: username ?? this.username,
    password: password ?? this.password,
    vpnProtocol: vpnProtocol ?? this.vpnProtocol,
    dnsServers: dnsServers ?? this.dnsServers,
    routingProfile: routingProfile ?? this.routingProfile,
    selected: selected ?? this.selected,
  );
}
