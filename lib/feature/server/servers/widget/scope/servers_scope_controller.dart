import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class ServersScopeController implements Listenable {
  abstract final List<Server> servers;
  abstract final Server? selectedServer;
  abstract final PresentationException? error;
  abstract final bool loading;

  abstract final void Function() fetchServers;

  /// Saves selection only; callers cancel obsolete VPN preparation before changing it.
  /// [shouldReportError] suppresses UI feedback for a cancelled connection's save.
  void selectServer(
    String? serverId, {
    ValueChanged<bool>? onSelected,
    ValueGetter<bool>? shouldReportError,
  });
}
