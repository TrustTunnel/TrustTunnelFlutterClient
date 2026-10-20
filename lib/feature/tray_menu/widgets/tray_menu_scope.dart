import 'dart:async';

import 'package:adguard_logger/adguard_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/router/app_route.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope.dart';
import 'package:trusttunnel/feature/tray_menu/controller/tray_menu_controller.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_labels.dart';
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
      controller.updateLabels(_getLabels());

      return;
    }

    final vpn = VpnScope.vpnControllerOf(context, listen: false);
    final servers = ServersScope.controllerOf(context, listen: false);
    final logging = AppLoggingScope.controllerOf(context, listen: false);
    final logs = LogsManagerScope.controllerOf(context, listen: false);
    final sources = TrayMenuSources(vpn: vpn, servers: servers, logging: logging);

    _controller = TrayMenuController(
      sources: sources,
      connect: vpn.selectAndConnectToServer,
      disconnect: vpn.disconnect,
      updateLoggingLevel: (level) => logging.updateLoggingLevel(level: level),
      updateSecurityType: (type) => logging.updateSecurityType(securityType: type),
      exportLogs: logs.exportLogs,
      deleteLogs: logs.deleteLogs,
      windowController: context.dependencyFactory.appWindowController,
      labels: _getLabels(),
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

  TrayMenuLabels _getLabels() {
    final ln = context.ln;

    return TrayMenuLabels(
      connect: ln.connect,
      disconnect: ln.disconnect,
      connectTo: ln.connectTo,
      addServer: ln.addServer,
      trayOpenApp: ln.trayOpenApp(AppConstants.appName),
      routing: ln.routing,
      connectionLog: ln.connectionLog,
      logging: ln.logging,
      loggingLevel: ln.loggingLevel,
      loggingLevelBasic: ln.loggingLevelBasic,
      loggingLevelDetailed: ln.loggingLevelDetailed,
      sensitiveData: ln.sensitiveData,
      sensitiveDataExcluded: ln.sensitiveDataExcluded,
      sensitiveDataIncluded: ln.sensitiveDataIncluded,
      deleteAppLogs: ln.deleteAppLogs,
      downloadAppLogs: ln.downloadAppLogs,
      trayQuitApp: ln.trayQuitApp(AppConstants.appName),
      otherServers: ln.otherServers,
      connectionTitles: {
        TrayMenuConnectionState.connected: ln.trayStatusConnected,
        TrayMenuConnectionState.connecting: ln.trayStatusConnecting,
        TrayMenuConnectionState.disconnected: ln.trayStatusDisconnected,
      },
      statusTitles: {
        TrayMenuConnectionState.connected: ln.trayStatus(ln.trayStatusConnected),
        TrayMenuConnectionState.connecting: ln.trayStatus(ln.trayStatusConnecting),
        TrayMenuConnectionState.disconnected: ln.trayStatus(ln.trayStatusDisconnected),
      },
    );
  }

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
        logger.logError(
          'Unable to dispose tray menu controller',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
    super.dispose();
  }
}
