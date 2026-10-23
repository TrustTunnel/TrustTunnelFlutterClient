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
  /// [onSelected] runs after both the selection and launch target have been saved.
  /// [onError] completes the caller's pending work; the error is also published by this scope.
  void selectServer(
    String? serverId, {
    VoidCallback? onSelected,
    VoidCallback? onError,
  });
}
