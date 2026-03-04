import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:vpn_plugin/domain/configuration_encoder.dart';
import 'package:vpn_plugin/domain/query_log_encoder.dart';
import 'package:vpn_plugin/models/configuration.dart';
import 'package:vpn_plugin/models/query_log_row.dart';
import 'package:vpn_plugin/platform_api.g.dart';

/// {@template vpn_plugin}
/// A plugin that provides VPN functionality across multiple platforms.
///
/// Defines the interface for managing VPN connections, monitoring connection
/// state changes, and accessing VPN traffic logs.
/// {@endtemplate}
abstract class VpnPlugin {
  /// {@template vpn_plugin_start}
  /// Starts the VPN connection with the specified configuration.
  ///
  /// The connection process is asynchronous. To monitor the actual connection
  /// state, observe the [states] stream.
  ///
  /// Throws a [PlatformException] if the VPN service fails to start.
  /// {@endtemplate}
  Future<void> start({required String serverName, required Configuration configuration});

  /// {@template vpn_plugin_stop}
  /// Stops the active VPN connection.
  ///
  /// To confirm the connection has fully terminated, observe the [states] stream
  /// for the [VpnManagerState.disconnected] state.
  ///
  /// Throws a [PlatformException] if the VPN service cannot be stopped.
  /// {@endtemplate}
  Future<void> stop();

  /// {@template vpn_plugin_get_current_state}
  /// Retrieves the current state of the VPN connection.
  ///
  /// For continuous updates on state changes, use the [states] stream instead.
  ///
  /// Throws a [PlatformException] if the state cannot be retrieved.
  /// {@endtemplate}
  Future<VpnManagerState> getCurrentState();

  /// {@template vpn_plugin_update_configuration}
  /// Updates the VPN configuration for an existing VPN profile on iOS.
  ///
  /// This method has effect **only on iOS**. On other platforms it performs no
  /// changes.
  ///
  /// The update is applied to the **system VPN profile** associated with
  /// [serverName] and becomes visible in the iOS Settings app (VPN configuration
  /// details for the selected profile).
  ///
  /// Throws a [PlatformException] if the configuration cannot be updated on iOS.
  /// {@endtemplate}
  Future<void> updateConfiguration({required String? serverName, required Configuration? configuration});

  /// {@template vpn_plugin_states}
  /// Stream of VPN connection state changes.
  ///
  /// Emits a new value whenever the VPN connection state changes.
  /// The stream is a broadcast stream, so multiple listeners can subscribe.
  /// {@endtemplate}
  abstract final Stream<VpnManagerState> states;

  /// {@template vpn_plugin_query_log}
  /// Stream of VPN traffic query logs.
  ///
  /// Emits [QueryLogRow] objects representing network traffic passing through the VPN.
  /// {@endtemplate}
  abstract final Stream<QueryLogRow> queryLog;
}

/// {@template vpn_plugin_impl}
/// Default implementation of [VpnPlugin] that communicates with platform-specific code.
///
/// Uses platform channels to communicate with native VPN implementations.
/// {@endtemplate}
class VpnPluginImpl implements VpnPlugin {
  /// {@template vpn_plugin_impl_constructor}
  /// Creates a new [VpnPluginImpl] instance.
  ///
  /// Optionally accepts custom [channel] and [logChannel] for platform communication,
  /// primarily useful for testing.
  /// {@endtemplate}
  VpnPluginImpl({
    EventChannel? channel,
    EventChannel? logChannel,
  }) : _api = IVpnManager(),
       _codec = const ConfigurationCodec(),
       _vpnChannel = channel ?? const EventChannel('vpn_plugin_event_channel'),
       _queryLogChannel = logChannel ?? const EventChannel('vpn_plugin_event_channel_query_log');

  final ConfigurationCodec _codec;
  final IVpnManager _api;
  final EventChannel _vpnChannel;
  final EventChannel _queryLogChannel;

  @override
  Future<VpnManagerState> getCurrentState() => _api.getCurrentState();

  final _logEncoder = QueryLogEncoder();

  /// {@macro vpn_plugin_start}
  @override
  Future<void> start({required String serverName, required Configuration configuration}) {
    final config = _codec.encode(configuration);
    return _api.start(serverName: serverName, config: config);
  }

  /// {@macro vpn_plugin_update_configuration}
  @override
  Future<void> updateConfiguration({required String? serverName, required Configuration? configuration}) {
    String? config;

    if (configuration != null) {
      config = const ConfigurationEncoder().convert(configuration);
    }

    return _api.updateConfiguration(serverName: serverName, config: config);
  }

  /// {@macro vpn_plugin_stop}
  @override
  Future<void> stop() => _api.stop();

  /// {@macro vpn_plugin_states}
  @override
  Stream<VpnManagerState> get states => _vpnChannel.receiveBroadcastStream().map(_mapNativeToState).distinct();

  /// {@macro vpn_plugin_query_log}
  @override
  Stream<QueryLogRow> get queryLog => _queryLogChannel.receiveBroadcastStream().map(
    (e) => _logEncoder.convert(jsonDecode(e.toString()) as Map<String, Object?>),
  );

  /// Converts raw platform-specific state values to [VpnManagerState] enum values.
  static VpnManagerState _mapNativeToState(dynamic raw) {
    if (raw is int) {
      switch (raw) {
        case 0:
          return VpnManagerState.disconnected;
        case 1:
          return VpnManagerState.connecting;
        case 2:
          return VpnManagerState.connected;
        case 3:
          return VpnManagerState.waitingForRecovery;
        case 4:
          return VpnManagerState.recovering;
        case 5:
          return VpnManagerState.waitingForNetwork;
      }
    }

    return VpnManagerState.disconnected;
  }
}
