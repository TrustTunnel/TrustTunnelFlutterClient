import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/error_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_error.dart';
import 'package:trusttunnel/data/repository/server_repository.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_states.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class ServersController extends BaseStateController<ServersState> with SequentialControllerHandler {
  final ServerRepository _repository;

  /// {@macro products_controller}
  ServersController({
    required ServerRepository repository,
    super.initialState = const ServersState.initial(),
  }) : _repository = repository;

  /// Make a purchase for the given product ID
  void fetchServers() {
    handle(
      () async {
        setState(
          ServersState.loading(
            servers: state.servers,
            selectedServer: state.selectedServer,
          ),
        );

        final servers = await _repository.getAllServers();

        setState(
          ServersState.idle(
            servers: servers,
            selectedServer: servers.where((s) => s.selected).firstOrNull?.id,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  /// Load available products
  void selectServer(int? serverId) {
    handle(
      () async {
        if (serverId == null) {
          setState(
            ServersState.idle(
              servers: state.servers,
              selectedServer: serverId,
            ),
          );

          return;
        }

        final operatingServers = state.servers;

        setState(
          ServersState.loading(
            servers: operatingServers,
            selectedServer: state.selectedServer,
          ),
        );

        await _repository.setSelectedServerId(id: serverId);

        setState(
          ServersState.idle(
            servers: operatingServers,
            selectedServer: operatingServers.where((s) => s.id == serverId).firstOrNull?.id,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  PresentationError _parseException(Object? exception) => ErrorUtils.toPresentationError(exception: exception);

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      ServersState.exception(
        exception: presentationException,
        servers: state.servers,
        selectedServer: state.selectedServer,
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ServersState.idle(
      selectedServer: state.selectedServer,
      servers: state.servers,
    ),
  );
}
