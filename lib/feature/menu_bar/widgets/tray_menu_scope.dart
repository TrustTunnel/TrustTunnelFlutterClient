import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/extensions/context_extensions.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/router/app_route.dart';
import 'package:trusttunnel/common/router/app_routes.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager/macos/macos_exit_dialog.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager/macos/tray_manager_macos.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager/macos/tray_menu_data.dart';
import 'package:trusttunnel/feature/routing/routing/widgets/scope/routing_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_aspect.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/settings/excluded_routes/widgets/scope/excluded_routes_scope.dart';
import 'package:trusttunnel/feature/settings/logs_manager/widgets/scope/logs_manager_scope.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

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
  late final TrayManagerMacOS? _trayManager;
  late VpnController _vpnController;
  late ServersScopeController _serversController;
  late AppLoggingScopeController _appLoggingController;

  Future<void> _syncQueue = Future<void>.value();
  bool _isDisposed = false;
  String? _lastConnectedServerId;

  bool get _isMacOS => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _trayManager = _isMacOS ? TrayManagerMacOS() : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isMacOS) {
      _vpnController = VpnScope.vpnControllerOf(context);
      _serversController = ServersScope.controllerOf(context);
      _appLoggingController = AppLoggingScope.controllerOf(
        context,
        aspect: AppLoggingScopeAspect.loggingLevel,
      );
      AppLoggingScope.controllerOf(context, aspect: AppLoggingScopeAspect.securityType);

      _enqueueSync();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _enqueueSync() {
    if (!_isMacOS || !mounted) {
      return;
    }

    final data = _prepareTrayMenuData();
    _syncQueue = _syncQueue.then((_) => _syncTrayMenu(data));
  }

  TrayMenuData _prepareTrayMenuData() {
    final vpnState = _vpnController.state;
    final servers = _serversController.servers;
    final selectedServer = _serversController.selectedServer;
    final connectionState = _mapConnectionStateForTray(vpnState);
    final activeServer = _resolveActiveServer(
      connectionState: connectionState,
      servers: servers,
      selectedServer: selectedServer,
    );

    return TrayMenuData(
      localization: context.ln,
      connectionState: connectionState,
      activeServerId: activeServer?.id,
      activeServerName: activeServer?.serverData.name,
      servers: servers,
      loggingLevel: _appLoggingController.loggingLevel,
      loggingSecurityType: _appLoggingController.securityType,
    );
  }

  Future<void> _syncTrayMenu(TrayMenuData data) async {
    if (_isDisposed) {
      return;
    }

    await _trayManager?.synchronizeMenu(
      data: data,
      callbacks: TrayMenuCallbacks(
        onAddServerPressed: _onAddServerPressed,
        onRoutingPressed: _onRoutingPressed,
        onConnectionLogPressed: _onConnectionLogPressed,
        onConnectPressed: _onConnectPressed,
        onDisconnectPressed: _onDisconnectPressed,
        onConnectToServerPressed: _onConnectToServerPressed,
        onOtherServersPressed: _onOtherServersPressed,
        onLoggingLevelPressed: _onLoggingLevelPressed,
        onLoggingSecurityTypePressed: _onLoggingSecurityTypePressed,
        onDeleteLogsPressed: _onDeleteLogsPressed,
        onExportLogsPressed: _onExportLogsPressed,
        onQuitPressed: _onQuitPressed,
      ),
    );
  }

  Future<void> _onAddServerPressed() => widget.onRouteRequested(AppRoutes.serverDetails);

  Future<void> _onRoutingPressed() => widget.onRouteRequested(AppRoutes.routing);

  Future<void> _onConnectionLogPressed() => widget.onRouteRequested(AppRoutes.queryLog);

  Future<void> _onConnectPressed() async {
    final targetServer = _resolveCurrentTargetServer();
    if (targetServer == null) {
      return;
    }

    _serversController.pickServer(targetServer.id);
    await _connectToServer(targetServer);
  }

  Future<void> _onDisconnectPressed() => _vpnController.stop();

  Future<void> _onConnectToServerPressed(String serverId) async {
    final server = _serversController.servers.firstWhereOrNull(
      (item) => item.id == serverId,
    );
    if (server == null) {
      return;
    }

    _serversController.pickServer(serverId);
    await _connectToServer(server);
  }

  Future<void> _onOtherServersPressed() => widget.onRouteRequested(AppRoutes.servers);

  Future<void> _onLoggingLevelPressed(LoggingLevel level) {
    if (_appLoggingController.loggingLevel == level) {
      return Future<void>.value();
    }

    _appLoggingController.updateLoggingLevel(level: level);

    return Future<void>.value();
  }

  Future<void> _onLoggingSecurityTypePressed(
    LoggingSecurityType type,
  ) {
    if (_appLoggingController.securityType == type) {
      return Future<void>.value();
    }

    _appLoggingController.updateSecurityType(securityType: type);

    return Future<void>.value();
  }

  Future<void> _onDeleteLogsPressed() {
    LogsManagerScope.controllerOf(context, listen: false).deleteLogs();

    return Future<void>.value();
  }

  Future<void> _onExportLogsPressed() {
    LogsManagerScope.controllerOf(context, listen: false).exportLogs(
      onCanceled: _showExportCanceledSnackBar,
      onError: _showExportErrorSnackBar,
    );

    return Future<void>.value();
  }

  Future<void> _onQuitPressed() async {
    if (!mounted) {
      return;
    }

    final vpnState = _vpnController.state;
    final shouldShowExitDialog = switch (vpnState) {
      VpnState.connected || VpnState.connecting => true,
      VpnState.disconnected ||
      VpnState.waitingForRecovery ||
      VpnState.recovering ||
      VpnState.waitingForNetwork => false,
    };

    if (shouldShowExitDialog) {
      final result = await MacosExitDialog.show(
        title: context.ln.exitDialogTitle,
        message: context.ln.exitDialogDescription,
        quitButtonText: context.ln.quit,
        dontQuitButtonText: context.ln.dontQuit,
      );
      if (!mounted || result != MacosExitDialogResult.quit) {
        return;
      }
    }

    await SystemNavigator.pop();
  }

  Future<void> _connectToServer(Server server) async {
    final routingController = RoutingScope.controllerOf(
      context,
      listen: false,
    );
    final routingProfile = routingController.routingList.firstWhereOrNull(
      (item) => item.id == server.serverData.routingProfileId,
    );
    if (routingProfile == null) {
      return;
    }

    _lastConnectedServerId = server.id;
    _enqueueSync();

    final excludedRoutes = ExcludedRoutesScope.controllerOf(
      context,
      listen: false,
    ).excludedRoutes;

    await _vpnController.start(
      server: server,
      routingProfile: routingProfile,
      excludedRoutes: excludedRoutes,
    );
  }

  Server? _resolveCurrentTargetServer() {
    final vpnState = _vpnController.state;

    return _resolveActiveServer(
      connectionState: _mapConnectionStateForTray(vpnState),
      servers: _serversController.servers,
      selectedServer: _serversController.selectedServer,
    );
  }

  Server? _resolveActiveServer({
    required ConnectionStateInTrayMenuMacOS connectionState,
    required List<Server> servers,
    required Server? selectedServer,
  }) {
    if (servers.isEmpty) {
      return null;
    }

    final fallbackServer = selectedServer ?? servers.first;
    final cachedServer = _lastConnectedServerId == null
        ? null
        : servers.firstWhereOrNull((item) => item.id == _lastConnectedServerId);

    switch (connectionState) {
      case ConnectionStateInTrayMenuMacOS.connected:
      case ConnectionStateInTrayMenuMacOS.connecting:
        final activeServer = cachedServer ?? selectedServer ?? servers.first;
        _lastConnectedServerId = activeServer.id;

        return activeServer;
      case ConnectionStateInTrayMenuMacOS.disconnected:
        return cachedServer ?? fallbackServer;
    }
  }

  void _showExportCanceledSnackBar() {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.exportCanceledSnackbar);
  }

  void _showExportErrorSnackBar() {
    if (!mounted) {
      return;
    }

    context.showInfoSnackBar(message: context.ln.somethingWentWrongSnackbar);
  }

  ConnectionStateInTrayMenuMacOS _mapConnectionStateForTray(VpnState state) => switch (state) {
    VpnState.connected => ConnectionStateInTrayMenuMacOS.connected,
    VpnState.disconnected => ConnectionStateInTrayMenuMacOS.disconnected,
    VpnState.connecting ||
    VpnState.waitingForRecovery ||
    VpnState.recovering ||
    VpnState.waitingForNetwork => ConnectionStateInTrayMenuMacOS.connecting,
  };

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_trayManager?.dispose());
    super.dispose();
  }
}
