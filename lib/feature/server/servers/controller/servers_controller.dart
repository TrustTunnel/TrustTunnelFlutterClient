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
      if (isDisposed) {
        return;
      }

      setState(
        ServersState.idle(
          servers: servers,
          pendingSelections: state.pendingSelections,
        ),
      );
    },
    errorHandler: _onError,
  );

  /// Saves selection and the launch target without changing the VPN connection.
  void selectServer(
    String? serverId, {
    ValueChanged<bool>? onSelected,
    ValueGetter<bool>? shouldReportError,
  }) {
    // Register queued selections synchronously; handle's disposal check cannot protect this state write.
    if (isDisposed) {
      return;
    }

    setState(state.copyWith(pendingSelections: state.pendingSelections + 1));

    handle(
      () async {
        final operatingServers = state.servers;

        setState(
          ServersState.loading(
            servers: operatingServers,
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
            pendingSelections: state.pendingSelections,
          ),
        );
        _completeSelection(saved: true, onSelected: onSelected);
      },
      errorHandler: (error, stackTrace) {
        try {
          if (shouldReportError?.call() ?? true) {
            _onError(error, stackTrace);
          } else {
            // The observer logs cancelled preparation errors; do not publish them to the tray or UI.
            setState(
              ServersState.idle(
                servers: state.servers,
                pendingSelections: state.pendingSelections,
              ),
            );
          }
        } finally {
          _completeSelection(saved: false, onSelected: onSelected);
        }
      },
    );
  }

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

  void _completeSelection({required bool saved, ValueChanged<bool>? onSelected}) {
    if (isDisposed) {
      return;
    }

    setState(state.copyWith(pendingSelections: state.pendingSelections - 1));

    try {
      onSelected?.call(saved);
    } on Object catch (error, stackTrace) {
      // A consumer callback failure must not complete or report the save a second time.
      super.onError(error, stackTrace);
    }
  }
}
