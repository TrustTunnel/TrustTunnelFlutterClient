/// {@template tls_fingerprint}
/// TLS ClientHello fingerprint used when connecting to a server.
///
/// This enum is used for persistence/interop where a stable numeric identifier
/// is required (for example, storing the choice in a database or sending it to
/// platform code).
///
/// The numeric [value] must remain stable across app versions.
/// {@endtemplate}
enum TlsFingerprint {
  chrome._(1),
  chromeCanary._(7),
  safari._(2),
  firefox._(3),
  okhttp._(4),
  openssl._(5),
  own._(6);

  /// {@template tls_fingerprint_value}
  /// Stable numeric identifier used for persistence/interop.
  ///
  /// Do not renumber existing values, as that would break stored data.
  /// {@endtemplate}
  final int value;

  /// {@macro tls_fingerprint}
  const TlsFingerprint._(this.value);
}
