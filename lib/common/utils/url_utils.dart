import 'package:url_launcher/url_launcher.dart';

abstract class UrlUtils {
  static Uri githubTrustTunnelTeam = Uri(scheme: 'https', host: 'github.com', path: 'TrustTunnel');

  static Future<void> openWebPage(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
