import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class ServersScopeController {
  abstract final List<Server> servers;
  abstract final Server? selectedServer;
  abstract final PresentationException? error;
  abstract final bool loading;

  abstract final void Function({
    required String serverId,
    required String Function(String name) copyName,
    required String Function(String name, int number) numberedName,
    ValueChanged<Server>? onDuplicated,
    VoidCallback? onError,
  })
  duplicateServer;

  abstract final void Function() fetchServers;
  abstract final void Function(String? serverId) pickServer;
}
