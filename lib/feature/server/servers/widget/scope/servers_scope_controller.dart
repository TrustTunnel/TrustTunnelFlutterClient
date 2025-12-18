import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/model/server.dart';

abstract class ServersScopeController {
  abstract final List<Server> servers;
  abstract final Server? selectedServer;
  abstract final PresentationError? error;
  abstract final bool loading;

  abstract final void Function() fetchServers;
  abstract final void Function(int? serverId) pickServer;
}
