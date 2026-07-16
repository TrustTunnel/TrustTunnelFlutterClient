import 'dart:async';

import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/datasources/logging_settings_datasource.dart';
import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

abstract class VpnRepository {
  Future<Stream<VpnState>> startListenToStates({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  });

  Future<void> updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  });

  Future<void> deleteConfiguration();

  Future<Stream<VpnLog>> listenToLogs();

  Future<VpnState> requestState();

  Future<void> stop();
}

class VpnRepositoryImpl implements VpnRepository {
  final VpnDataSource _vpnDataSource;
  final LoggingSettingsDataSource _loggingSettingsDataSource;

  VpnRepositoryImpl({
    required VpnDataSource vpnDataSource,
    required LoggingSettingsDataSource loggingSettingsDataSource,
  }) : _vpnDataSource = vpnDataSource,
       _loggingSettingsDataSource = loggingSettingsDataSource;

  @override
  Future<Stream<VpnState>> startListenToStates({
    required Server server,
    required List<String> excludedRoutes,
    required RoutingProfile routingProfile,
  }) async {
    final logLevel = await _getConfigurationLogLevel();

    await _vpnDataSource.start(
      server: server.serverData,
      routingProfile: routingProfile.data,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );

    return _vpnDataSource.vpnState;
  }

  @override
  Future<void> stop() => _vpnDataSource.stop();

  @override
  Future<Stream<VpnLog>> listenToLogs() async => _vpnDataSource.vpnLogs;

  @override
  Future<VpnState> requestState() => _vpnDataSource.requestState();

  @override
  Future<void> updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  }) async {
    final logLevel = await _getConfigurationLogLevel();

    await _vpnDataSource.updateConfiguration(
      server: server.serverData,
      routingProfile: routingProfile.data,
      excludedRoutes: excludedRoutes,
      logLevel: logLevel,
    );
  }

  @override
  Future<void> deleteConfiguration() => _vpnDataSource.deleteConfiguration();

  Future<VpnConfigurationLogLevel> _getConfigurationLogLevel() async {
    final securityType = await _loggingSettingsDataSource.getSecurityType();

    return switch (securityType) {
      LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
      LoggingSecurityType.full => VpnConfigurationLogLevel.debug,
    };
  }
}
