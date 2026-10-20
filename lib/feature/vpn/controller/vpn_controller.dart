import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/feature/vpn/controller/vpn_controller_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_command.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration_sources.dart';

/// Serializes decisions, while repository replies reenter through short handlers.
///
/// Saving, loading and native operations must not occupy the handler queue while waiting:
/// disconnect, exit and native events need to remain processable. The state records pending
/// work and the single repository mutation in flight; completion handlers decide what follows.
final class VpnController extends BaseStateController<VpnControllerState> with SequentialControllerHandler {
  final VpnRepository _repository;
  final VpnConfigurationSources _sources;
  final Future<bool> Function(String serverId) _saveSelection;
  final VoidCallback _notifyOperationError;
  final ValueChanged<bool> _onExitStopped;

  VpnController({
    required this._repository,
    required VpnConfigurationSources sources,
    required this._saveSelection,
    required this._notifyOperationError,
    required this._onExitStopped,
    required VpnState initialState,
  }) : _sources = sources,
       super(
         initialState: VpnControllerState(
           vpnState: initialState,
           selectionRevision: sources.selectionRequestRevision,
           requestId: sources.selectionRequestRevision == 0 ? 0 : 1,
         ),
       );

  String? get _configurationTargetId => state.isRunning
      ? state.currentlyConnectedServerId
      : (_sources.selectedServer?.id ?? state.configuration?.server.id);

  /// Attempts a connection using saved settings, even if the configuration has not changed.
  /// Automatic launch is accepted only before the first VPN or selection intention.
  void connectToServer(String serverId, {bool isFromAutomaticLaunch = false}) => handle(
    () {
      if (state.isExitProcessing || (isFromAutomaticLaunch && (state.requestId != 0 || state.isRunning))) {
        return;
      }
      _acceptConnection(serverId, saveSelection: false);
    },
    errorHandler: _onError,
  );

  /// Saves selection and the automatic launch target, then continues the same connection request.
  void selectAndConnectToServer(String serverId) => handle(
    () {
      if (state.isExitProcessing) {
        return;
      }
      _acceptConnection(serverId, saveSelection: true);
    },
    errorHandler: _onError,
  );

  /// Cancels pending connection preparation and preserves an explicit stop before any later start.
  void disconnect() => handle(
    () {
      _cancelConnection();
      // An explicit stop must execute before a subsequent connection.
      setState(state.copyWith(stopRequired: true));
      _continueOperations();
    },
    errorHandler: _onError,
  );

  /// Receives source notifications directly, independently of Flutter frame scheduling.
  void onSourcesChanged() => handle(
    () {
      final revision = _sources.selectionRequestRevision;
      if (revision != state.selectionRevision) {
        _cancelConnection();
        setState(state.copyWith(selectionRevision: revision));
      }

      setState(state.copyWith(needsSynchronization: true));

      _continueOperations();
    },
    errorHandler: _onError,
  );

  void onNativeStateChanged(VpnState vpnState) => handle(
    () {
      _applyNativeState(vpnState);

      _continueOperations();
    },
    errorHandler: _onError,
  );

  /// Refreshes native status without allowing a delayed response to overwrite newer updates.
  void onResumed() => handle(
    () {
      final revision = state.nativeRevision;

      unawaited(
        Future<VpnState>.sync(_repository.requestState).then(
          (vpnState) => _onStateRequested(vpnState, revision),
          onError: onSourceError,
        ),
      );
    },
    errorHandler: _onError,
  );

  void onSourceError(Object error, StackTrace stackTrace) => handle(
    () => Error.throwWithStackTrace(error, stackTrace),
    errorHandler: _onError,
  );

  /// Blocks new starts and cancels preparation of the previous connection.
  /// Cancelling exit later must not revive that earlier connection intention.
  void prepareExit() => handle(
    () {
      if (state.isExitProcessing) {
        return;
      }

      _cancelConnection();

      setState(state.copyWith(isExitProcessing: true));
    },
    errorHandler: _onError,
  );

  void stopForExit() => handle(
    () {
      if (!state.isExitProcessing || state.exitStopRequested) {
        return;
      }

      setState(state.copyWith(exitStopRequested: true, exitNeedsStop: true));

      _continueOperations();
    },
    errorHandler: _onError,
  );

  /// Cancels exit and any exit stop not yet submitted; previously cancelled connections stay cancelled.
  void cancelExit() => handle(
    () {
      setState(
        state.copyWith(
          isExitProcessing: false,
          exitStopRequested: false,
          exitNeedsStop: false,
        ),
      );
      // Do not restore the connection or synchronization interrupted by exit.
    },
    errorHandler: _onError,
  );

