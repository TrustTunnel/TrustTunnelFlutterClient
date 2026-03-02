import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

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
  Uri? get link => _link;

  @override
  Future<Uri?> getInitialLink() => !kIsWeb ? appLinks.getInitialLink() : Future.value();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
