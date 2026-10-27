import 'package:flutter/foundation.dart';

/// Preparation of one connection; its submitted native operation is tracked separately.
enum VpnConnectionStage {
  /// Persisting the selection and automatic launch target before preparing the connection.
  savingSelection,

  /// A previous stop operation completed while selection is still saving.
  /// Remember it so finishing the save does not submit the same stop again.
  savingSelectionAfterStop,

  /// Waiting for valid saved settings; an active session still needs stopping.
  preparing,

  /// No further stop is needed; start waits for saved settings and the native operation slot.
  readyToStart,
}

/// A pending connection command, separate from any native operation already submitted.
/// Settings synchronization uses the same preparation to restart a known active session.
@immutable
final class VpnUserCommand {
  final int requestId;
  final String serverId;
  final VpnConnectionStage stage;

  const VpnUserCommand({
    required this.requestId,
    required this.serverId,
    required this.stage,
  });

  bool get isSavingSelection =>
      stage == VpnConnectionStage.savingSelection || stage == VpnConnectionStage.savingSelectionAfterStop;

  @override
  int get hashCode => Object.hashAll([
    requestId,
    serverId,
    stage,
  ]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VpnUserCommand && requestId == other.requestId && serverId == other.serverId && stage == other.stage;

  @override
  String toString() => 'VpnUserCommand(id: $requestId, server: $serverId, stage: $stage)';

  VpnUserCommand onSelectionSaved() => copyWith(
    stage: switch (stage) {
      VpnConnectionStage.savingSelection => VpnConnectionStage.preparing,
      VpnConnectionStage.savingSelectionAfterStop => VpnConnectionStage.readyToStart,
      _ => stage,
    },
  );

  VpnUserCommand onStopCompleted() => copyWith(
    stage: switch (stage) {
      VpnConnectionStage.savingSelection => VpnConnectionStage.savingSelectionAfterStop,
      VpnConnectionStage.preparing => VpnConnectionStage.readyToStart,
      _ => stage,
    },
  );

  VpnUserCommand copyWith({VpnConnectionStage? stage}) => VpnUserCommand(
    requestId: requestId,
    serverId: serverId,
    stage: stage ?? this.stage,
  );
}
