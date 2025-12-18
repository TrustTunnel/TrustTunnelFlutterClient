import 'dart:async';

import 'package:trusttunnel/data/datasources/vpn_datasource.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_log.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

abstract class VpnRepository {
  Future<Stream<VpnState>> startListenToStates({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  });

  Future<Stream<VpnLog>> listenToLogs();

  Future<VpnState> requestState();

  Future<void> stop();
}

class VpnRepositoryImpl implements VpnRepository {
  final VpnDataSource _vpnDataSource;

  VpnRepositoryImpl({
    required VpnDataSource vpnDataSource,
  }) : _vpnDataSource = vpnDataSource;

  @override
  Future<Stream<VpnState>> startListenToStates({
    required Server server,
    required List<String> excludedRoutes,
    required RoutingProfile routingProfile,
  }) async {
    await _vpnDataSource.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
    );

    return _vpnDataSource.vpnState;
  }

  @override
  Future<void> stop() => _vpnDataSource.stop();

  @override
  Future<Stream<VpnLog>> listenToLogs() async => _vpnDataSource.vpnLogs;

  @override
  Future<VpnState> requestState() => _vpnDataSource.requestState();
}
