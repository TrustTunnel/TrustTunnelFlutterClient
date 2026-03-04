import 'package:flutter/foundation.dart';
import 'package:vpn_plugin/models/upstream_protocol.dart';

/// {@template endpoint}
/// Connection settings for a remote VPN endpoint.
///
/// [Endpoint] defines how the client connects to the VPN server:
/// - possible server [addresses] and TLS [hostName],
/// - authentication ([username], [password]),
/// - certificate pinning and verification behavior,
/// - upstream protocol selection and optional fallback,
/// - optional traffic-handling features (e.g. anti-DPI).
///
/// This class is a data container. It does not validate that values are
/// syntactically correct (for example, that an address is a valid IP literal),
/// unless the backend enforces it later.
/// {@endtemplate}
final class Endpoint {
  /// {@template endpoint_addresses}
  /// Candidate endpoint addresses to connect to.
  ///
  /// Each entry is typically an IP literal (IPv4 or IPv6) with an optional port.
  /// The backend (or encoder) may normalize entries without a port by applying
  /// a default port.
  ///
  /// An empty list usually means the backend will rely on other discovery or
  /// configuration mechanisms (if supported).
  /// {@endtemplate}
  final List<String> addresses;

  /// {@template endpoint_dns_upstreams}
  /// DNS upstream resolvers used when DNS interception/routing is enabled.
  ///
  /// The exact accepted formats depend on the backend. Common examples include:
  /// - `8.8.8.8:53` (plain DNS)
  /// - `tcp://8.8.8.8:53`
  /// - `tls://1.1.1.1`
  /// - `https://dns.example.com/dns-query`
  /// - DNS stamps (`sdns://...`)
  /// {@endtemplate}
  final List<String> dnsUpStreams;

  /// {@template endpoint_exclusions}
  /// Domains, IP addresses, or CIDR ranges that should be treated specially.
  ///
  /// The interpretation depends on the routing mode and backend rules. In many
  /// setups, exclusions define destinations that should be bypassed or tunneled
  /// depending on the selected [VpnMode] at the [Configuration] level.
  /// {@endtemplate}
  final List<String> exclusions;

  /// {@template endpoint_host_name}
  /// Host name used for TLS session establishment.
  ///
  /// This is typically used for SNI and certificate validation.
  /// {@endtemplate}
  final String hostName;

  /// {@template endpoint_username}
  /// Username used for endpoint authentication.
  /// {@endtemplate}
  final String username;

  /// {@template endpoint_password}
  /// Password used for endpoint authentication.
  /// {@endtemplate}
  final String password;

  /// {@template endpoint_client_random}
  /// TLS client random prefix represented as a hex string.
  ///
  /// This value is forwarded to the backend as-is. If the backend does not
  /// support this feature, it may be ignored.
  /// {@endtemplate}
  final String clientRandom;

  /// {@template endpoint_certificate}
  /// Endpoint certificate in PEM format.
  ///
  /// When provided, the backend may use it for certificate pinning or custom
  /// verification. When empty, the system trust store is typically used.
  /// {@endtemplate}
  final String certificate;

  /// {@template endpoint_upstream_protocol}
  /// Primary protocol used to communicate with the endpoint.
  /// {@endtemplate}
  final UpStreamProtocol upStreamProtocol;

  /// {@template endpoint_upstream_fallback_protocol}
  /// Optional fallback protocol used when [upStreamProtocol] fails.
  ///
  /// When `null`, the backend may treat this as "no fallback".
  /// {@endtemplate}
  final UpStreamProtocol? upStreamFallbackProtocol;

  /// {@template endpoint_anti_dpi}
  /// Whether anti-DPI measures should be enabled.
  ///
  /// The exact techniques and availability depend on the backend.
  /// {@endtemplate}
  final bool antiDpi;

  /// {@template endpoint_has_ipv6}
  /// Whether IPv6 traffic may be routed through the endpoint.
  ///
  /// This is typically used by the backend to decide whether IPv6 connections
  /// can be accepted and tunneled.
  /// {@endtemplate}
  final bool hasIpv6;

  /// {@template endpoint_skip_verification}
  /// Whether endpoint TLS certificate verification should be skipped.
  ///
  /// When `true`, any certificate may be accepted. This is dangerous and should
  /// generally only be used for debugging or controlled environments.
  /// {@endtemplate}
  final bool skipVerification;

  /// {@macro endpoint}
  ///
  /// Defaults are intentionally permissive:
  /// - [addresses], [dnsUpStreams] and [exclusions] default to empty lists.
  /// - [clientRandom] and [certificate] default to empty strings.
  /// - [skipVerification] and [antiDpi] default to `false`.
  /// - [upStreamFallbackProtocol] defaults to `null` (no explicit fallback).
  Endpoint({
    this.addresses = const [],
    this.dnsUpStreams = const [],
    this.exclusions = const [],
    this.clientRandom = '',
    this.certificate = '',
    this.upStreamFallbackProtocol,
    this.antiDpi = false,
    this.skipVerification = false,
    required this.hostName,
    required this.username,
    required this.password,
    required this.upStreamProtocol,
    required this.hasIpv6,
  });

  @override
  String toString() =>
      'Endpoint(addresses: $addresses, dnsUpStreams: $dnsUpStreams, exclusions: $exclusions, hostName: $hostName, username: $username, password: $password, clientRandom: $clientRandom, certificate: $certificate, upStreamProtocol: $upStreamProtocol, upStreamFallbackProtocol: $upStreamFallbackProtocol, antiDpi: $antiDpi, hasIpv6: $hasIpv6, skipVerification: $skipVerification)';

  @override
  bool operator ==(covariant Endpoint other) {
    if (identical(this, other)) return true;

    return listEquals(other.addresses, addresses) &&
        listEquals(other.dnsUpStreams, dnsUpStreams) &&
        listEquals(other.exclusions, exclusions) &&
        other.hostName == hostName &&
        other.username == username &&
        other.password == password &&
        other.clientRandom == clientRandom &&
        other.certificate == certificate &&
        other.upStreamProtocol == upStreamProtocol &&
        other.upStreamFallbackProtocol == upStreamFallbackProtocol &&
        other.antiDpi == antiDpi &&
        other.hasIpv6 == hasIpv6 &&
        other.skipVerification == skipVerification;
  }

  @override
  int get hashCode => Object.hashAll([
    addresses.hashCode,
    dnsUpStreams.hashCode,
    exclusions.hashCode,
    hostName.hashCode,
    username.hashCode,
    password.hashCode,
    clientRandom.hashCode,
    certificate.hashCode,
    upStreamProtocol.hashCode,
    upStreamFallbackProtocol.hashCode,
    antiDpi.hashCode,
    hasIpv6.hashCode,
    skipVerification.hashCode,
  ]);
}
