/// {@template routing_mode}
/// Routing policy mode used by routing profiles.
///
/// This enum is stored as a stable numeric identifier via [value], for example
/// in a local database. Do not change existing numeric values.
/// {@endtemplate}
enum RoutingMode {
  /// Traffic matching the associated rule set should bypass the VPN.
  bypass._(1),

  /// Traffic matching the associated rule set should be routed via VPN.
  vpn._(2);

  /// {@template routing_mode_value}
  /// Stable numeric identifier used for persistence/interop.
  /// {@endtemplate}
  final int value;

  /// {@macro routing_mode}
  const RoutingMode._(this.value);
}
