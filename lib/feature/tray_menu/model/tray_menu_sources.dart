import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_version_and_updating/widgets/scope/app_version_and_updating_scope_controller.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_state.dart';
import 'package:trusttunnel/feature/vpn/widgets/vpn_scope_controller.dart';

/// Reads live scope data without owning the scopes or caching their state.
final class TrayMenuSources implements ValueListenable<TrayMenuState> {
  final VpnScopeController _vpnScopeController;
  final ServersScopeController _serversScopeController;
  final AppLoggingScopeController _appLoggingScopeController;
  final Listenable _sources;
  final AppVersionAndUpdatingScopeController _updatesController;

  TrayMenuSources({
    required this._updatesController,
    required this._vpnScopeController,
    required this._serversScopeController,
    required this._appLoggingScopeController,
  }) : _sources = Listenable.merge([
         _vpnScopeController,
         _serversScopeController,
         _appLoggingScopeController,
       ]);

  final Map<VoidCallback, VoidCallback> _updateListeners = {};

  @override
  TrayMenuState get value => TrayMenuState(
    updateAvailable: _updatesController.updatesSupported && _updatesController.showUpdateIndicator,
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
  void addListener(VoidCallback listener) {
    _sources.addListener(listener);
    bool previousUpdateIndicator = _updatesController.showUpdateIndicator;

    void onUpdateChanged() {
      final bool nextUpdateIndicator = _updatesController.showUpdateIndicator;
      if (nextUpdateIndicator == previousUpdateIndicator) {
        return;
      }

      previousUpdateIndicator = nextUpdateIndicator;
      listener();
    }

    _updateListeners[listener] = onUpdateChanged;
    _updatesController.addListener(onUpdateChanged);
  }

  @override
  void removeListener(VoidCallback listener) {
    _sources.removeListener(listener);
    final void Function()? updateListener = _updateListeners.remove(listener);
    if (updateListener != null) {
      _updatesController.removeListener(updateListener);
    }
  }
}
