import 'package:vpn_plugin/models/configuration_log_level.dart';
import 'package:vpn_plugin/models/endpoint.dart';
import 'package:vpn_plugin/models/socks.dart';
import 'package:vpn_plugin/models/tun.dart';
import 'package:vpn_plugin/models/vpn_mode.dart';

/// {@template configuration}
/// A complete VPN client configuration.
///
/// This is the top-level model that groups all settings required by the VPN
/// backend. It combines:
/// - global client settings (e.g. logging level, VPN routing mode),
/// - endpoint connection settings ([Endpoint]),
/// - traffic capture/listener settings ([Tun] and [Socks]),
/// - optional security and transport toggles.
///
/// The model is intentionally lightweight and does not validate values beyond
/// what is enforced by constructors/`assert`s in nested models. Consumers are
/// expected to provide values that make sense for the backend.
/// {@endtemplate}
final class Configuration {
  /// {@template configuration_log_level_field}
  /// Verbosity of the VPN client logs.
  ///
  /// This value is typically forwarded to the backend as a string (for example
  /// `debug`, `info`, `trace`) and affects the amount of diagnostic output.
  /// {@endtemplate}
  final ConfigurationLogLevel logLevel;

  /// {@template configuration_vpn_mode_field}
  /// Routing mode that defines what traffic is sent through the VPN endpoint.
  ///
  /// See [VpnMode] for the exact meaning of available modes.
  /// {@endtemplate}
  final VpnMode vpnMode;

  /// {@template configuration_endpoint_field}
  /// Remote VPN endpoint settings.
  ///
  /// This contains server addresses, authentication credentials and transport
  /// options used to establish the connection.
  /// {@endtemplate}
  final Endpoint endpoint;

  /// {@template configuration_tun_field}
  /// TUN listener configuration.
  ///
  /// When the backend runs in TUN mode, it creates a virtual network interface
  /// and routes matching traffic into the VPN tunnel.
  /// {@endtemplate}
  final Tun tun;

  /// {@template configuration_socks_field}
  /// SOCKS listener configuration.
  ///
  /// Some backends can expose a local SOCKS proxy instead of (or in addition to)
  /// a TUN device. The exact behavior depends on the backend.
  /// {@endtemplate}
  final Socks socks;

  /// {@template configuration_killswitch_field}
  /// Whether the kill switch is enabled.
  ///
  /// When enabled, traffic that is expected to go through the VPN endpoint
  /// should not be allowed to "fall back" to direct connections if the VPN link
  /// is down. This is commonly used to avoid accidental traffic leaks.
  /// {@endtemplate}
  final bool killSwitchEnabled;

  /// {@template configuration_pq_field}
  /// Whether post-quantum key exchange support is enabled (if supported).
  ///
  /// When enabled, the backend may choose a post-quantum group for TLS key
  /// exchange. Availability and exact behavior depend on the backend build.
  /// {@endtemplate}
  final bool postQuantumGroupEnabled;

  /// {@macro configuration}
  ///
  /// [vpnMode], [endpoint], [tun] and [socks] are required because they define
  /// the primary routing behavior and traffic listener configuration.
  ///
  /// Defaults are chosen to be safe and useful for development:
  /// - [logLevel] defaults to [ConfigurationLogLevel.debug].
  /// - [killSwitchEnabled] defaults to `true`.
  /// - [postQuantumGroupEnabled] defaults to `false`.
  Configuration({
    this.logLevel = ConfigurationLogLevel.debug,
    this.killSwitchEnabled = true,
    this.postQuantumGroupEnabled = true,
    required this.vpnMode,
    required this.endpoint,
    required this.tun,
    required this.socks,
  });

  @override
  String toString() =>
      'Configuration(logLevel: $logLevel, vpnMode: $vpnMode, endpoint: $endpoint, tun: $tun, socks: $socks, killSwitchEnabled: $killSwitchEnabled, postQuantumGroupEnabled: $postQuantumGroupEnabled)';

  @override
  bool operator ==(covariant Configuration other) {
    if (identical(this, other)) return true;

    return other.logLevel == logLevel &&
        other.vpnMode == vpnMode &&
        other.endpoint == endpoint &&
        other.tun == tun &&
        other.socks == socks &&
        other.killSwitchEnabled == killSwitchEnabled &&
        other.postQuantumGroupEnabled == postQuantumGroupEnabled;
  }

  @override
  int get hashCode => Object.hashAll([
    logLevel.hashCode,
    vpnMode.hashCode,
    endpoint.hashCode,
    tun.hashCode,
    socks.hashCode,
    killSwitchEnabled.hashCode,
    postQuantumGroupEnabled.hashCode,
  ]);
}
