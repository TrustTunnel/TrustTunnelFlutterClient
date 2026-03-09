// configuration_codeconfig.dart
//
// Unified bidirectional codec for the backend INI-like configuration.
//
// This file defines:
// - [ConfigurationCodec], [ConfigurationEncoder], [ConfigurationDecoder]
// - A minimal INI-ish document model ([IniDocument], [IniSection], [IniValue])
//
// The config format is INI-like with sections and key/value pairs.
// Values support TOML-like multiline strings using triple quotes: `""" ... """`.

import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:vpn_plugin/models/configuration.dart';
import 'package:vpn_plugin/models/configuration_log_level.dart';
import 'package:vpn_plugin/models/endpoint.dart';
import 'package:vpn_plugin/models/ini_document.dart';
import 'package:vpn_plugin/models/socks.dart';
import 'package:vpn_plugin/models/tun.dart';
import 'package:vpn_plugin/models/upstream_protocol.dart';
import 'package:vpn_plugin/models/vpn_mode.dart';

/// {@category VPN}
/// {@subCategory Configuration}
///
/// Stable backend keys and section names.
///
/// This class is the single source of truth for the textual configuration
/// layout used by [ConfigurationEncoder] and [ConfigurationDecoder].
abstract final class ConfigurationCodecKeys {
  // Top-level keys
  /// Top-level log level key.
  static const logLevel = 'loglevel';

  /// Top-level VPN mode key.
  static const vpnMode = 'vpn_mode';

  /// Top-level kill switch toggle key.
  static const killSwitchEnabled = 'killswitch_enabled';

  /// Top-level post-quantum group toggle key.
  static const postQuantumGroupEnabled = 'post_quantum_group_enabled';

  /// Top-level exclusions list key.
  static const exclusions = 'exclusions';

  /// Top-level DNS upstreams list key.
  static const dnsUpStreams = 'dns_upstreams';

  // Sections
  /// `[endpoint]` section name.
  static const endpointSection = 'endpoint';

  /// `[listener]` section name.
  static const listenerSection = 'listener';

  /// `[listener.tun]` section name.
  static const tunSection = 'listener.tun';

  /// `[listener.socks]` section name.
  static const socksSection = 'listener.socks';

  // Endpoint keys
  /// Endpoint host name key.
  static const hostname = 'hostname';

  /// Endpoint addresses list key.
  static const addresses = 'addresses';

  /// Endpoint IPv6 capability key.
  static const hasIpv6 = 'has_ipv6';

  /// Endpoint username key.
  static const username = 'username';

  /// Endpoint password key.
  static const password = 'password';

  /// Endpoint TLS client random key.
  static const clientRandom = 'client_random';

  /// Endpoint skip verification key.
  static const skipVerification = 'skip_verification';

  /// Endpoint certificate (PEM) key.
  static const certificate = 'certificate';

  /// Endpoint upstream protocol key.
  static const upstreamProtocol = 'upstream_protocol';

  /// Endpoint upstream fallback protocol key.
  static const upstreamFallbackProtocol = 'upstream_fallback_protocol';

  /// Endpoint anti-DPI toggle key.
  static const antiDpi = 'anti_dpi';

  // Tun keys
  /// TUN included routes list key.
  static const includedRoutes = 'included_routes';

  /// TUN excluded routes list key.
  static const excludedRoutes = 'excluded_routes';

  /// TUN MTU key.
  static const mtuSize = 'mtu_size';

  // Socks keys
  /// SOCKS listener bind address key.
  static const socksAddress = 'address';

  /// SOCKS auth username key.
  static const socksUsername = 'username';

  /// SOCKS auth password key.
  static const socksPassword = 'password';
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// A bidirectional codec for converting between [Configuration] and backend
/// INI-like configuration text.
///
/// This is a convenience wrapper around [ConfigurationEncoder] and
/// [ConfigurationDecoder].
final class ConfigurationCodec extends Codec<Configuration, String> {
  @override
  final ConfigurationEncoder encoder;

  @override
  final ConfigurationDecoder decoder;

  /// Creates a [ConfigurationCodec].
  ///
  /// Both encoder and decoder are stateless and can be reused.
  const ConfigurationCodec({
    this.encoder = const ConfigurationEncoder(),
    this.decoder = const ConfigurationDecoder(),
  });
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// Encodes a [Configuration] into the backend INI-like configuration text.
///
@immutable
final class ConfigurationEncoder extends Converter<Configuration, String> {
  /// Creates an encoder.
  const ConfigurationEncoder();

