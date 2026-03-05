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
          ),
        );

        final servers = await _repository.getAllServers();

        setState(
          ServersState.idle(
            servers: servers,
          ),
        );
      },
      errorHandler: _onError,
      completionHandler: _onCompleted,
    );
  }

  /// Load available products
  void selectServer(String? serverId) {
    handle(
      () async {
        if (serverId == null) {
          return;
        }

        final operatingServers = state.servers;

        setState(
          ServersState.loading(
            servers: operatingServers,
          ),
        );

        await _repository.setSelectedServerId(id: serverId);

        final servers = operatingServers
            .map(
              (e) => e.copyWith(serverData: e.serverData.copyWith(selected: e.id == serverId)),
            )
            .toList();

        setState(
          ServersState.idle(
            servers: servers,
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
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ServersState.idle(
      servers: state.servers,
    ),
  );
}
