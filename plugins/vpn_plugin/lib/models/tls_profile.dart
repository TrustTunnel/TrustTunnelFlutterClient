/// TLS ClientHello profiles supported by the native client.
enum TlsProfile {
  chrome('chrome'),
  chromeCanary('chrome_canary'),
  safari('safari'),
  firefox('firefox'),
  okhttp('okhttp'),
  openssl('openssl'),
  defaultProfile('default');

  /// Value used in the native endpoint configuration.
  final String value;

  const TlsProfile(this.value);
}
