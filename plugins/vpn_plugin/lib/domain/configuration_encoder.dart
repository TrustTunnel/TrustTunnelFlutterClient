import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:vpn_plugin/models/configuration.dart';

/// {@template configuration_encoder}
/// Encodes a high-level [Configuration] object into a textual VPN configuration.
///
/// This encoder is responsible for converting the structured Dart
/// configuration model into a single configuration document understood by
/// the native VPN backend. The output format is a stable, INI-like text file
/// with sections and key-value pairs.
///
/// ### Responsibilities
/// - Serialize all configuration sections (logging, endpoint, listener).
/// - Apply consistent quoting and list formatting rules.
/// - Normalize endpoint addresses by adding fallback ports when missing.
///
///
/// The encoder is deterministic: identical [Configuration] inputs always
/// produce identical output strings.
///
/// Instances are immutable and may be reused safely.
/// {@endtemplate}
@immutable
final class ConfigurationEncoder extends Converter<Configuration, String> {
  /// {@macro configuration_encoder}
  const ConfigurationEncoder();

  /// {@template configuration_encoder_convert}
  /// Converts a [Configuration] into a backend configuration string.
  ///
  /// The returned string represents the full configuration file content and
  /// can be passed directly to the VPN backend.
  ///
  /// ### Formatting rules
  /// - `String` values are always emitted as quoted strings.
  /// - Empty strings are emitted as `""`.
  /// - Boolean and numeric values use their `toString()` representation.
  /// - Lists are emitted in bracket notation: `["a", "b"]`.
  /// - `null` list elements are omitted.
  /// - Endpoint addresses without an explicit port receive a fallback port
  ///   (`443` by default).
  ///
  /// ### Error handling
  /// This method does not perform validation and does not throw under normal
  /// circumstances. Invalid or unsupported values are serialized as-is.
  /// {@endtemplate}
  @override
  String convert(Configuration configuration) {
    final String logLevel = _parseToConfigString(configuration.logLevel.value);
    final String vpnMode = _parseToConfigString(configuration.vpnMode.value);

    final bool killSwitchEnabled = configuration.killSwitchEnabled;
    final bool postQuantumGroupEnabled = configuration.postQuantumGroupEnabled;

    final String exclusions = _parseToConfigList(configuration.endpoint.exclusions);
    final String dnsUpStreams = _parseToConfigList(configuration.endpoint.dnsUpStreams);
    final String hostName = _parseToConfigString(configuration.endpoint.hostName);

    final bool hasIpv6 = false;

    final String addresses = _parseHostAddresses(configuration.endpoint.addresses);

    final String userName = _parseToConfigString(configuration.endpoint.username);
    final String password = _parseToConfigString(configuration.endpoint.password);
    final String clientRandom = _parseToConfigString('5841/7a43');

    final bool skipVerification = configuration.endpoint.skipVerification;

    final String certificate = _parseCertificateToString(configuration.endpoint.certificate);

    final String upstreamProtocol = _parseToConfigString(configuration.endpoint.upStreamProtocol.value);

    final String upstreamFallbackProtocol = _parseToConfigString(
      configuration.endpoint.upStreamFallbackProtocol?.value ?? '',
    );

    final bool antiDpi = configuration.endpoint.antiDpi;

    final String tunIncludedRoutes = _parseToConfigList(configuration.tun.includedRoutes);
    final String tunExcludedRoutes = _parseToConfigList(configuration.tun.excludedRoutes);

    final int tunMtuSize = configuration.tun.mtuSize;

    final String socksAddress = _parseToConfigString(configuration.socks.address);
    final String socksUsername = _parseToConfigString(configuration.socks.username);
    final String socksPassword = _parseToConfigString(configuration.socks.password);

    final String customSni = _parseToConfigString(configuration.endpoint.customSni);

    return _parseBaseConfiguration(
      logLevel: logLevel,
      vpnMode: vpnMode,
      killSwitchEnabled: killSwitchEnabled,
      postQuantumGroupEnabled: postQuantumGroupEnabled,
      exclusions: exclusions,
      dnsUpStreams: dnsUpStreams,
      hostName: hostName,
      addresses: addresses,
      hasIpv6: hasIpv6,
      username: userName,
      password: password,
      clientRandom: clientRandom,
      skipVerification: skipVerification,
      certificate: certificate,
      upstreamProtocol: upstreamProtocol,
      upstreamFallbackProtocol: upstreamFallbackProtocol,
      antiDpi: antiDpi,
      tunIncludedRoutes: tunIncludedRoutes,
      tunExcludedRoutes: tunExcludedRoutes,
      tunMtuSize: tunMtuSize,
      socksAddress: socksAddress,
      socksUsername: socksUsername,
      socksPassword: socksPassword,
      customSni: customSni,
    );
  }

