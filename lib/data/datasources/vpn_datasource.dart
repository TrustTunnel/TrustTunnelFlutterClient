import 'package:vpn/data/model/routing_profile.dart';
import 'package:vpn/data/model/server.dart';
import 'package:vpn/data/model/vpn_log.dart';
import 'package:vpn/data/model/vpn_state.dart';

abstract class VpnDataSource {
  Stream<VpnState> get vpnState;

  Stream<VpnLog> get vpnLogs;

  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
  });

  Future<void> stop();

  Future<VpnState> requestState();
}
