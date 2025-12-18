import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:trusttunnel/data/model/vpn_protocol.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';

/// {@template server_details_data}
/// Editable representation of VPN server connection details.
///
/// `ServerDetailsData` is a mutable-by-copy, immutable-by-contract data object
/// intended for **UI forms and editing flows** (for example, "Add server" or
/// "Edit server" screens).
///
/// Unlike domain models such as `Server` or `RawServer`, this class:
/// - provides **safe default values** for all fields,
/// - is suitable for incremental updates via [copyWith],
/// - does not imply that the data is valid or persisted.
///
/// Validation, normalization, and conversion to persistence or domain models
/// are expected to be handled by upper layers.
///
/// ## Typical usage
/// ```dart
/// var data = const ServerDetailsData();
///
/// data = data.copyWith(serverName: 'My VPN');
/// data = data.copyWith(ipAddress: '1.2.3.4');
/// ```
///
/// Instances are immutable and use value-based equality.
/// {@endtemplate}
@immutable
class ServerDetailsData {
  /// User-visible server name.
  ///
  /// May be empty while the user is editing the form.
  final String serverName;

  /// Server IP address (IPv4/IPv6 literal).
  ///
  /// Stored as entered by the user; not guaranteed to be valid.
  final String ipAddress;

  /// Server domain name used for TLS (SNI / certificate verification).
  ///
  /// May be empty if the server is addressed by IP only.
  final String domain;

  /// Username used for authentication.
  ///
  /// May be empty if authentication is not required or not yet entered.
  final String username;

  /// Password used for authentication.
  ///
  /// May be empty while editing or if authentication is not required.
  final String password;

  /// Transport protocol selected for server communication.
  ///
  /// Defaults to [VpnProtocol.http2].
  final VpnProtocol protocol;

  /// Identifier of the routing profile selected for this server.
  ///
  /// Defaults to [RoutingProfileUtils.defaultRoutingProfileId].
  final int routingProfileId;

  /// DNS upstream addresses associated with the server.
  ///
  /// The list is expected to be treated as immutable by callers.
  final List<String> dnsServers;

  /// {@macro server_details_data}
  const ServerDetailsData({
    this.serverName = '',
    this.ipAddress = '',
    this.domain = '',
    this.username = '',
    this.password = '',
    this.protocol = VpnProtocol.http2,
    this.routingProfileId = RoutingProfileUtils.defaultRoutingProfileId,
    this.dnsServers = const <String>[],
  });

  @override
  int get hashCode => Object.hash(
    serverName,
    ipAddress,
    domain,
    username,
    password,
    protocol,
    routingProfileId,
    Object.hashAll(dnsServers),
  );

  @override
  String toString() =>
      'ServerDetailsData('
      'serverName: $serverName, '
      'ipAddress: $ipAddress, '
      'domain: $domain, '
      'username: $username, '
      'protocol: $protocol, '
      'routingProfileId: $routingProfileId, '
      'dnsServers: $dnsServers'
      ')';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ServerDetailsData &&
        other.serverName == serverName &&
        other.ipAddress == ipAddress &&
        other.domain == domain &&
        other.username == username &&
        other.password == password &&
        other.protocol == protocol &&
        other.routingProfileId == routingProfileId &&
        listEquals(other.dnsServers, dnsServers);
  }

  ServerDetailsData copyWith({
    String? serverName,
    String? ipAddress,
    String? domain,
    String? username,
    String? password,
    VpnProtocol? protocol,
    int? routingProfileId,
    List<String>? dnsServers,
  }) => ServerDetailsData(
    serverName: serverName ?? this.serverName,
    ipAddress: ipAddress ?? this.ipAddress,
    domain: domain ?? this.domain,
    username: username ?? this.username,
    password: password ?? this.password,
    protocol: protocol ?? this.protocol,
    routingProfileId: routingProfileId ?? this.routingProfileId,
    dnsServers: dnsServers ?? this.dnsServers,
  );
}