  /// {@template configuration_encoder_host_addresses}
  /// Formats endpoint addresses into a configuration list.
  ///
  /// Each address may be an IPv4 or IPv6 literal, with or without a port.
  /// If the port is missing, a fallback port is appended.
  /// {@endtemplate}

  String _parseHostAddresses(List<String> addresses) {
    final resultList = addresses.map(_parseAddress);
    return _parseToConfigList(resultList);
  }

  /// {@template configuration_encoder_address}
  /// Normalizes a single endpoint address.
  ///
  /// If the address does not specify a port, [fallbackPort] is appended.
  /// IPv6 literals are wrapped in square brackets when a port is added.
  /// {@endtemplate}
  String _parseAddress(String address, {int fallbackPort = 443}) {
    final bool isIpv6 = RegExp(':').allMatches(address).length > 1;
    final String portDivider = isIpv6 ? ']:' : ':';
    final List<String> divided = address.split(portDivider);

    if (divided.length == 1) {
      if (isIpv6) {
        address = '[$address]';
      }
      address = '$address:$fallbackPort';
    }
    return address;
  }

  /// {@template configuration_encoder_list}
  /// Converts an iterable into a configuration list literal.
  ///
  /// `null` elements are skipped. All values are serialized using the same
  /// rules as scalar configuration values.
  /// {@endtemplate}
  String _parseToConfigList(Iterable<Object?> list) => '[${list.nonNulls.map(_parseToConfigString).join(', ')}]';

  /// {@template configuration_encoder_certificate}
  /// Formats a PEM certificate for inclusion in the configuration.
  ///
  /// Non-empty certificates are wrapped in quotes and surrounded by line
  /// breaks so the backend receives a multi-line string value.
  /// {@endtemplate}
  String _parseCertificateToString(String certificate) {
    var certificateCopy = certificate;
    if (certificateCopy.isNotEmpty) {
      certificateCopy = '"\n$certificateCopy\n"';
    }
    return _parseToConfigString(certificateCopy);
  }

  /// {@template configuration_encoder_scalar}
  /// Converts a scalar value into its configuration string representation.
  ///
  /// Strings are always quoted; all other values use `toString()`.
  /// {@endtemplate}
  String _parseToConfigString(Object? object) {
    if (object is String || object == null) {
      return (object as String? ?? '').isEmpty ? '""' : '"$object"';
    }
    return object.toString();
  }

