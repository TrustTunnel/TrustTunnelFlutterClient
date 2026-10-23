import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/controller/concurrency/sequential_controller_handler.dart';
import 'package:trusttunnel/common/controller/controller/state_controller.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/data/repository/vpn_repository.dart';
import 'package:trusttunnel/feature/vpn/controller/vpn_controller_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration_sources.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_native_operation.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_operations_processing_info.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_user_command.dart';

/// Coordinates user commands, saved settings and native VPN updates.
///
/// About operations:
/// - `handle` queues short state transitions; `_handle*` methods continue a specific scenario.
/// - `_on*` methods receive operation results and errors.
/// - `vpnOperationsProcessingInfo` stores internal coordination data.
/// - `pendingUserCommand` is a replaceable connection intention; a submitted `nativeOperation`
/// reserves the repository until its reply arrives.
///
/// About state transitions:
/// - `_submit*` methods start native calls inside a handler without awaiting their replies.
/// - `nativeStateRequest` reads status once on resume, supplementing native events.
///
/// Both update `vpnState`: transitions are smoothed, connection outcomes come from native state.
final class VpnController extends BaseStateController<VpnControllerState> with SequentialControllerHandler {
  final VpnRepository _repository;
  final VpnConfigurationSources _sources;
  final void Function(
    String, {
    VoidCallback? onSelected,
    VoidCallback? onError,
  })
  _saveSelection;
  final VoidCallback _notifyOperationError;
  final ValueChanged<bool> _onExitStopped;

  VpnController({
    required this._repository,
    required this._sources,
    required this._saveSelection,
    required this._notifyOperationError,
    required this._onExitStopped,
    required VpnState initialState,
  }) : super(initialState: VpnControllerState(vpnState: initialState));

  VpnOperationsProcessingInfo get _vpnOperationsProcessingInfo => state.vpnOperationsProcessingInfo;

  bool get shouldShowExitDialog => state.shouldShowExitDialog;

  bool get isDisconnectedForExit => state.isDisconnectedForExit;

  bool get _isRunning => state.isRunning;

  String? get _configurationTargetId => _isRunning
      ? state.currentlyConnectedServerId
      : (_sources.selectedServer?.id ?? _vpnOperationsProcessingInfo.configuration?.server.id);

  @override
  bool shouldNotifyListeners(VpnControllerState previousState, VpnControllerState nextState) =>
      !previousState.hasSamePublicState(nextState);

