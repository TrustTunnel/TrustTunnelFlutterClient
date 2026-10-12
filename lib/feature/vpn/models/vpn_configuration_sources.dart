import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/routing_profile.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope_controller.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope_controller.dart';

/// Reads saved VPN settings without caching state or owning the controllers.
final class VpnConfigurationSources implements Listenable {
  final ServersScopeController _serversScopeController;
  final RoutingScopeController _routingScopeController;
  final AppLoggingScopeController _appLoggingScopeController;
  final ExcludedRoutesScopeController _excludedRoutesScopeController;
  final Listenable _sources;

  VpnConfigurationSources({
    required ServersScopeController serversScopeController,
    required RoutingScopeController routingScopeController,
    required AppLoggingScopeController appLoggingScopeController,
    required ExcludedRoutesScopeController excludedRoutesScopeController,
  }) : _serversScopeController = serversScopeController,
       _routingScopeController = routingScopeController,
       _appLoggingScopeController = appLoggingScopeController,
       _excludedRoutesScopeController = excludedRoutesScopeController,
       _sources = Listenable.merge([
         serversScopeController,
         routingScopeController,
         appLoggingScopeController,
         excludedRoutesScopeController,
       ]);

  bool get loading =>
      _serversScopeController.loading ||
      _routingScopeController.loading ||
      _appLoggingScopeController.loading ||
      _excludedRoutesScopeController.loading;

  bool get hasErrors =>
      _serversScopeController.error != null ||
      _routingScopeController.error != null ||
      _appLoggingScopeController.error != null ||
      _excludedRoutesScopeController.error != null;

  bool get serversLoading => _serversScopeController.loading;

  PresentationException? get serversError => _serversScopeController.error;

  List<Server> get servers => _serversScopeController.servers;

  Server? get selectedServer => _serversScopeController.selectedServer;

  @override
  void addListener(VoidCallback listener) => _sources.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _sources.removeListener(listener);

  ({
    Server server,
    RoutingProfile routingProfile,
    List<String> excludedRoutes,
    VpnConfigurationLogLevel logLevel,
  })?
  configurationFor(String? serverId) {
    final server = _serversScopeController.servers.firstWhereOrNull((server) => server.id == serverId);
    if (server == null) {
      return null;
    }
    final profile = _routingScopeController.routingList.firstWhereOrNull(
      (profile) => profile.id == server.serverData.routingProfileId,
    );
    if (profile == null) {
      return null;
    }

    return (
      // Selection is metadata and must not participate in configuration equality.
      server: server.copyWith(serverData: server.serverData.copyWith(selected: false)),
      routingProfile: profile,
      excludedRoutes: List<String>.of(_excludedRoutesScopeController.initialExcludedRoutes),
      logLevel: switch (_appLoggingScopeController.securityType) {
        LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
        LoggingSecurityType.full => switch (_appLoggingScopeController.loggingLevel) {
          LoggingLevel.defaultLevel => VpnConfigurationLogLevel.info,
          LoggingLevel.debug => VpnConfigurationLogLevel.debug,
        },
      },
    );
  }
}
