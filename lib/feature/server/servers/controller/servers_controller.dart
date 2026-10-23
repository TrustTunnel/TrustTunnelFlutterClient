import 'package:flutter/foundation.dart';
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
  void fetchServers() => handle(
    () async {
      setState(
        ServersState.loading(
          servers: state.servers,
          pendingSelections: state.pendingSelections,
        ),
      );

      final servers = await _repository.getAllServers();
      setState(state.copyWith(servers: servers));
    },
    errorHandler: _onError,
    completionHandler: _onCompleted,
  );

  /// Saves selection and the launch target without changing the VPN connection.
  void selectServer(
    String? serverId, {
    VoidCallback? onSelected,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(state.copyWith(pendingSelections: state.pendingSelections + 1));

      final operatingServers = state.servers;

      setState(
        ServersState.loading(
          servers: operatingServers,
          pendingSelections: state.pendingSelections,
        ),
      );

      await _repository.setSelectedServerId(id: serverId);

      final servers = operatingServers
          .map(
            (server) => server.copyWith(serverData: server.serverData.copyWith(selected: server.id == serverId)),
          )
          .toList();

      // Keep the confirmed DB choice visible if saving the launch target fails.
      setState(state.copyWith(servers: servers));

      await _autoConnectOnLaunchSettingsRepository.setLastServerId(serverId);
    },
    errorHandler: _onError,
    completionHandler: () {
      _onCompleted(completedSelections: 1);

      final callback = state.error == null ? onSelected : onError;
      callback?.call();
    },
  );

  PresentationException _parseException(
    Object? exception,
  ) => ExceptionUtils.toPresentationException(
    exception: exception,
  );

  void _onError(Object? error, StackTrace _) {
    final presentationException = _parseException(error);

    setState(
      ServersState.exception(
        exception: presentationException,
        servers: state.servers,
        pendingSelections: state.pendingSelections,
      ),
    );
  }

  void _onCompleted({int completedSelections = 0}) {
    final pendingSelections = state.pendingSelections - completedSelections;

    setState(
      state.error == null
          ? ServersState.idle(servers: state.servers, pendingSelections: pendingSelections)
          : state.copyWith(pendingSelections: pendingSelections),
    );
  }
}
