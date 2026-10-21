/// {@template tls_authentication_type}
/// TLS authentication mode used to authenticate the client to the server.
///
/// This enum is used for persistence/interop where a stable numeric identifier
/// is required (for example, storing the choice in a database or sending it to
/// platform code).
///
/// The numeric [value] must remain stable across app versions.
/// {@endtemplate}
/// Do not renumber existing values.
enum TlsAuthenticationType {
  /// TLS authentication type using client random.
  clientRandom._(1),

  /// TLS authentication type using client random authentication key.
  clientRandomAuthKey._(2);

  /// {@template tls_authentication_type_value}
  /// Stable numeric identifier used for persistence/interop.
  ///
  /// Do not renumber existing values, as that would break stored data.
  /// {@endtemplate}
  final int value;

  const TlsAuthenticationType._(this.value);
}