  /// Explicit connections also retry an unchanged configuration.
  void connectToServer(String serverId, {bool isFromAutomaticLaunch = false}) => handle(
    () {
      final hasConnectionActivity = _vpnOperationsProcessingInfo.requestId != 0 || _isRunning;
      final shouldSkipAutomaticLaunch = isFromAutomaticLaunch && hasConnectionActivity;
      if (state.isExitProcessing || shouldSkipAutomaticLaunch) {
        return;
      }

      _acceptConnectionUserCommand(serverId, saveSelection: false);
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void selectAndConnectToServer(String serverId) => handle(
    () {
      if (!state.isExitProcessing) {
        _acceptConnectionUserCommand(serverId, saveSelection: true);
        _handlePendingWork();
      }
    },
    errorHandler: _onHandlerError,
    completionHandler: _savePendingServerSelection,
  );

  void disconnect() => handle(
    () {
      _cancelPendingUserCommand();

      // Preserve an explicit stop even if another connection is requested next.
      _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(stopRequired: true));
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void stopForExit() => handle(
    () {
      if (_vpnOperationsProcessingInfo.exitStage != VpnExitStage.idle) {
        return;
      }

      _beginExit();

      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(
          exitStage: VpnExitStage.stopRequested,
        ),
      );
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void cancelExit() => handle(
    () {
      _updateState(
        state.copyWith(
          isExitProcessing: false,
          vpnOperationsProcessingInfo: _vpnOperationsProcessingInfo.copyWith(exitStage: VpnExitStage.idle),
        ),
      );
      // Previously cancelled connections stay cancelled.
    },
    errorHandler: _onHandlerError,
  );

  /// Non-desktop exit cancels preparation without stopping the system VPN.
  void onAppExiting() => handle(_beginExit, errorHandler: _onHandlerError);

  void onSourcesChanged() => handle(
    () {
      _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(needsSynchronization: true));
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void onNativeStateChanged(VpnState nativeState) => handle(
    () {
      _handleNativeStateUpdate(nativeState);
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void onResumed() => handle(
    () {
      final nativeStateRequest = Future<VpnState>.sync(_repository.requestState);
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(nativeStateRequest: ValueData(nativeStateRequest)),
      );

      unawaited(
        nativeStateRequest.then(
          (nativeState) => _onNativeStateRequestCompleted(
            nativeStateRequest: nativeStateRequest,
            nativeState: nativeState,
          ),
          onError: (Object error, StackTrace stackTrace) => _onNativeStateRequestFailed(
            nativeStateRequest: nativeStateRequest,
            error: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    },
    errorHandler: _onHandlerError,
  );

  void onSourceError(Object error, StackTrace stackTrace) => handle(
    () => _reportError(error: error, stackTrace: stackTrace),
    errorHandler: _onHandlerError,
  );

  void _handlePendingWork() {
    if (_vpnOperationsProcessingInfo.nativeOperation != null) {
      return;
    }

    // Exit and explicit stop take priority over connection and settings changes.
    if (state.isExitProcessing) {
      _handleExit();
    } else if (_vpnOperationsProcessingInfo.stopRequired) {
      _submitStop();
    } else if (_vpnOperationsProcessingInfo.pendingUserCommand != null) {
      _handleConnectionUserCommand();
    } else {
      _handleConfigurationSynchronization();
    }
  }

  void _acceptConnectionUserCommand(String serverId, {required bool saveSelection}) {
    final requestId = _vpnOperationsProcessingInfo.requestId + 1;

    _updateVpnOperationsProcessingInfo(
      _vpnOperationsProcessingInfo.copyWith(
        requestId: requestId,
        pendingUserCommand: ValueData(
          VpnUserCommand(
            requestId: requestId,
            serverId: serverId,
            stage: saveSelection ? VpnConnectionStage.savingSelection : VpnConnectionStage.preparing,
          ),
        ),
        needsSynchronization: true,
      ),
    );
  }

  bool _isCurrentUserCommand(int requestId) {
    final canAcceptResult = !isDisposed && !state.isExitProcessing;

    return canAcceptResult && _vpnOperationsProcessingInfo.pendingUserCommand?.requestId == requestId;
  }

  /// Cancels preparation; a native operation already submitted must still finish.
  void _cancelPendingUserCommand() => _updateVpnOperationsProcessingInfo(
    _vpnOperationsProcessingInfo.copyWith(
      requestId: _vpnOperationsProcessingInfo.requestId + 1,
      pendingUserCommand: const ValueData(null),
    ),
  );

  /// Runs after the selection handler yields, before the queue can replace its command.
  /// Selection registration can notify sources; those notifications must enqueue behind this handler.
  void _savePendingServerSelection() {
    final command = _vpnOperationsProcessingInfo.pendingUserCommand;
    if (state.isExitProcessing || command == null || !command.isSavingSelection) {
      return;
    }

    final requestId = command.requestId;
    try {
      _saveSelection(
        command.serverId,
        onSelected: () => _onSelectionSaved(requestId),
        onError: () => _onSelectionSaveRejected(requestId),
      );
    } catch (error, stackTrace) {
      _onSelectionFailed(
        requestId: requestId,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onSelectionSaved(int requestId) => handle(
    () {
      if (!_isCurrentUserCommand(requestId)) {
        return;
      }

      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(
          pendingUserCommand: ValueData(_vpnOperationsProcessingInfo.pendingUserCommand!.onSelectionSaved()),
        ),
      );
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void _onSelectionSaveRejected(int requestId) => handle(
    () {
      if (!_isCurrentUserCommand(requestId)) {
        return;
      }

      // ServersController already published the storage error.
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(pendingUserCommand: const ValueData(null)),
      );
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void _onSelectionFailed({
    required int requestId,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () {
      final isCurrent = _isCurrentUserCommand(requestId);
      if (isCurrent) {
        _cancelPendingUserCommand();
      }

      // A cancelled preparation is logged without reopening the window.
      _reportError(error: error, stackTrace: stackTrace, notify: isCurrent);
    },
    errorHandler: _onHandlerError,
  );

  void _handleConnectionUserCommand() {
    final request = _vpnOperationsProcessingInfo.pendingUserCommand!;
    if (request.isSavingSelection || _sources.loading) {
      return;
    }
    // Read again after stop: settings may have changed while it was in progress.
    final configuration = _sources.configurationFor(request.serverId);
    if (_sources.hasErrors || configuration == null) {
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(pendingUserCommand: const ValueData(null)),
      );
      _handleConfigurationSynchronization();

      return;
    }
    final needsStopBeforeStart = request.stage == VpnConnectionStage.preparing && _isRunning;
    if (needsStopBeforeStart) {
      _submitStop();

      return;
    }
    _submitStart(configuration);
  }

  void _handleConfigurationSynchronization() {
    final shouldSkipSynchronization = !_vpnOperationsProcessingInfo.needsSynchronization || _sources.loading;
    if (shouldSkipSynchronization || _sources.hasErrors) {
      return;
    }

    if (_sources.servers.isEmpty) {
      _submitConfigurationDeletion();

      return;
    }

    final isWaitingForStop = _vpnOperationsProcessingInfo.stopSubmitted && !_vpnOperationsProcessingInfo.startSubmitted;
    if (isWaitingForStop) {
      // Settings must not restart a session whose stop is still awaiting confirmation.
      return;
    }

    final connectedId = state.currentlyConnectedServerId;
    if (_isRunning && connectedId == null) {
      // Persisted selection cannot identify a session restored from native code.
      return;
    }

    final isConnectedServerRemoved = _isRunning && !_sources.servers.any((server) => server.id == connectedId);
    if (isConnectedServerRemoved) {
      _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(needsSynchronization: false));
      _submitStop();

      return;
    }

    final configuration = _sources.configurationFor(_configurationTargetId);
    if (configuration == null || configuration == _vpnOperationsProcessingInfo.configuration) {
      _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(needsSynchronization: false));

      return;
    }

    if (_isRunning) {
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(
          pendingUserCommand: ValueData(
            VpnUserCommand(
              requestId: _vpnOperationsProcessingInfo.requestId,
              serverId: configuration.server.id,
              stage: VpnConnectionStage.preparing,
            ),
          ),
        ),
      );

      _handleConnectionUserCommand();
    } else {
      _submitConfigurationUpdate(configuration);
    }
  }

  void _beginExit() {
    if (!state.isExitProcessing) {
      _cancelPendingUserCommand();
      _updateState(state.copyWith(isExitProcessing: true));
    }
  }

  void _handleExit() {
    if (_vpnOperationsProcessingInfo.exitStage == VpnExitStage.idle) {
      return;
    }

    if (isDisconnectedForExit) {
      // New connections stay blocked until the platform completes or cancels exit.
      _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(exitStage: VpnExitStage.idle));
      _onExitStopped(true);

      return;
    }

    final isWaitingForStop = _vpnOperationsProcessingInfo.stopSubmitted && !_vpnOperationsProcessingInfo.startSubmitted;
    if (_vpnOperationsProcessingInfo.exitStage == VpnExitStage.stopRequested || !isWaitingForStop) {
      _submitStop();
    }
  }

  /// Called inside a handler: reserves and starts one repository call without awaiting its reply.
  /// Completion and failure handlers enqueue the result; native state confirms the session status.
  void _submitNativeOperation({
    required VpnNativeOperation nativeOperation,
    required AsyncCallback execute,
    required VoidCallback onCompleted,
    VpnConfiguration? configuration,
  }) {
    final requestId = _vpnOperationsProcessingInfo.requestId;
    _updateVpnOperationsProcessingInfo(
      _vpnOperationsProcessingInfo.copyWith(nativeOperation: ValueData(nativeOperation)),
    );

    // Future.sync sends synchronous call failures through the same path as asynchronous errors.
    unawaited(
      Future<void>.sync(execute).then(
        (_) => _onNativeOperationCompleted(onCompleted: onCompleted),
        onError: (Object error, StackTrace stackTrace) => _onNativeOperationFailed(
          nativeOperation: nativeOperation,
          requestId: requestId,
          configuration: configuration,
          error: error,
          stackTrace: stackTrace,
        ),
      ),
    );
  }

  Future<void> _onNativeOperationCompleted({required VoidCallback onCompleted}) => handle(
    () {
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(nativeOperation: const ValueData(null)),
      );

      onCompleted();
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  Future<void> _onNativeOperationFailed({
    required VpnNativeOperation nativeOperation,
    required int requestId,
    VpnConfiguration? configuration,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () {
      VpnOperationsProcessingInfo vpnOperationsProcessingInfo = _vpnOperationsProcessingInfo.copyWith(
        nativeOperation: const ValueData(null),
      );

      if (configuration != null) {
        // Do not immediately retry the same failure; retain settings changed during it.
        final hasNewConfiguration =
            vpnOperationsProcessingInfo.needsSynchronization &&
            _sources.configurationFor(_configurationTargetId) != configuration;
        vpnOperationsProcessingInfo = vpnOperationsProcessingInfo.copyWith(
          needsSynchronization: hasNewConfiguration,
        );
      } else if (nativeOperation == VpnNativeOperation.deleteConfiguration) {
        vpnOperationsProcessingInfo = vpnOperationsProcessingInfo.copyWith(
          needsSynchronization: vpnOperationsProcessingInfo.needsSynchronization && _sources.servers.isNotEmpty,
        );
      }
      if (requestId == vpnOperationsProcessingInfo.requestId) {
        vpnOperationsProcessingInfo = vpnOperationsProcessingInfo.copyWith(pendingUserCommand: const ValueData(null));
      }
      final exitStopFailed = state.isExitProcessing && vpnOperationsProcessingInfo.exitStage != VpnExitStage.idle;
      if (exitStopFailed) {
        vpnOperationsProcessingInfo = vpnOperationsProcessingInfo.copyWith(exitStage: VpnExitStage.idle);
      }

      // A failing reply may still have reached native code; keep the submitted flags.
      _updateVpnOperationsProcessingInfo(vpnOperationsProcessingInfo);
      if (exitStopFailed) {
        _onExitStopped(false);
      }

      _reportError(error: error, stackTrace: stackTrace);
      if (nativeOperation == VpnNativeOperation.stop) {
        // Retry a failed stop only for a newer explicit request, never for background synchronization.
        final hasPendingRequest =
            _vpnOperationsProcessingInfo.stopRequired || _vpnOperationsProcessingInfo.pendingUserCommand != null;
        if (state.isExitProcessing || !hasPendingRequest) {
          return;
        }
      }

      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void _submitStart(VpnConfiguration configuration) {
    final requestId = _vpnOperationsProcessingInfo.requestId;
    _updateState(
      state.copyWith(
        vpnState: VpnState.connecting,
        currentlyConnectedServerId: ValueData(configuration.server.id),
        vpnOperationsProcessingInfo: _vpnOperationsProcessingInfo.copyWith(
          pendingUserCommand: ValueData(
            _vpnOperationsProcessingInfo.pendingUserCommand?.copyWith(stage: VpnConnectionStage.readyToStart),
          ),
          startSubmitted: true,
          nativeStateRequest: const ValueData(null),
          needsSynchronization: false,
        ),
      ),
    );

    _submitNativeOperation(
      nativeOperation: VpnNativeOperation.start,
      execute: () => _repository.start(
        server: configuration.server,
        routingProfile: configuration.routingProfile,
        excludedRoutes: configuration.excludedRoutes,
        logLevel: configuration.logLevel,
      ),
      configuration: configuration,
      onCompleted: () => _onNativeStartOperationCompleted(configuration, requestId),
    );
  }

  void _onNativeStartOperationCompleted(VpnConfiguration configuration, int requestId) {
    // Remember submitted work even if its connection request has since been replaced.
    _onNativeConfigurationOperationCompleted(configuration);

    if (_vpnOperationsProcessingInfo.pendingUserCommand?.requestId == requestId) {
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(pendingUserCommand: const ValueData(null)),
      );
    }
  }

  void _submitStop() {
    _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(stopRequired: false));

    final isAlreadyStopped = !_isRunning && !_vpnOperationsProcessingInfo.stopSubmitted;
    if (isAlreadyStopped) {
      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(
          pendingUserCommand: ValueData(_vpnOperationsProcessingInfo.pendingUserCommand?.onStopCompleted()),
        ),
      );
      _handlePendingWork();

      return;
    }

    _updateVpnOperationsProcessingInfo(
      _vpnOperationsProcessingInfo.copyWith(
        stopSubmitted: true,
        exitStage: _vpnOperationsProcessingInfo.exitStage == VpnExitStage.stopRequested
            ? VpnExitStage.waitingForDisconnection
            : _vpnOperationsProcessingInfo.exitStage,
      ),
    );

    _submitNativeOperation(
      nativeOperation: VpnNativeOperation.stop,
      execute: () => _repository.stop(),
      onCompleted: _onNativeStopOperationCompleted,
    );
  }

  void _onNativeStopOperationCompleted() {
    // Release the next start; only a native event confirms disconnection.
    _updateVpnOperationsProcessingInfo(
      _vpnOperationsProcessingInfo.copyWith(
        startSubmitted: false,
        pendingUserCommand: ValueData(_vpnOperationsProcessingInfo.pendingUserCommand?.onStopCompleted()),
      ),
    );
  }

  void _submitConfigurationUpdate(VpnConfiguration configuration) {
    _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(needsSynchronization: false));
    _submitNativeOperation(
      nativeOperation: VpnNativeOperation.updateConfiguration,
      execute: () => _repository.updateConfiguration(
        server: configuration.server,
        routingProfile: configuration.routingProfile,
        excludedRoutes: configuration.excludedRoutes,
        logLevel: configuration.logLevel,
      ),
      configuration: configuration,
      onCompleted: () => _onNativeConfigurationOperationCompleted(configuration),
    );
  }

  void _onNativeConfigurationOperationCompleted(VpnConfiguration configuration) {
    // Compare again to include settings changed during the native operation.
    _updateVpnOperationsProcessingInfo(
      _vpnOperationsProcessingInfo.copyWith(
        configuration: ValueData(configuration),
        configurationDeleted: false,
        needsSynchronization: true,
      ),
    );
  }

  void _submitConfigurationDeletion() {
    final isWaitingForStop = _vpnOperationsProcessingInfo.stopSubmitted && !_vpnOperationsProcessingInfo.startSubmitted;
    if (_isRunning && !isWaitingForStop) {
      _submitStop();

      return;
    }

    if (_vpnOperationsProcessingInfo.configurationDeleted) {
      _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(needsSynchronization: false));

      return;
    }

    _updateVpnOperationsProcessingInfo(_vpnOperationsProcessingInfo.copyWith(needsSynchronization: false));
    _submitNativeOperation(
      nativeOperation: VpnNativeOperation.deleteConfiguration,
      execute: () => _repository.deleteConfiguration(),
      onCompleted: () => _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(
          configuration: const ValueData(null),
          configurationDeleted: true,
          needsSynchronization: true,
        ),
      ),
    );
  }

  /// Settles submitted start/stop tracking and updates the shared, smoothed VPN status.
  void _handleNativeStateUpdate(VpnState nativeState) {
    bool startSubmitted = _vpnOperationsProcessingInfo.startSubmitted;
    bool stopSubmitted = _vpnOperationsProcessingInfo.stopSubmitted;

    final isStopOperationPending = _vpnOperationsProcessingInfo.nativeOperation == VpnNativeOperation.stop;
    if (nativeState == VpnState.disconnected) {
      final completesPreviousStop = stopSubmitted && !isStopOperationPending;
      if (!completesPreviousStop) {
        startSubmitted = false;
      }
      stopSubmitted = false;
    } else if (!stopSubmitted || isStopOperationPending) {
      startSubmitted = false;
    }

    // A delayed previous stop must not overwrite the newer start's status.
    final shouldPreserveStartState = nativeState == VpnState.disconnected && startSubmitted;
    final vpnState = shouldPreserveStartState ? state.vpnState : nativeState;
    _updateState(
      state.copyWith(
        vpnState: vpnState,
        currentlyConnectedServerId: vpnState == VpnState.disconnected ? const ValueData(null) : null,
        vpnOperationsProcessingInfo: _vpnOperationsProcessingInfo.copyWith(
          startSubmitted: startSubmitted,
          stopSubmitted: stopSubmitted,
          nativeStateRequest: const ValueData(null),
          needsSynchronization: true,
        ),
      ),
    );
  }

  /// Applies a one-shot status reply on resume only if no newer update has superseded it.
  void _onNativeStateRequestCompleted({
    required Future<VpnState> nativeStateRequest,
    required VpnState nativeState,
  }) => handle(
    () {
      if (!identical(_vpnOperationsProcessingInfo.nativeStateRequest, nativeStateRequest)) {
        // A newer native event, start or status request has superseded this snapshot.
        return;
      }

      _updateVpnOperationsProcessingInfo(
        _vpnOperationsProcessingInfo.copyWith(nativeStateRequest: const ValueData(null)),
      );

      final shouldIgnoreSnapshot =
          (nativeState == VpnState.disconnected) && _vpnOperationsProcessingInfo.startSubmitted;
      if (shouldIgnoreSnapshot) {
        // A queued start may not yet be reflected in the native snapshot.
        return;
      }

      _handleNativeStateUpdate(nativeState);
      _handlePendingWork();
    },
    errorHandler: _onHandlerError,
  );

  void _onNativeStateRequestFailed({
    required Future<VpnState> nativeStateRequest,
    required Object error,
    required StackTrace stackTrace,
  }) => handle(
    () {
      final isCurrent = identical(_vpnOperationsProcessingInfo.nativeStateRequest, nativeStateRequest);
      if (isCurrent) {
        _updateVpnOperationsProcessingInfo(
          _vpnOperationsProcessingInfo.copyWith(nativeStateRequest: const ValueData(null)),
        );
      }

      // Obsolete reads cannot affect the current session or its UI feedback.
      _reportError(
        error: error,
        stackTrace: stackTrace,
        notify: isCurrent,
      );
    },
    errorHandler: _onHandlerError,
  );

  void _updateState(VpnControllerState nextState) {
    if (nextState != state) {
      setState(nextState);
    }
  }

  void _updateVpnOperationsProcessingInfo(VpnOperationsProcessingInfo vpnOperationsProcessingInfo) =>
      _updateState(state.copyWith(vpnOperationsProcessingInfo: vpnOperationsProcessingInfo));

  void _reportError({
    required Object error,
    required StackTrace stackTrace,
    bool notify = true,
  }) {
    super.onError(error, stackTrace);

    if (notify) {
      _notifyOperationError();
    }
  }

  // Unexpected handler errors are already logged by SequentialControllerHandler.
  void _onHandlerError(Object error, StackTrace stackTrace) => _notifyOperationError();
}
