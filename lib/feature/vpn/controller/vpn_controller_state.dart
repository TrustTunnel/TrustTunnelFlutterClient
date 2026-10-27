import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_operations_processing_info.dart';

/// Public VPN status and internal operation processing data.
@immutable
final class VpnControllerState {
  /// Native status with connection transitions smoothed for all consumers.
  final VpnState vpnState;

  /// Server of the current session or submitted start; null for an unknown native session.
  final String? currentlyConnectedServerId;

  /// Blocks new connections until the platform completes or cancels exit.
  final bool isExitProcessing;

  /// Internal work; changes here alone do not notify controller listeners.
  final VpnOperationsProcessingInfo vpnOperationsProcessingInfo;

  const VpnControllerState({
    this.vpnState = VpnState.disconnected,
    this.currentlyConnectedServerId,
    this.isExitProcessing = false,
    this.vpnOperationsProcessingInfo = const VpnOperationsProcessingInfo(),
  });

  bool get isRunning => vpnState != VpnState.disconnected || vpnOperationsProcessingInfo.startSubmitted;

  /// A native operation reply alone does not confirm native disconnection.
  bool get isDisconnectedForExit {
    final isDisconnectionConfirmed = !isRunning && !vpnOperationsProcessingInfo.stopSubmitted;

    return isDisconnectionConfirmed && vpnOperationsProcessingInfo.nativeOperation == null;
  }

  bool get shouldShowExitDialog {
    final isConnectingOrConnected = vpnState == VpnState.connected || vpnState == VpnState.connecting;

    return vpnOperationsProcessingInfo.startSubmitted || isConnectingOrConnected;
  }

  @override
  int get hashCode => Object.hashAll([
    vpnState,
    currentlyConnectedServerId,
    isExitProcessing,
    vpnOperationsProcessingInfo,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VpnControllerState &&
          hasSamePublicState(other) &&
          vpnOperationsProcessingInfo == other.vpnOperationsProcessingInfo;

  @override
  String toString() =>
      'VpnControllerState(vpn: $vpnState, server: $currentlyConnectedServerId, '
      'exit: $isExitProcessing, vpnOperationsProcessingInfo: $vpnOperationsProcessingInfo)';

  /// The controller filters notifications without excluding internal work from state equality.
  bool hasSamePublicState(VpnControllerState other) =>
      vpnState == other.vpnState &&
      currentlyConnectedServerId == other.currentlyConnectedServerId &&
      isExitProcessing == other.isExitProcessing;

  VpnControllerState copyWith({
    VpnState? vpnState,
    ValueData<String>? currentlyConnectedServerId,
    bool? isExitProcessing,
    VpnOperationsProcessingInfo? vpnOperationsProcessingInfo,
  }) => VpnControllerState(
    vpnState: vpnState ?? this.vpnState,
    currentlyConnectedServerId: currentlyConnectedServerId != null
        ? currentlyConnectedServerId.value
        : this.currentlyConnectedServerId,
    isExitProcessing: isExitProcessing ?? this.isExitProcessing,
    vpnOperationsProcessingInfo: vpnOperationsProcessingInfo ?? this.vpnOperationsProcessingInfo,
  );
}
