import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class ServersScopeController implements Listenable {
  abstract final List<Server> servers;
  abstract final Server? selectedServer;
  abstract final PresentationException? error;
  abstract final bool loading;

  /// Starts at zero and increments synchronously for every choice, including repeated or failed choices.
  /// Observers may invalidate pending work without depending on a persisted change.
  abstract final int selectionRequestRevision;

  abstract final void Function() fetchServers;

  /// Saves selection and the launch target without starting or switching VPN.
  void selectServer(String? serverId, {ValueChanged<bool>? onSelected});
}
