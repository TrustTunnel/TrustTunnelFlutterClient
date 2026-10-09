import 'package:flutter/foundation.dart' show Listenable;
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';

mixin VpnController implements Listenable {
  abstract final VpnState state;

  /// Notifies the UI when a VPN operation or exit request fails.
  abstract final Listenable operationErrorListenable;

  Future<void> start({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  });

  Future<void> updateConfiguration({
    required Server server,
    required RoutingProfile routingProfile,
    required List<String> excludedRoutes,
    required VpnConfigurationLogLevel logLevel,
  });

  Future<void> deleteConfiguration();

  Future<void> stop();

  Future<void> notifyOnOperationError();
}