  @override
  String convert(Configuration config) {
    final IniDocument document = IniDocument();

    final IniSection top = document.section(null);
    top.setString(ConfigurationCodecKeys.logLevel, config.logLevel.value);
    top.setString(ConfigurationCodecKeys.vpnMode, config.vpnMode.value);
    top.setBool(ConfigurationCodecKeys.killSwitchEnabled, config.killSwitchEnabled);
    top.setBool(ConfigurationCodecKeys.postQuantumGroupEnabled, config.postQuantumGroupEnabled);
    top.setStringList(ConfigurationCodecKeys.exclusions, config.endpoint.exclusions);
    top.setStringList(ConfigurationCodecKeys.dnsUpStreams, config.endpoint.dnsUpStreams);

    final IniSection endpoint = document.section(ConfigurationCodecKeys.endpointSection);
    endpoint.setString(ConfigurationCodecKeys.hostname, config.endpoint.hostName);
    endpoint.setStringList(ConfigurationCodecKeys.addresses, _normalizeAddresses(config.endpoint.addresses));
    endpoint.setBool(ConfigurationCodecKeys.hasIpv6, config.endpoint.hasIpv6);
    endpoint.setString(ConfigurationCodecKeys.username, config.endpoint.username);
    endpoint.setString(ConfigurationCodecKeys.password, config.endpoint.password);
    endpoint.setString(ConfigurationCodecKeys.clientRandom, config.endpoint.clientRandom);
    endpoint.setBool(ConfigurationCodecKeys.skipVerification, config.endpoint.skipVerification);
    endpoint.setMultilinePem(ConfigurationCodecKeys.certificate, config.endpoint.certificate);
    endpoint.setString(ConfigurationCodecKeys.upstreamProtocol, config.endpoint.upStreamProtocol.value);
    endpoint.setString(
      ConfigurationCodecKeys.upstreamFallbackProtocol,
      config.endpoint.upStreamFallbackProtocol?.value ?? '',
    );
    endpoint.setBool(ConfigurationCodecKeys.antiDpi, config.endpoint.antiDpi);

    document.section(ConfigurationCodecKeys.listenerSection);

    final IniSection tun = document.section(ConfigurationCodecKeys.tunSection);
    tun.setStringList(ConfigurationCodecKeys.includedRoutes, config.tun.includedRoutes);
    tun.setStringList(ConfigurationCodecKeys.excludedRoutes, config.tun.excludedRoutes);
    tun.setInt(ConfigurationCodecKeys.mtuSize, config.tun.mtuSize);

    // final IniSection socks = document.section(ConfigurationCodecKeys.socksSection);
    // socks.setString(ConfigurationCodecKeys.socksAddress, config.socks.address);
    // socks.setString(ConfigurationCodecKeys.socksUsername, config.socks.username);
    // socks.setString(ConfigurationCodecKeys.socksPassword, config.socks.password);

    return document.toString();
  }

  /// Normalizes endpoint addresses:
  /// - If an address has no explicit port, appends [ IniConst.defaultPort ].
  /// - If an IPv6 literal has no port, wraps it in brackets before appending.
  List<String> _normalizeAddresses(List<String> addresses) => addresses.map(_normalizeAddress).toList(growable: false);

  /// Normalizes a single endpoint address.
  String _normalizeAddress(String address) {
    final bool isIpv6Literal = _looksLikeIpv6Literal(address);
    final String portDivider = isIpv6Literal ? IniConst.ipv6PortDivider : IniConst.ipv4PortDivider;
    final List<String> parts = address.split(portDivider);

    final bool hasPort = parts.length != 1;
    if (hasPort) return address;

    final String host = isIpv6Literal ? '[$address]' : address;
    return '$host:${IniConst.defaultPort}';
  }

  /// Detects an IPv6 literal by the presence of multiple `:` characters.
  bool _looksLikeIpv6Literal(String address) => RegExp(':').allMatches(address).length > 1;
}

/// {@category VPN}
/// {@subCategory Configuration}
///
/// Decodes backend INI-like configuration text into a [Configuration].
@immutable
final class ConfigurationDecoder extends Converter<String, Configuration> {
  /// Creates a decoder.
  const ConfigurationDecoder();