  /// {@template configuration_encoder_template}
  /// Assembles the final configuration document.
  ///
  /// This method interpolates already-formatted values into a static template.
  /// It must not perform validation or transformation logic.
  /// {@endtemplate}
  String _parseBaseConfiguration({
    required String logLevel,
    required String vpnMode,
    required bool killSwitchEnabled,
    required bool postQuantumGroupEnabled,
    required String exclusions,
    required String dnsUpStreams,
    required String hostName,
    required String addresses,
    required bool hasIpv6,
    required String username,
    required String password,
    required String clientRandom,
    required bool skipVerification,
    required String certificate,
    required String upstreamProtocol,
    required String upstreamFallbackProtocol,
    required bool antiDpi,
    required String tunIncludedRoutes,
    required String tunExcludedRoutes,
    required int tunMtuSize,
    required String socksAddress,
    required String socksUsername,
    required String socksPassword,
    required String customSni,
  }) => '''
# Logging level [info, debug, trace]
loglevel = $logLevel

# VPN mode.
# Defines client connections routing policy:
# * general: route through a VPN endpoint all connections except ones which destinations are in exclusions,
# * selective: route through a VPN endpoint only the connections which destinations are in exclusions.
vpn_mode = $vpnMode

# When disabled, all connection requests are routed directly to target hosts
# in case connection to VPN endpoint is lost. This helps not to break an
# Internet connection if user has poor connectivity to an endpoint.
# When enabled, incoming connection requests which should be routed through
# an endpoint will not be routed directly in that case.
killswitch_enabled = $killSwitchEnabled

# When enabled, a post-quantum group may be used for key exchange
# in TLS handshakes initiated by the VPN client.
post_quantum_group_enabled = $postQuantumGroupEnabled

# Domains and addresses which should be routed in a special manner.
# Supported syntax:
#   * domain name
#     * if starts with "*.", any subdomain of the domain will be matched including
#       www-subdomain, but not the domain itself (e.g., `*.example.com`  will match
#       `sub.example.com` , `sub.sub.example.com` , `www.example.com` , but not `example.com` )
#     * if starts with "www." or it's just a domain name, the domain itself and its
#       www-subdomain will be matched (e.g. `example.com`  and `www.example.com`  will
#       match `example.com`  `www.example.com` , but not `sub.example.com` )
#   * ip address
#     * recognized formats are:
#       * [IPv6Address]:port
#       * [IPv6Address]
#       * IPv6Address
#       * IPv4Address:port
#       * IPv4Address
#     * if port is not specified, any port will be matched
#   * CIDR range
#     * recognized formats are:
#       * IPv4Address/mask
#       * IPv6Address/mask
exclusions = $exclusions

# DNS upstreams.
# If specified, the library intercepts and routes plain DNS queries
# going through the endpoint to the DNS resolvers.
# One of the following kinds:
#   * 8.8.8.8:53 -- plain DNS
#   * tcp://8.8.8.8:53 -- plain DNS over TCP
#   * tls://1.1.1.1 -- DNS-over-TLS
#   * https://dns.adguard.com/dns-query -- DNS-over-HTTPS
#   * sdns://... -- DNS stamp (see https://dnscrypt.info/stamps-specifications)
#   * quic://dns.adguard.com:8853 -- DNS-over-QUIC
dns_upstreams = $dnsUpStreams

# The set of endpoint connection settings
[endpoint]
# Endpoint host name, used for TLS session establishment
hostname = $hostName
# Endpoint addresses.
# The exact address is selected by the pinger. Absence of IPv6 addresses in
# the list makes the VPN client reject IPv6 connections which must be routed
# through the endpoint with unreachable code.
addresses = $addresses
# Whether IPv6 traffic can be routed through the endpoint
has_ipv6 = $hasIpv6
# Username for authorization
username = $username
# Password for authorization
password = $password
# TLS client random prefix (hex string)
client_random = $clientRandom
# Skip the endpoint certificate verification?
# That is, any certificate is accepted with this one set to true.
skip_verification = $skipVerification
# Endpoint certificate in PEM format.
# If not specified, the endpoint certificate is verified using the system storage.
certificate = $certificate
# Protocol to be used to communicate with the endpoint [http2, http3]
upstream_protocol = $upstreamProtocol
# Fallback protocol to be used in case the main one fails [<none>, http2, http3]
upstream_fallback_protocol = $upstreamFallbackProtocol
# Is anti-DPI measures should be enabled
anti_dpi = $antiDpi

custom_sni = $customSni

# Defines the way to listen to network traffic by the kind of the nested table.
# Possible types:
#   * socks: SOCKS proxy with UDP support,
#   * tun: TUN device.
[listener]

[listener.tun]
# Name of the interface used for connections made by the VPN client.
# On Linux and Windows, it is detected automatically if not specified.
# On macOS, it defaults to `en0`  if not specified.
# On Windows, an interface index as shown by `route print` , written as a string, may be used instead of a name.
# bound_if = "en0"
# Routes in CIDR notation to set to the virtual interface
included_routes = $tunIncludedRoutes
# Routes in CIDR notation to exclude from routing through the virtual interface
excluded_routes = $tunExcludedRoutes
# MTU size on the interface
mtu_size = $tunMtuSize

# [listener.socks]
# # IP address to bind the listener to
# address = $socksAddress
# # Username for authentication if desired
# username = $socksUsername
# # Password for authentication if desired
# password = $socksPassword
''';
}