  void _acceptConnection(String serverId, {required bool saveSelection}) {
    setState(
      state.copyWith(
        requestId: state.requestId + 1,
        pendingServerId: ValueData(serverId),
        isSelectionPending: saveSelection,
        connectionNeedsStop: true,
        needsSynchronization: true,
        // selectServer increments this revision synchronously before notifying sources.
        // Record the expected revision so our own save does not cancel its connection request.
        selectionRevision: _sources.selectionRequestRevision + (saveSelection ? 1 : 0),
      ),
    );
    if (saveSelection) {
      _saveServerSelection(serverId, state.requestId);
    }
    _continueOperations();
  }

  /// Saving does not occupy the VPN mutation slot or delay disconnect and exit processing.
  void _saveServerSelection(String serverId, int requestId) => unawaited(
    Future<bool>.sync(() => _saveSelection(serverId)).then(
      (saved) => _onSelectionSaved(requestId, saved),
      onError: (Object error, StackTrace stackTrace) => _onSelectionFailed(requestId, error, stackTrace),
    ),
  );

  void _onSelectionSaved(int requestId, bool saved) => handle(
    () {
      // An old save must not start a request cancelled by another choice, disconnect or exit.
      if (requestId != state.requestId || state.isExitProcessing) {
        return;
      }

      setState(
        state.copyWith(
          isSelectionPending: false,
          pendingServerId: saved ? null : const ValueData(null),
        ),
      );
      _continueOperations();
    },
    errorHandler: _onError,
  );

  void _onSelectionFailed(
    int requestId,
    Object error,
    StackTrace stackTrace,
  ) => handle(
    () {
      if (requestId == state.requestId) {
        _cancelConnection();
      }
      Error.throwWithStackTrace(error, stackTrace);
    },
    errorHandler: _onError,
  );

  void _cancelConnection() => setState(
    state.copyWith(
      requestId: state.requestId + 1,
      pendingServerId: const ValueData(null),
      isSelectionPending: false,
      connectionNeedsStop: false,
    ),
  );

  void _continueOperations() {
    if (state.command != null) {
      return;
    }
    if (state.isExitProcessing) {
      _continueExit();

      return;
    }
    if (state.stopRequired) {
      _stop();

      return;
    }
    if (state.pendingServerId != null) {
      _continueConnection();

      return;
    }
    _synchronizeConfiguration();
  }

  /// Settings sources load independently and may become ready in different orders.
  /// Keep the target pending while loading; the next source notification resumes it without a waiter.
  /// Re-read configuration here because dependencies may also change during native stop.
  void _continueConnection() {
    if (state.isSelectionPending || _sources.loading) {
      return;
    }
    final configuration = _sources.configurationFor(state.pendingServerId);
    if (_sources.hasErrors || configuration == null) {
      setState(state.copyWith(pendingServerId: const ValueData(null)));
      _synchronizeConfiguration();

      return;
    }
    if (state.connectionNeedsStop && state.isRunning) {
      _stop();

      return;
    }
    _start(configuration);
  }

  void _start(VpnConfiguration configuration) {
    final requestId = state.requestId;
    setState(
      state.copyWith(
        command: const ValueData(VpnCommand.start),
        startSubmitted: true,
        vpnState: VpnState.connecting,
        currentlyConnectedServerId: ValueData(configuration.server.id),
        nativeRevision: state.nativeRevision + 1,
        connectionNeedsStop: false,
        needsSynchronization: false,
      ),
    );
    unawaited(
      Future<void>.sync(
        () => _repository.start(
          server: configuration.server,
          routingProfile: configuration.routingProfile,
          excludedRoutes: configuration.excludedRoutes,
          logLevel: configuration.logLevel,
        ),
      ).then(
        (_) => _onStarted(configuration, requestId),
        onError: (Object error, StackTrace stackTrace) => _onConfigurationFailed(
          configuration,
          requestId,
          error,
          stackTrace,
        ),
      ),
    );
  }

  void _onStarted(VpnConfiguration configuration, int requestId) => handle(
    () {
      // A submitted native operation finishes even if a newer intention arrived.
      // Remember its configuration, but clear only the request that actually submitted it.
      setState(
        state.copyWith(
          command: const ValueData(null),
          configuration: ValueData(configuration),
          configurationDeleted: false,
          pendingServerId: requestId == state.requestId ? const ValueData(null) : null,
          needsSynchronization: true,
        ),
      );
      _continueOperations();
    },
    errorHandler: _onError,
  );