  @override
  Configuration convert(String input) {
    final IniDocument document = IniDocument.parse(input);

    final IniSection top = document.section(null);
    final IniSection endpoint = document.section(ConfigurationCodecKeys.endpointSection);
    final IniSection tun = document.section(ConfigurationCodecKeys.tunSection);
    final IniSection socks = document.section(ConfigurationCodecKeys.socksSection);

    final String logLevelStr = top.getString(ConfigurationCodecKeys.logLevel) ?? ConfigurationLogLevel.debug.value;
    final String vpnModeStr = top.getString(ConfigurationCodecKeys.vpnMode) ?? VpnMode.general.value;

    final bool killSwitchEnabled = top.getBool(ConfigurationCodecKeys.killSwitchEnabled) ?? true;
    final bool postQuantumGroupEnabled = top.getBool(ConfigurationCodecKeys.postQuantumGroupEnabled) ?? false;

    final List<String> exclusions = top.getStringList(ConfigurationCodecKeys.exclusions) ?? const <String>[];
    final List<String> dnsUpStreams = top.getStringList(ConfigurationCodecKeys.dnsUpStreams) ?? const <String>[];

    final String hostName = endpoint.getString(ConfigurationCodecKeys.hostname) ?? '';
    final List<String> addresses = endpoint.getStringList(ConfigurationCodecKeys.addresses) ?? const <String>[];
    final bool hasIpv6 = endpoint.getBool(ConfigurationCodecKeys.hasIpv6) ?? false;

    final String username = endpoint.getString(ConfigurationCodecKeys.username) ?? '';
    final String password = endpoint.getString(ConfigurationCodecKeys.password) ?? '';
    final String clientRandom = endpoint.getString(ConfigurationCodecKeys.clientRandom) ?? '';
    final bool skipVerification = endpoint.getBool(ConfigurationCodecKeys.skipVerification) ?? false;

    final String certificate = _normalizePem(endpoint.getString(ConfigurationCodecKeys.certificate) ?? '');

    final String upstreamProtocolStr =
        endpoint.getString(ConfigurationCodecKeys.upstreamProtocol) ?? UpStreamProtocol.http2.value;
    final String upstreamFallbackProtocolStr =
        endpoint.getString(ConfigurationCodecKeys.upstreamFallbackProtocol) ?? '';
    final bool antiDpi = endpoint.getBool(ConfigurationCodecKeys.antiDpi) ?? false;

    final List<String> includedRoutes =
        tun.getStringList(ConfigurationCodecKeys.includedRoutes) ?? IniConst.defaultTunRoutes;
    final List<String> excludedRoutes = tun.getStringList(ConfigurationCodecKeys.excludedRoutes) ?? const <String>[];
    final int mtuSize = tun.getInt(ConfigurationCodecKeys.mtuSize) ?? IniConst.defaultTunMtu;

    final String socksAddress = socks.getString(ConfigurationCodecKeys.socksAddress) ?? IniConst.defaultSocksAddress;
    final String socksUsername = socks.getString(ConfigurationCodecKeys.socksUsername) ?? '';
    final String socksPassword = socks.getString(ConfigurationCodecKeys.socksPassword) ?? '';

    return Configuration(
      logLevel: _enumByValue(
        ConfigurationLogLevel.values,
        logLevelStr,
        (e) => e.value,
        fallback: ConfigurationLogLevel.debug,
      ),
      killSwitchEnabled: killSwitchEnabled,
      postQuantumGroupEnabled: postQuantumGroupEnabled,
      vpnMode: _enumByValue(VpnMode.values, vpnModeStr, (e) => e.value, fallback: VpnMode.general),
      endpoint: Endpoint(
        hostName: hostName,
        hasIpv6: hasIpv6,
        username: username,
        password: password,
        upStreamProtocol: _enumByValue(
          UpStreamProtocol.values,
          upstreamProtocolStr,
          (e) => e.value,
          fallback: UpStreamProtocol.http2,
        ),
        upStreamFallbackProtocol:
            upstreamFallbackProtocolStr.isEmpty
                ? null
                : _enumByValue(
                  UpStreamProtocol.values,
                  upstreamFallbackProtocolStr,
                  (e) => e?.value ?? '',
                  fallback: UpStreamProtocol.http2,
                ),
        addresses: addresses,
        dnsUpStreams: dnsUpStreams,
        exclusions: exclusions,
        clientRandom: clientRandom,
        skipVerification: skipVerification,
        certificate: certificate,
        antiDpi: antiDpi,
      ),
      tun: Tun(
        includedRoutes: includedRoutes,
        excludedRoutes: excludedRoutes,
        mtuSize: mtuSize,
      ),
      socks: Socks(
        address: socksAddress,
        username: socksUsername,
        password: socksPassword,
      ),
    );
  }

  /// Normalizes a PEM string:
  /// - Converts platform line terminators to `\n`.
  /// - Does not strip meaningful whitespace.
  static String _normalizePem(String value) {
    if (value.isEmpty) return '';
    return value.replaceAll(Platform.lineTerminator, '\n');
  }

  static T _enumByValue<T>(
    List<T> values,
    String raw,
    String Function(T) valueOf, {
    T? fallback,
  }) {
    for (final T v in values) {
      if (valueOf(v) == raw) return v;
    }
    if (fallback != null) return fallback;
    throw FormatException('Unknown enum value "$raw" for $T');
  }
}
