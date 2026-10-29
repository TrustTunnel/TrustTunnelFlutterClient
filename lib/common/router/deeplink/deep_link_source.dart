import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';

abstract class DeepLinkSource with ChangeNotifier {
  Uri? get link;

  Future<Uri?> getInitialLink();
}

class AppLinksSource extends DeepLinkSource {
  final AppLinks appLinks;

  AppLinksSource(this.appLinks) {
    _subscription = appLinks.uriLinkStream.listen((link) {
      _link = link;
      notifyListeners();
    });
  }
  late StreamSubscription<Uri> _subscription;

  Uri? _link;

  @override
  Uri? get link => _parseLink(_link);

  @override
  Future<Uri?> getInitialLink() async => _parseLink(await appLinks.getInitialLink());

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Uri? _parseLink(Uri? link) {
    if (link == null || !link.hasQuery || link.scheme != AppConstants.deepLinkScheme) {
      return null;
    }

    return Uri(
      scheme: link.scheme,
      host: '',
      query: link.query,
    );
  }
}
