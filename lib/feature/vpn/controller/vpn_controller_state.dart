import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_command.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration.dart';

@immutable
final class VpnControllerState {
  /// Native VPN status with the submitted-start and delayed-stop corrections applied.
  /// Consumers use this single status instead of interpreting command flags themselves.
  final VpnState vpnState;

  /// Server of the current session or submitted start; null for an unknown native session.
  /// Use together with [vpnState] to determine whether it is connected.
  final String? currentlyConnectedServerId;

  /// A confirmed exit blocks new starts until exit is cancelled on failure or timeout.
  final bool isExitProcessing;

  /// The scope is waiting for the controller's stop result before replying to Flutter.
  /// The associated Completer and timeout belong to the exit mixin, not this state.
  final bool exitStopRequested;

  /// Exit still needs to submit a stop after the current repository operation finishes.
  /// Cancelling exit clears this separately from a stop that has already been sent.
  final bool exitNeedsStop;

  /// Identifies the most recent connection intention or its cancellation.
  /// Zero means no intention has been registered, so automatic launch may still proceed.
  ///
  /// Example:
  /// 1. The user clicks "Connect to A". Request #1 starts waiting for settings or selection saving.
  /// 2. The user clicks "Connect to B". Request #2 replaces the pending target.
  /// 3. Saving for request #1 finishes, but its ID no longer matches and cannot start A.
  /// 4. Request #2 continues once its own selection and settings are ready.
  ///
  /// Comparing by server ID is not enough: selecting A twice must also cancel the older request.
  final int requestId;

  /// Target waiting for selection saving, source loading or a repository operation to finish.
  /// Cleared when connection work completes or the intention is cancelled.
  final String? pendingServerId;

  /// The current request must finish saving selection and the automatic launch target before starting.
  /// An older save may still finish, but its request ID prevents it from continuing this connection.
  final bool isSelectionPending;

  /// The pending connection must stop the previous session before submitting its start.
  /// Cleared after the stop reply so resuming the request does not send the same stop again.
  final bool connectionNeedsStop;

  /// An explicit disconnect still needs processing, even if a newer connection is already pending.
  /// This preserves the order of "disconnect, then connect" while another operation is running.
  final bool stopRequired;

  /// The repository mutation currently awaiting its reply; null leaves the mutation slot available.
  /// Short handlers remain free to accept cancellation, exit and native events in the meantime.
  final VpnCommand? command;

  /// A start has been sent, but native status alone does not yet settle its outcome.
  /// It also identifies the new start while a previous stop's disconnected event is still pending.
  /// A failed repository reply can still have reached native code, so it does not clear this flag.
  final bool startSubmitted;

  /// A stop has been sent, but native disconnection has not yet been confirmed.
  /// Completing stop() only releases the repository mutation slot; it does not confirm disconnection.
  final bool stopSubmitted;

  /// Last configuration successfully handed to native code by start or updateConfiguration.
  /// Kept as one snapshot so later synchronization compares all settings together.
  final VpnConfiguration? configuration;

  /// An empty server list has already led to successful native configuration deletion.
  ///
  /// Synchronization runs for server, settings and VPN status changes, so remembering this avoids
  /// repeating the same deletion. A null [configuration] alone could also mean nothing was applied yet.
  final bool configurationDeleted;

  /// Saved settings need another comparison with the applied configuration.
  /// Changes received during an operation stay pending until its reply releases the mutation slot.
  final bool needsSynchronization;

  /// Tracks state updates so a delayed requestState() result cannot overwrite newer VPN state.
  /// Submitting a start also advances it to protect the prepared connecting status.
  final int nativeRevision;

  /// Last observed choice request, including repeated or failed choices without a persisted change.
  /// The expected revision of our own save is recorded before its synchronous notification arrives.
  final int selectionRevision;

  const VpnControllerState({
    this.vpnState = VpnState.disconnected,
    this.currentlyConnectedServerId,
    this.isExitProcessing = false,
    this.exitStopRequested = false,
    this.exitNeedsStop = false,
    this.requestId = 0,
    this.pendingServerId,
    this.isSelectionPending = false,
    this.connectionNeedsStop = false,
    this.stopRequired = false,
    this.command,
    this.startSubmitted = false,
    this.stopSubmitted = false,
    this.configuration,
    this.configurationDeleted = false,
    this.needsSynchronization = true,
    this.nativeRevision = 0,
    this.selectionRevision = 0,
  });

  bool get isRunning => vpnState != VpnState.disconnected || startSubmitted;

  /// Exit requires both native disconnection and completion of any submitted repository mutation.
  bool get isDisconnectedForExit => !isRunning && !stopSubmitted && command == null;

  bool get shouldShowExitDialog => startSubmitted || vpnState == VpnState.connected || vpnState == VpnState.connecting;

  @override
  String toString() =>
      'VpnControllerState(vpn: $vpnState, server: $currentlyConnectedServerId, '
      'request: $requestId, pending: $pendingServerId, saving: $isSelectionPending, '
      'command: $command, start: $startSubmitted, stop: $stopSubmitted, '
      'stopRequired: $stopRequired, connectionNeedsStop: $connectionNeedsStop, '
      'exit: $isExitProcessing, exitStop: $exitStopRequested, exitNeedsStop: $exitNeedsStop, sync: $needsSynchronization, '
      'configured: ${configuration != null}, deleted: $configurationDeleted, '
      'nativeRevision: $nativeRevision, selectionRevision: $selectionRevision)';

  VpnControllerState copyWith({
    VpnState? vpnState,
    ValueData<String>? currentlyConnectedServerId,
    bool? isExitProcessing,
    bool? exitStopRequested,
    bool? exitNeedsStop,
    int? requestId,
    ValueData<String>? pendingServerId,
    bool? isSelectionPending,
    bool? connectionNeedsStop,
    bool? stopRequired,
    ValueData<VpnCommand>? command,
    bool? startSubmitted,
    bool? stopSubmitted,
    ValueData<VpnConfiguration>? configuration,
    bool? configurationDeleted,
    bool? needsSynchronization,
    int? nativeRevision,
    int? selectionRevision,
  }) => VpnControllerState(
    vpnState: vpnState ?? this.vpnState,
    currentlyConnectedServerId: currentlyConnectedServerId != null
        ? currentlyConnectedServerId.value
        : this.currentlyConnectedServerId,
    isExitProcessing: isExitProcessing ?? this.isExitProcessing,
    exitStopRequested: exitStopRequested ?? this.exitStopRequested,
    exitNeedsStop: exitNeedsStop ?? this.exitNeedsStop,
    requestId: requestId ?? this.requestId,
    pendingServerId: pendingServerId != null ? pendingServerId.value : this.pendingServerId,
    isSelectionPending: isSelectionPending ?? this.isSelectionPending,
    connectionNeedsStop: connectionNeedsStop ?? this.connectionNeedsStop,
    stopRequired: stopRequired ?? this.stopRequired,
    command: command != null ? command.value : this.command,
    startSubmitted: startSubmitted ?? this.startSubmitted,
    stopSubmitted: stopSubmitted ?? this.stopSubmitted,
    configuration: configuration != null ? configuration.value : this.configuration,
    configurationDeleted: configurationDeleted ?? this.configurationDeleted,
    needsSynchronization: needsSynchronization ?? this.needsSynchronization,
    nativeRevision: nativeRevision ?? this.nativeRevision,
    selectionRevision: selectionRevision ?? this.selectionRevision,
  );
}
