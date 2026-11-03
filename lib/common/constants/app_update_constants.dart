abstract final class AppUpdateConstants {
  static const String repositoryName = 'TrustTunnel/TrustTunnelFlutterClient';
  static const String releasesUrl = 'https://api.github.com/repos/$repositoryName/releases';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration checkInterval = Duration(hours: 6);
  static const String installerBundleName = 'TrustTunnel-windows.exe';
}
