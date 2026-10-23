import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/error/exception_utils.dart';
import 'package:trusttunnel/common/error/model/presentation_code_exception.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/utils/server_name_utils.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/repository/server_repository.dart';
import 'package:trusttunnel/feature/server/servers/controller/servers_states.dart';

/// {@template products_controller}
/// Controller for managing products and purchase operations.
/// {@endtemplate}
final class ServersController extends BaseStateController<ServersState> with SequentialControllerHandler {
  final ServerRepository _repository;

  /// {@macro products_controller}
  ServersController({
    required this._repository,
    super.initialState = const ServersState.initial(),
  });

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

  void duplicateServer({
    required String serverId,
    required String Function(String name, int number) numberedName,
    ValueChanged<Server>? onDuplicated,
    VoidCallback? onError,
  }) => handle(
    () async {
      setState(ServersState.loading(servers: state.servers));

      final currentServers = await _repository.getAllServers();
      final originalServer = currentServers.firstWhere(
        (server) => server.id == serverId,
        orElse: () => throw const PresentationNotFoundException(),
      );

      final duplicateName = ServerNameUtils.findAvailable(
        baseName: originalServer.serverData.name,
        otherNames: currentServers.map((server) => server.serverData.name),
        preferredName: numberedName(originalServer.serverData.name.trim(), 0),
        numberedName: numberedName,
      );

      final duplicate = await _repository.duplicateServer(
        serverId: serverId,
        name: duplicateName,
      );
      final servers = await _repository.getAllServers();
      setState(ServersState.idle(servers: servers));
      if (!isDisposed) onDuplicated?.call(duplicate);
    },
    errorHandler: (error, stackTrace) {
      _onError(error, stackTrace);
      onError?.call();
    },
    completionHandler: _onCompleted,
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
      ),
    );
  }

  Future<void> _onCompleted() async => setState(
    ServersState.idle(
      servers: state.servers,
    ),
  );
}
