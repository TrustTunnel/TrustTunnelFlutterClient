import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_configuration.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_native_operation.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_user_command.dart';

enum VpnExitStage {
  /// No stop is pending. Connections may still be blocked while the platform finishes exiting.
  idle,

  /// Exit was confirmed; submit stop once the current repository call finishes.
  stopRequested,

  /// Stop was submitted; wait for both its reply and native disconnection.
  waitingForDisconnection,
}

/// Internal data for preparing user commands and tracking submitted native operations.
@immutable
final class VpnOperationsProcessingInfo {
  /// Zero allows automatic launch; every connection request or cancellation advances it.
  final int requestId;

  /// Connection intention waiting for preparation or a free native operation slot.
  final VpnUserCommand? pendingUserCommand;

  /// An explicit disconnect must execute before a later connection.
  final bool stopRequired;

  /// Native events settle submitted starts independently of repository replies.
  final bool startSubmitted;

  /// A stop was submitted, but native disconnection is not yet confirmed.
  final bool stopSubmitted;

  /// Recheck saved settings once the current native operation finishes.
  final bool needsSynchronization;

  /// Distinguishes successful deletion from an initially unknown configuration.
  final bool configurationDeleted;

  final VpnExitStage exitStage;

  /// The single repository mutation awaiting its reply; native events do not release this slot.
  final VpnNativeOperation? nativeOperation;

  /// Last configuration successfully handed to native code, regardless of connection outcome.
  final VpnConfiguration? configuration;

  /// One-shot status read on resume; newer native events or starts invalidate its result.
  final Future<VpnState>? nativeStateRequest;

  const VpnOperationsProcessingInfo({
    this.requestId = 0,
    this.pendingUserCommand,
    this.stopRequired = false,
    this.startSubmitted = false,
    this.stopSubmitted = false,
    this.needsSynchronization = true,
    this.configurationDeleted = false,
    this.exitStage = VpnExitStage.idle,
    this.nativeOperation,
    this.configuration,
    this.nativeStateRequest,
  });

  @override
  int get hashCode => Object.hashAll([
    requestId,
    pendingUserCommand,
    stopRequired,
    startSubmitted,
    stopSubmitted,
    needsSynchronization,
    configurationDeleted,
    exitStage,
    nativeOperation,
    configuration,
    nativeStateRequest,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VpnOperationsProcessingInfo &&
          requestId == other.requestId &&
          pendingUserCommand == other.pendingUserCommand &&
          stopRequired == other.stopRequired &&
          startSubmitted == other.startSubmitted &&
          stopSubmitted == other.stopSubmitted &&
          needsSynchronization == other.needsSynchronization &&
          configurationDeleted == other.configurationDeleted &&
          exitStage == other.exitStage &&
          nativeOperation == other.nativeOperation &&
          configuration == other.configuration &&
          identical(nativeStateRequest, other.nativeStateRequest);

  @override
  String toString() =>
      'VpnOperationsProcessingInfo(request: $requestId, pending: $pendingUserCommand, nativeOperation: $nativeOperation, '
      'stopRequired: $stopRequired, start: $startSubmitted, stop: $stopSubmitted, '
      'sync: $needsSynchronization, exit: $exitStage, configured: ${configuration != null}, '
      'deleted: $configurationDeleted, refreshing: ${nativeStateRequest != null})';

  VpnOperationsProcessingInfo copyWith({
    int? requestId,
    ValueData<VpnUserCommand>? pendingUserCommand,
    bool? stopRequired,
    bool? startSubmitted,
    bool? stopSubmitted,
    bool? needsSynchronization,
    bool? configurationDeleted,
    VpnExitStage? exitStage,
    ValueData<VpnNativeOperation>? nativeOperation,
    ValueData<VpnConfiguration>? configuration,
    ValueData<Future<VpnState>>? nativeStateRequest,
  }) => VpnOperationsProcessingInfo(
    requestId: requestId ?? this.requestId,
    pendingUserCommand: pendingUserCommand != null ? pendingUserCommand.value : this.pendingUserCommand,
    stopRequired: stopRequired ?? this.stopRequired,
    startSubmitted: startSubmitted ?? this.startSubmitted,
    stopSubmitted: stopSubmitted ?? this.stopSubmitted,
    needsSynchronization: needsSynchronization ?? this.needsSynchronization,
    configurationDeleted: configurationDeleted ?? this.configurationDeleted,
    exitStage: exitStage ?? this.exitStage,
    nativeOperation: nativeOperation != null ? nativeOperation.value : this.nativeOperation,
    configuration: configuration != null ? configuration.value : this.configuration,
    nativeStateRequest: nativeStateRequest != null ? nativeStateRequest.value : this.nativeStateRequest,
  );
}
