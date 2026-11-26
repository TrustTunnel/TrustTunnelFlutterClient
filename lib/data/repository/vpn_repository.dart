import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:trusttunnel/data/datasources/vpn_profile_server_datasource.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

abstract class VpnRepository {
  /// The saved server ID for restoring the VPN display, or `null` if unavailable.
  ///
  /// Reads the server of the system profile, which can start the VPN without the app.
  Future<String?> getSavedVpnProfileServerId();

  /// Saves [serverId] for later restoration of the VPN display.
  ///
  /// Call this when a connection started by the app reports `Connected`.
  /// Skips the write on platforms without profile restoration and logs storage errors.
  Future<void> saveVpnProfileServerId(String serverId);

  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
    bool fallIntoRecovery = false,
  });

  Future<Stream<VpnState>> listenToStates();

  /// Applies [server] and the given settings to the saved system profile.
  ///
  /// On iOS and macOS the profile keeps its own server, so this also keeps the
  /// saved server ID in sync: an ID that differs from [server] is cleared before
  /// the native call, and [server]'s ID is stored after the call succeeds. A
  /// connection that the system starts from the profile can then restore its server.
  Future<void> updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  });

  Future<void> deleteConfiguration();

  Future<Stream<VpnLog>> listenToLogs();

  Future<VpnState> requestState();

  Future<void> stop();
}

class VpnRepositoryImpl implements VpnRepository {
  final VpnDataSource _vpnDataSource;
  final VpnProfileServerDataSource _vpnProfileServerDataSource;

  VpnRepositoryImpl({
    required this._vpnDataSource,
    required this._vpnProfileServerDataSource,
  });

  // Apple platforms and Android can start VPN from a saved configuration.
  // Windows uses the server ID from the app's start command.
  bool get _supportsVpnProfileRestoration => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS || TargetPlatform.android => true,
    _ => false,
  };

  // Only iOS and macOS change the saved profile through update or delete calls.
  // Android saves its configuration on start. Windows receives it on start.
  bool get _supportsVpnProfileUpdates => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => true,
    _ => false,
  };

  @override
  Future<String?> getSavedVpnProfileServerId() async {
    if (!_supportsVpnProfileRestoration) {
      return null;
    }

    return _vpnProfileServerDataSource.getServerId();
  }

  @override
  Future<void> saveVpnProfileServerId(String serverId) async {
    if (_supportsVpnProfileRestoration && (await getSavedVpnProfileServerId() != serverId)) {
      await _writeVpnProfileServerId(serverId);
    }
  }

  @override
  Future<void> start({
    required Server server,
    required List<String> excludedRoutes,
    required RoutingProfile routingProfile,
    required VpnConfigurationLogLevel logLevel,
    bool fallIntoRecovery = false,
  }) async {
    await _clearSavedVpnProfileServerIdIfChanged(server.id);

    return _vpnDataSource.start(
      server: server.serverData,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
      fallIntoRecovery: fallIntoRecovery,
    );
  }

  @override
  Future<Stream<VpnState>> listenToStates() async => _vpnDataSource.vpnState;

  @override
  Future<void> stop() async {
    // Android clears the configuration used by Always-on VPN on stop.
    // iOS and macOS keep the system profile, so its server ID remains valid.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _clearSavedVpnProfileServerIdIfChanged(null);
    }

    return _vpnDataSource.stop();
  }

  @override
  Future<Stream<VpnLog>> listenToLogs() async => _vpnDataSource.vpnLogs;

  @override
  Future<VpnState> requestState() => _vpnDataSource.requestState();

  @override
  Future<void> updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  }) async {
    if (_supportsVpnProfileUpdates) {
      await _clearSavedVpnProfileServerIdIfChanged(server.id);
    }

    await _vpnDataSource.updateConfiguration(
      server: server.serverData,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );

    // The system profile now starts this server, so it can restore the server ID
    // even though the app did not start the connection.
    if (_supportsVpnProfileUpdates) {
      await saveVpnProfileServerId(server.id);
    }
  }

  @override
  Future<void> deleteConfiguration() async {
    if (_supportsVpnProfileUpdates) {
      await _clearSavedVpnProfileServerIdIfChanged(null);
    }

    return _vpnDataSource.deleteConfiguration();
  }

  Future<void> _clearSavedVpnProfileServerIdIfChanged(String? nextServerId) async {
    final savedServerId = await getSavedVpnProfileServerId();
    if (savedServerId != null && savedServerId != nextServerId) {
      // The plugin can return before the profile changes. Clear the old ID first.
      await _writeVpnProfileServerId(null);
    }
  }

  Future<void> _writeVpnProfileServerId(String? serverId) async {
    final errorMessage = serverId == null
        ? 'Unable to clear VPN profile server ID'
        : 'Unable to save VPN profile server ID';

    try {
      final saved = await _vpnProfileServerDataSource.setServerId(serverId);
      if (!saved) {
        logger.logWarning(errorMessage);
      }
    } on Object catch (error, stackTrace) {
      logger.logError(
        errorMessage,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
