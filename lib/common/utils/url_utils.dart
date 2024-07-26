import 'package:url_launcher/url_launcher.dart';

abstract class UrlUtils {
  static Uri githubAdguardTeam = Uri(scheme: 'https', host: 'github.com', path: 'AdguardTeam');

  static Future<void> openWebPage(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
