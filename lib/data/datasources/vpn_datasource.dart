import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

/// {@template vpn_data_source}
/// Low-level abstraction over the VPN platform/backend.
///
/// `VpnDataSource` represents the closest Dart-side interface to the platform
/// implementation. It exposes:
/// - continuous streams of VPN state and logs,
/// - imperative commands to start and stop the VPN,
/// - a one-shot state request.
///
/// This interface is intentionally minimal and backend-oriented. Higher-level
/// orchestration (restarts, state caching, UI concerns) is expected to be
/// handled by repositories or controllers above this layer.
/// {@endtemplate}
abstract class VpnDataSource {
  /// {@template vpn_data_source_state_stream}
  /// Stream of VPN state updates.
  ///
  /// The stream emits new [VpnState] values whenever the backend reports a state
  /// change. The exact frequency and timing depend on the platform implementation.
  ///
  /// Consumers should assume this stream is:
  /// - single-subscription,
  /// - long-lived for the duration of an active VPN session.
  /// {@endtemplate}
  Stream<VpnState> get vpnState;

  /// {@template vpn_data_source_logs_stream}
  /// Stream of VPN log events.
  ///
  /// Each emitted [VpnLog] represents a single log entry produced by the backend.
  /// Ordering is preserved as provided by the platform.
  /// {@endtemplate}
  Stream<VpnLog> get vpnLogs;

  /// {@template vpn_data_source_start}
  /// Starts the VPN session using the provided configuration inputs.
  ///
  /// Implementations are responsible for:
  /// - translating domain models into backend-specific configuration,
  /// - initiating the VPN engine/service on the platform,
  /// - making state and log streams available.
  ///
  /// This method completes when the start request has been issued to the backend,
  /// not necessarily when the VPN reaches a connected state.
  /// {@endtemplate}
  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  });

  /// {@template vpn_data_source_stop}
  /// Stops the VPN session.
  ///
  /// Implementations should terminate the backend VPN engine and release
  /// associated resources. After completion, [vpnState] is expected to
  /// eventually emit [VpnState.disconnected].
  /// {@endtemplate}
  Future<void> stop();

  /// {@template vpn_data_source_request_state}
  /// Requests the current VPN state from the backend.
  ///
  /// Unlike [vpnState], this method performs a one-time request and returns
  /// the most recent state known to the platform.
  /// {@endtemplate}
  Future<VpnState> requestState();
}
