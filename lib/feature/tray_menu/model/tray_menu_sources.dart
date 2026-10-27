import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_state.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_controller.dart';

/// Reads live scope data without owning the scopes or caching their state.
final class TrayMenuSources implements ValueListenable<TrayMenuState> {
  final VpnScopeController _vpnScopeController;
  final ServersScopeController _serversScopeController;
  final AppLoggingScopeController _appLoggingScopeController;
  final Listenable _sources;

  TrayMenuSources({
    required this._vpnScopeController,
    required this._serversScopeController,
    required this._appLoggingScopeController,
  }) : _sources = Listenable.merge([
         _vpnScopeController,
         _serversScopeController,
         _appLoggingScopeController,
       ]);

  @override
  TrayMenuState get value => TrayMenuState(
    vpnState: _vpnScopeController.state,
    currentlyConnectedServerId: _vpnScopeController.currentlyConnectedServerId,
    servers: _serversScopeController.servers,
    selectedServer: _serversScopeController.selectedServer,
    loggingLevel: _appLoggingScopeController.loggingLevel,
    loggingSecurityType: _appLoggingScopeController.securityType,
    serverError: _serversScopeController.error,
    loggingError: _appLoggingScopeController.error,
  );

  @override
  void addListener(VoidCallback listener) => _sources.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _sources.removeListener(listener);
}
