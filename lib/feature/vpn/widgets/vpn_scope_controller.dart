import 'package:flutter/foundation.dart' show Listenable;
import 'package:trusttunnel/data/model/vpn_state.dart';

/// Synchronous commands and the prepared VPN status exposed to consumers.
abstract interface class VpnScopeController implements Listenable {
  /// Prepared VPN status, including the interval before native code acknowledges a submitted start.
  VpnState get state;

  /// Server of the current session or submitted start; null for an unknown native session.
  /// Use together with [state] to determine whether it is connected.
  String? get currentlyConnectedServerId;

  /// A confirmed exit blocks new starts until exit is cancelled on failure or timeout.
  bool get isExitProcessing;

  /// Attempts a connection regardless of whether the saved configuration changed.
  /// Launch requests yield to manual commands received before or during loading.
  void connectToServer(String serverId, {bool isFromAutomaticLaunch = false});

  /// Saves selection and the launch target before attempting the connection.
  void selectAndConnectToServer(String serverId);

  /// Cancels pending connection intentions and stops any submitted or active session.
  ///
  /// Native state confirms disconnection; this synchronous call only submits the intention.
  void disconnect();
}
