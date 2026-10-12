import 'package:flutter/foundation.dart' show Listenable;
import 'package:trusttunnel/data/model/vpn_state.dart';

mixin VpnController implements Listenable {
  abstract final VpnState state;

  /// Server targeted by the last VPN connection attempt.
  /// Does not indicate that the connection succeeded.
  abstract final String? lastConnectionServerId;

  /// Server of the current session or submitted start; null for an unknown native session.
  /// Use together with [state] to determine whether it is connected.
  abstract final String? currentlyConnectedServerId;

  /// A native start was submitted but has not yet reported an active state.
  abstract final bool hasPendingStart;

  /// A confirmed exit blocks new starts until exit is cancelled on failure.
  abstract final bool isExitProcessing;

  /// Notifies the UI when a VPN operation or exit request fails.
  abstract final Listenable operationErrorListenable;

  /// Attempts a connection regardless of whether the saved configuration changed.
  /// Launch requests yield to manual commands received before or during loading.
  Future<void> connectToServer(String serverId, {bool isFromAutomaticLaunch = false});

  /// Saves selection and the launch target before attempting the connection.
  Future<void> selectAndConnectToServer(String serverId);

  /// Cancels pending connection intentions and stops any submitted or active session.
  Future<void> disconnect();

  /// Applies the latest saved configuration through the VPN lifecycle queue.
  /// Does not start a disconnected VPN merely because selection or settings changed.
  Future<void> synchronizeConfiguration();
}
