import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class ServersScopeController {
  abstract final List<Server> servers;
  abstract final Server? selectedServer;
  abstract final PresentationException? error;
  abstract final bool loading;

  abstract final void Function() fetchServers;
  abstract final void Function(String? serverId) pickServer;
}