  /// Submits a native stop, leaving VPN status unchanged until native confirmation arrives.
  void _stop() {
    setState(state.copyWith(stopRequired: false));
    if (!state.isRunning && !state.stopSubmitted) {
      setState(state.copyWith(connectionNeedsStop: false));
      _continueOperations();

      return;
    }
    final requestId = state.requestId;
    setState(
      state.copyWith(
        command: const ValueData(VpnCommand.stop),
        stopSubmitted: true,
        exitNeedsStop: false,
      ),
    );
    unawaited(
      Future<void>.sync(_repository.stop).then(
        (_) => _onStopped(),
        onError: (Object error, StackTrace stackTrace) => _onStopFailed(requestId, error, stackTrace),
      ),
    );
  }

  void _onStopped() => handle(
    () {
      // The reply permits the next command, but only native state confirms disconnection.
      setState(
        state.copyWith(
          command: const ValueData(null),
          startSubmitted: false,
          connectionNeedsStop: false,
        ),
      );
      _continueOperations();
    },
    errorHandler: _onError,
  );

  /// Applies the latest saved settings through the same lifecycle as connection requests.
  /// Settings changes alone do not start a disconnected VPN; only a known active session is restarted.
  void _synchronizeConfiguration() {
    if (!state.needsSynchronization || _sources.loading || _sources.hasErrors) {
      return;
    }
    if (_sources.servers.isEmpty) {
      _deleteConfiguration();

      return;
    }
    // A stop reply is not disconnection. Settings must not restart the session
    // while its native disconnection is still pending.
    if (state.stopSubmitted && !state.startSubmitted) {
      return;
    }
    final connectedId = state.currentlyConnectedServerId;
    if (state.isRunning && connectedId == null) {
      // A restored native session cannot be identified by the persisted selection.
      return;
    }
    if (state.isRunning && !_sources.servers.any((server) => server.id == connectedId)) {
      setState(state.copyWith(needsSynchronization: false));
      if (!state.stopSubmitted || state.startSubmitted) {
        _stop();
      }

      return;
    }
    final targetId = _configurationTargetId;
    final configuration = _sources.configurationFor(targetId);
    if (configuration == null || configuration == state.configuration) {
      setState(state.copyWith(needsSynchronization: false));

      return;
    }
    if (state.isRunning) {
      setState(
        state.copyWith(pendingServerId: ValueData(targetId), connectionNeedsStop: true),
      );
      _continueConnection();
    } else {
      _updateConfiguration(configuration);
    }
  }

  void _updateConfiguration(VpnConfiguration configuration) {
    final requestId = state.requestId;
    setState(
      state.copyWith(command: const ValueData(VpnCommand.updateConfiguration), needsSynchronization: false),
    );
    unawaited(
      Future<void>.sync(
        () => _repository.updateConfiguration(
          server: configuration.server,
          routingProfile: configuration.routingProfile,
          excludedRoutes: configuration.excludedRoutes,
          logLevel: configuration.logLevel,
        ),
      ).then(
        (_) => _onConfigurationUpdated(configuration),
        onError: (Object error, StackTrace stackTrace) => _onConfigurationFailed(
          configuration,
          requestId,
          error,
          stackTrace,
        ),
      ),
    );
  }

  void _onConfigurationUpdated(VpnConfiguration configuration) => handle(
    () {
      // Changes observed while the operation was in progress must still be compared and applied.
      setState(
        state.copyWith(
          command: const ValueData(null),
          configuration: ValueData(configuration),
          configurationDeleted: false,
          needsSynchronization: true,
        ),
      );
      _continueOperations();
    },
    errorHandler: _onError,
  );

  void _deleteConfiguration() {
    if (state.isRunning && (!state.stopSubmitted || state.startSubmitted)) {
      _stop();

      return;
    }
    if (state.configurationDeleted) {
      setState(state.copyWith(needsSynchronization: false));

      return;
    }
    final requestId = state.requestId;
    setState(
      state.copyWith(command: const ValueData(VpnCommand.deleteConfiguration), needsSynchronization: false),
    );
    unawaited(
      Future<void>.sync(_repository.deleteConfiguration).then(
        (_) => _onConfigurationDeleted(),
        onError: (Object error, StackTrace stackTrace) => _onDeletionFailed(
          requestId,
          error,
          stackTrace,
        ),
      ),
    );
  }

