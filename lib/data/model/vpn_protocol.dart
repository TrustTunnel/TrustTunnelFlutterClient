/// {@template vpn_protocol}
/// VPN transport protocol used to connect to the endpoint.
///
/// This enum is used for persistence/interop where a stable numeric identifier
/// is required (for example, storing the choice in a database or sending it to
/// platform code).
///
/// The numeric [value] must remain stable across app versions.
/// {@endtemplate}
enum VpnProtocol {
  /// QUIC-based transport (typically maps to HTTP/3-like behavior).
  quic._(1),

  /// HTTP/2-based transport.
  http2._(2);

  /// {@template vpn_protocol_value}
  /// Stable numeric identifier used for persistence/interop.
  ///
  /// Do not renumber existing values, as that would break stored data.
  /// {@endtemplate}
  final int value;

  /// {@macro vpn_protocol}
  const VpnProtocol._(this.value);
}
