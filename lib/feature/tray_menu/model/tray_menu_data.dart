import 'package:flutter/foundation.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/server.dart';

enum TrayMenuConnectionState {
  connected,
  connecting,
  disconnected,
}

/// Native menu item event handlers supplied by the tray controller.
/// They translate menu clicks into coordinated application actions.
final class TrayMenuCallbacks {
  final AsyncCallback onAddServerPressed;
  final AsyncCallback onOpenTrustTunnelPressed;
  final AsyncCallback onRoutingPressed;
  final AsyncCallback onConnectionLogPressed;
  final AsyncCallback onConnectPressed;
  final AsyncCallback onDisconnectPressed;
  final Future<void> Function(String serverId) onConnectToServerPressed;
  final AsyncCallback onOtherServersPressed;
  final Future<void> Function(LoggingLevel level) onLoggingLevelPressed;
  final Future<void> Function(LoggingSecurityType type) onLoggingSecurityTypePressed;
  final AsyncCallback onDeleteLogsPressed;
  final AsyncCallback onExportLogsPressed;
  final AsyncCallback onQuitPressed;

  const TrayMenuCallbacks({
    required this.onAddServerPressed,
    required this.onOpenTrustTunnelPressed,
    required this.onRoutingPressed,
    required this.onConnectionLogPressed,
    required this.onConnectPressed,
    required this.onDisconnectPressed,
    required this.onConnectToServerPressed,
    required this.onOtherServersPressed,
    required this.onLoggingLevelPressed,
    required this.onLoggingSecurityTypePressed,
    required this.onDeleteLogsPressed,
    required this.onExportLogsPressed,
    required this.onQuitPressed,
  });
}

final class TrayMenuData {
  final AppLocalizations localization;
  final TrayMenuConnectionState connectionState;
  final String? activeServerId;
  final String? activeServerName;
  final List<Server> servers;
  final LoggingLevel loggingLevel;
  final LoggingSecurityType loggingSecurityType;

  const TrayMenuData({
    required this.localization,
    required this.connectionState,
    required this.activeServerId,
    required this.activeServerName,
    required this.servers,
    required this.loggingLevel,
    required this.loggingSecurityType,
  });

  bool get hasServers => servers.isNotEmpty;
}
