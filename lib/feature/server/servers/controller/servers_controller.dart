import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/data/repository/auto_connect_on_launch_settings_repository.dart';
import 'package:trusttunnel/data/repository/server_repository.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_states.dart';

/// {@template servers_controller}
/// Loads servers and persists the selected server and automatic launch target.
/// {@endtemplate}
final class ServersController extends BaseStateController<ServersState> with SequentialControllerHandler {
  final ServerRepository _repository;
  final AutoConnectOnLaunchSettingsRepository _autoConnectOnLaunchSettingsRepository;

  /// {@macro servers_controller}
  ServersController({
    required this._repository,
    required this._autoConnectOnLaunchSettingsRepository,
    super.initialState = const ServersState.initial(),
  });

  /// Reloads the persisted server list.
  void fetchServers() {
    if (isDisposed) {
      return;
    }

    handle(
      () async {
        setState(
          ServersState.loading(
            servers: state.servers,
            selectionRequestRevision: state.selectionRequestRevision,
            pendingSelections: state.pendingSelections,
          ),
        );

        final servers = await _repository.getAllServers();
        if (isDisposed) {
          return;
        }

        setState(
          ServersState.idle(
            servers: servers,
            selectionRequestRevision: state.selectionRequestRevision,
            pendingSelections: state.pendingSelections,
          ),
        );
      },
      errorHandler: _onError,
    );
  }

  /// Saves selection and the launch target without changing the VPN connection.
  Future<bool> selectServer(String? serverId) {
    if (isDisposed) {
      return Future<bool>.value(false);
    }

    // Notify immediately: repeated and failed choices also cancel older VPN intentions.
    setState(
      state.copyWith(
        selectionRequestRevision: state.selectionRequestRevision + 1,
        pendingSelections: state.pendingSelections + 1,
      ),
    );

    // The handler reports errors through state, so track the result explicitly.
    bool isSucceeded = false;

    return handle(
      () async {
        final operatingServers = state.servers;

        setState(
          ServersState.loading(
            servers: operatingServers,
            selectionRequestRevision: state.selectionRequestRevision,
            pendingSelections: state.pendingSelections,
          ),
        );

        await _repository.setSelectedServerId(id: serverId);
        if (isDisposed) {
          return;
        }

        final servers = operatingServers
            .map(
              (server) => server.copyWith(serverData: server.serverData.copyWith(selected: server.id == serverId)),
            )
            .toList();

        // Keep the confirmed DB choice visible if saving the launch target fails.
        setState(state.copyWith(servers: servers));
        if (isDisposed) {
          return;
        }

        await _autoConnectOnLaunchSettingsRepository.setLastServerId(serverId);
        if (isDisposed) {
          return;
        }

        setState(
          ServersState.idle(
            servers: state.servers,
            selectionRequestRevision: state.selectionRequestRevision,
            pendingSelections: state.pendingSelections,
          ),
        );
        isSucceeded = true;
      },
      errorHandler: _onError,
      completionHandler: _onSelectionCompleted,
    ).then((_) => isSucceeded);
  }

  PresentationException _parseException(
    Object? exception,
  ) => ExceptionUtils.toPresentationException(
    exception: exception,
  );

  Future<void> _onError(Object? error, StackTrace _) async {
    final presentationException = _parseException(error);

    setState(
      ServersState.exception(
        exception: presentationException,
        servers: state.servers,
        selectionRequestRevision: state.selectionRequestRevision,
        pendingSelections: state.pendingSelections,
      ),
    );
  }

  void _onSelectionCompleted() => setState(
    state.copyWith(pendingSelections: state.pendingSelections - 1),
  );
}
