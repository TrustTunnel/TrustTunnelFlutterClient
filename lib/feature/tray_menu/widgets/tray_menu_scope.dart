import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/router/app_route.dart';
import 'package:trusttunnel/data/model/vpn_configuration_log_level.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope.dart';
import 'package:trusttunnel/feature/tray_menu/controller/tray_menu_controller.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_sources.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

/// Provides the desktop tray with scope dependencies and localized UI feedback.
class TrayMenuScope extends StatefulWidget {
  final Widget child;
  final Future<void> Function(AppRoute route) onRouteRequested;

  const TrayMenuScope({
    required this.onRouteRequested,
    required this.child,
    super.key,
  });

  @override
  State<TrayMenuScope> createState() => _TrayMenuScopeState();
}

class _TrayMenuScopeState extends State<TrayMenuScope> {
  TrayMenuController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (defaultTargetPlatform != TargetPlatform.macOS && defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }

    final controller = _controller;
    if (controller != null) {
      controller.updateLocalization(context.ln);

      return;
    }

    final vpn = VpnScope.vpnControllerOf(context, listen: false);
    final servers = ServersScope.controllerOf(context, listen: false);
    final logging = AppLoggingScope.controllerOf(context, listen: false);
    final routing = RoutingScope.controllerOf(context, listen: false);
    final routes = ExcludedRoutesScope.controllerOf(context, listen: false);
    final logs = LogsManagerScope.controllerOf(context, listen: false);
    final sources = TrayMenuSources(vpn: vpn, servers: servers, logging: logging);

    _controller = TrayMenuController(
      sources: sources,
      connect: (server, {required onReady}) async {
        if (logging.loading || servers.loading || routing.loading || routes.loading) {
          return;
        }

        final profile = routing.routingList.firstWhereOrNull(
          (item) => item.id == server.serverData.routingProfileId,
        );
        if (profile == null) {
          return;
        }

        // Only persisted exclusions belong in the VPN configuration.
        final excludedRoutes = routes.initialExcludedRoutes;
        if (!onReady()) {
          return;
        }

        await vpn.start(
          server: server,
          routingProfile: profile,
          excludedRoutes: excludedRoutes,
          logLevel: switch (logging.securityType) {
            LoggingSecurityType.stripped => VpnConfigurationLogLevel.error,
            LoggingSecurityType.full => switch (logging.loggingLevel) {
              LoggingLevel.defaultLevel => VpnConfigurationLogLevel.info,
              LoggingLevel.debug => VpnConfigurationLogLevel.debug,
            },
          },
        );
      },
      disconnect: vpn.stop,
      pickServer: servers.pickServer,
      updateLoggingLevel: (level) => logging.updateLoggingLevel(level: level),
      updateSecurityType: (type) => logging.updateSecurityType(securityType: type),
      exportLogs: logs.exportLogs,
      deleteLogs: logs.deleteLogs,
      windowController: context.dependencyFactory.appWindowController!,
      localization: context.ln,
      onRouteRequested: (route) async {
        if (mounted) {
          await widget.onRouteRequested(route);
        }
      },
      onMessage: _showMessage,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _showMessage({bool canceled = false}) {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(
      message: canceled ? context.ln.exportCanceledSnackbar : context.ln.somethingWentWrongSnackbar,
    );
  }

  @override
  void dispose() {
    // Regular sync cleanup doesn't cover this case completely (since we're dependent on the native side and other async operations),
    // so we do it this way
    unawaited(
      _controller?.dispose().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
          ),
        );
      }),
    );
    super.dispose();
  }
}
