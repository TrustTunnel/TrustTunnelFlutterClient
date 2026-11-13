import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/models/value_data.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_operations_processing_info.dart';

/// Public VPN status and internal operation processing data.
@immutable
final class VpnControllerState {
  /// Native status with connection transitions smoothed for all consumers.
  final VpnState vpnState;

  /// Server ID from a start that this controller submitted, if still tracked.
  final String? appStartedServerId;

  /// Saved server ID used to display and disconnect a VPN started outside this controller.
  final String? restoredServerId;

  /// Blocks new connections until the platform completes or cancels exit.
  final bool isExitProcessing;

  /// Internal work; changes here alone do not notify controller listeners.
  final VpnOperationsProcessingInfo vpnOperationsProcessingInfo;

  const VpnControllerState({
    this.vpnState = VpnState.disconnected,
    this.appStartedServerId,
    this.restoredServerId,
    this.isExitProcessing = false,
    this.vpnOperationsProcessingInfo = const VpnOperationsProcessingInfo(),
  });

  bool get isRunning => vpnState != VpnState.disconnected || vpnOperationsProcessingInfo.startSubmitted;

  /// Server ID for the current session or submitted start, if known.
  String? get activeServerId => appStartedServerId ?? restoredServerId;

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
    appStartedServerId,
    restoredServerId,
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
      'VpnControllerState(vpn: $vpnState, server: $activeServerId, '
      'exit: $isExitProcessing, vpnOperationsProcessingInfo: $vpnOperationsProcessingInfo)';

  /// The controller filters notifications without excluding internal work from state equality.
  bool hasSamePublicState(VpnControllerState other) =>
      vpnState == other.vpnState &&
      appStartedServerId == other.appStartedServerId &&
      restoredServerId == other.restoredServerId &&
      isExitProcessing == other.isExitProcessing;

  VpnControllerState copyWith({
    VpnState? vpnState,
    ValueData<String>? appStartedServerId,
    ValueData<String>? restoredServerId,
    bool? isExitProcessing,
    VpnOperationsProcessingInfo? vpnOperationsProcessingInfo,
  }) => VpnControllerState(
    vpnState: vpnState ?? this.vpnState,
    appStartedServerId: appStartedServerId != null ? appStartedServerId.value : this.appStartedServerId,
    restoredServerId: restoredServerId != null ? restoredServerId.value : this.restoredServerId,
    isExitProcessing: isExitProcessing ?? this.isExitProcessing,
    vpnOperationsProcessingInfo: vpnOperationsProcessingInfo ?? this.vpnOperationsProcessingInfo,
  );
}
