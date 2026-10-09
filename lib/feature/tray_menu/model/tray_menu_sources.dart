import 'package:flutter/foundation.dart';
import 'package:trusttunnel/feature/server/servers/widget/scope/servers_scope_controller.dart';
import 'package:trusttunnel/feature/settings/app_logging/widgets/scope/app_logging_scope_controller.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_state.dart';
import 'package:trusttunnel/feature/vpn/models/vpn_controller.dart';

/// Reads live scope data without owning the scopes or caching their state.
final class TrayMenuSources implements ValueListenable<TrayMenuState> {
  final VpnController _vpn;
  final ServersScopeController _servers;
  final AppLoggingScopeController _logging;
  final Listenable _sources;

  TrayMenuSources({
    required VpnController vpn,
    required ServersScopeController servers,
    required AppLoggingScopeController logging,
  }) : _vpn = vpn,
       _servers = servers,
       _logging = logging,
       _sources = Listenable.merge([
         vpn,
         servers,
         logging,
       ]);

  @override
  TrayMenuState get value => TrayMenuState(
    vpnState: _vpn.state,
    servers: _servers.servers,
    selectedServer: _servers.selectedServer,
    loggingLevel: _logging.loggingLevel,
    loggingSecurityType: _logging.securityType,
    serverError: _servers.error,
    loggingError: _logging.error,
  );

  @override
  void addListener(VoidCallback listener) => _sources.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _sources.removeListener(listener);
}
