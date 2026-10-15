import 'dart:ui';

import 'package:trusttunnel/data/model/server_data.dart';

abstract class ServerSharingScopeController {
  abstract final bool loading;

  abstract final void Function({
    required ServerData server,
    VoidCallback? onCopied,
    VoidCallback? onError,
  })
  copyLink;

  abstract final void Function({
    required ServerData server,
    required Rect sharePositionOrigin,
    VoidCallback? onError,
  })
  share;
}
