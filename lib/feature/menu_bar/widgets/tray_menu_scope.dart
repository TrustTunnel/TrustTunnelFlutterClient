import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/localization/localization.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager_macos.dart';
import 'package:trusttunnel/feature/menu_bar/utils/exit_dialog.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope.dart';

class TrayMenuScope extends StatefulWidget {
  final Widget child;

  const TrayMenuScope({
    required this.child,
    super.key,
  });

  @override
  State<TrayMenuScope> createState() => _TrayMenuScopeState();
}

class _TrayMenuScopeState extends State<TrayMenuScope> {
  late final TrayManagerMacOS? _trayManager;

  Future<void> _syncQueue = Future<void>.value();
  bool _isDisposed = false;

  bool get _isMacOs => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _trayManager = _isMacOs ? TrayManagerMacOS() : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isMacOs) {
      return;
    }

    final vpnState = VpnScope.vpnControllerOf(context).state;
    final serversController = ServersScope.controllerOf(context);
    final selectedServer = serversController.selectedServer;
    final servers = serversController.servers;

    final data = TrayMenuData(
      localization: context.ln,
      connectionState: _mapConnectionState(vpnState),
      selectedServerName: servers.isEmpty ? null : (selectedServer ?? servers.first).serverData.name,
      servers: servers,
    );

    _syncQueue = _syncQueue.then((_) => _syncTray(data));
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _syncTray(TrayMenuData data) async {
    if (_isDisposed) {
      return;
    }

    await _trayManager?.sync(
      data: data,
      onQuitPressed: _onQuitPressed,
    );
  }

  Future<void> _onQuitPressed() async {
    if (!mounted) {
      return;
    }

    final vpnState = VpnScope.vpnControllerOf(context, listen: false).state;
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
      if (!mounted || result != ExitDialogResult.quit) {
        return;
      }
    }

    await SystemNavigator.pop();
  }

  TrayConnectionState _mapConnectionState(VpnState state) => switch (state) {
    VpnState.connected => TrayConnectionState.connected,
    VpnState.disconnected => TrayConnectionState.disconnected,
    VpnState.connecting ||
    VpnState.waitingForRecovery ||
    VpnState.recovering ||
    VpnState.waitingForNetwork => TrayConnectionState.connecting,
  };

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(_trayManager?.dispose());
    super.dispose();
  }
}