  void _onConfigurationDeleted() => handle(
    () {
      setState(
        state.copyWith(
          command: const ValueData(null),
          configuration: const ValueData(null),
          configurationDeleted: true,
          needsSynchronization: true,
        ),
      );
      _continueOperations();
    },
    errorHandler: _onError,
  );

  void _applyNativeState(VpnState vpnState) {
    var startSubmitted = state.startSubmitted;
    var stopSubmitted = state.stopSubmitted;
    if (vpnState == VpnState.disconnected) {
      // A previous stop may report after the next start has already been submitted.
      if (!stopSubmitted || state.command == VpnCommand.stop) {
        startSubmitted = false;
      }
      stopSubmitted = false;
    } else if (!stopSubmitted || state.command == VpnCommand.stop) {
      // Keep the new start identifiable until the previous stop's event arrives.
      startSubmitted = false;
    }
    setState(
      state.copyWith(
        vpnState: vpnState == VpnState.disconnected && startSubmitted ? state.vpnState : vpnState,
        startSubmitted: startSubmitted,
        stopSubmitted: stopSubmitted,
        currentlyConnectedServerId: vpnState == VpnState.disconnected && !startSubmitted ? const ValueData(null) : null,
        nativeRevision: state.nativeRevision + 1,
        needsSynchronization: true,
      ),
    );
  }

  void _onStateRequested(VpnState vpnState, int revision) => handle(
    () {
      // Ignore an outdated snapshot or disconnected returned while native start is still being processed.
      if (revision != state.nativeRevision || (vpnState == VpnState.disconnected && state.startSubmitted)) {
        return;
      }
      _applyNativeState(vpnState);
      _continueOperations();
    },
    errorHandler: _onError,
  );

  /// Waits for the current mutation, sends the required stop and reports sufficient disconnection.
  /// The scope owns the technical wait and can cancel exit before a delayed stop is submitted.
  void _continueExit() {
    if (!state.exitStopRequested) {
      return;
    }
    if (state.isDisconnectedForExit) {
      setState(state.copyWith(exitStopRequested: false, exitNeedsStop: false));
      _onExitStopped(true);
    } else if (state.exitNeedsStop || !state.stopSubmitted || state.startSubmitted) {
      _stop();
    }
  }

  void _onConfigurationFailed(
    VpnConfiguration configuration,
    int requestId,
    Object error,
    StackTrace stackTrace,
  ) => handle(
    () {
      final targetId = _configurationTargetId;
      // Do not repeat the failed configuration automatically, but retain settings changed during the operation.
      setState(
        state.copyWith(
          needsSynchronization: state.needsSynchronization && _sources.configurationFor(targetId) != configuration,
        ),
      );
      _failCommand(requestId, error, stackTrace);
    },
    errorHandler: _onCommandError,
  );

  void _onDeletionFailed(
    int requestId,
    Object error,
    StackTrace stackTrace,
  ) => handle(
    () {
      setState(state.copyWith(needsSynchronization: state.needsSynchronization && _sources.servers.isNotEmpty));
      _failCommand(requestId, error, stackTrace);
    },
    errorHandler: _onCommandError,
  );

  void _onStopFailed(
    int requestId,
    Object error,
    StackTrace stackTrace,
  ) => handle(
    () => _failCommand(requestId, error, stackTrace),
    errorHandler: _onStopError,
  );

  void _onStopError(Object error, StackTrace stackTrace) {
    _onError(error, stackTrace);
    if (!state.isExitProcessing && (state.stopRequired || state.pendingServerId != null)) {
      _continueOperations();
    }
  }

  Never _failCommand(
    int requestId,
    Object error,
    StackTrace stackTrace,
  ) {
    // Release the mutation slot so failure cannot block later commands.
    setState(state.copyWith(command: const ValueData(null)));
    if (requestId == state.requestId) {
      setState(
        state.copyWith(
          pendingServerId: const ValueData(null),
          isSelectionPending: false,
        ),
      );
    }
    if (state.isExitProcessing && state.exitStopRequested) {
      setState(state.copyWith(exitStopRequested: false, exitNeedsStop: false));
      _onExitStopped(false);
    }
    // A failed reply may still have reached native code. Keep status and submitted flags.
    Error.throwWithStackTrace(error, stackTrace);
  }

  void _onCommandError(Object error, StackTrace stackTrace) {
    _onError(error, stackTrace);
    _continueOperations();
  }

  void _onError(Object error, StackTrace stackTrace) => _notifyOperationError();
}
