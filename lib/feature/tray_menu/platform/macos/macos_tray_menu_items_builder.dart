import 'dart:async';

import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';
import 'package:trusttunnel/feature/tray_menu/platform/tray_menu_items_builder.dart';

/// Defines the macOS tray menu contents and layout.
final class MacosTrayMenuItemsBuilder implements TrayMenuItemsBuilder {
  final int _topServersLimitForView;
  final int _maxServerTitleLength;

  const MacosTrayMenuItemsBuilder({
    this._topServersLimitForView = 10,
    this._maxServerTitleLength = 40,
  });

  @override
  List<TrayItem> build({
    required TrayMenuData data,
    required TrayMenuCallbacks callbacks,
  }) {
    final items = <TrayItem>[];
    final connectEnabled = data.connectionState == TrayMenuConnectionState.disconnected;
    final disconnectEnabled = !connectEnabled;

    if (data.hasServers) {
      items.add(
        TrayStatus(
          title: data.localization.trayStatus(
            _getConnectionStateTitleString(data.connectionState, data.localization),
          ),
        ),
      );
      items.add(
        TrayStatus(
          title: _truncateServerTitle(data.activeServerName!),
        ),
      );
      items.add(const TraySeparator());
      items.add(
        TrayButton(
          id: 'connect',
          title: data.localization.connect,
          isEnabled: connectEnabled,
          onTap: connectEnabled ? () => unawaited(callbacks.onConnectPressed()) : null,
        ),
      );
      items.add(
        TrayButton(
          id: 'disconnect',
          title: data.localization.disconnect,
          isEnabled: disconnectEnabled,
          onTap: disconnectEnabled ? () => unawaited(callbacks.onDisconnectPressed()) : null,
        ),
      );
      items.add(const TraySeparator());
      items.add(
        TrayButton(
          id: 'connectTo',
          title: data.localization.connectTo,
          children: _buildServerTrayItems(
            data.servers,
            activeServerId: data.activeServerId,
            localization: data.localization,
            callbacks: callbacks,
          ),
        ),
      );
      items.add(const TraySeparator());
    } else {
      items.add(
        TrayButton(
          id: 'addServer',
          title: data.localization.addServer,
          onTap: () => unawaited(callbacks.onAddServerPressed()),
        ),
      );
      items.add(const TraySeparator());
    }

    items.addAll([
      TrayButton(
        id: 'trayOpenApp',
        title: data.localization.trayOpenApp(AppConstants.appName),
        onTap: () => unawaited(callbacks.onOpenTrustTunnelPressed()),
      ),
      TrayButton(
        id: 'routing',
        title: data.localization.routing,
        onTap: () => unawaited(callbacks.onRoutingPressed()),
      ),
      TrayButton(
        id: 'connectionLog',
        title: data.localization.connectionLog,
        onTap: () => unawaited(callbacks.onConnectionLogPressed()),
      ),
      TrayButton(
        id: 'logging',
        title: data.localization.logging,
        children: [
          TrayButton(
            id: 'loggingLevel',
            title: data.localization.loggingLevel,
            children: [
              TrayButton(
                id: 'loggingLevelBasic',
                title: data.localization.loggingLevelBasic,
                isChecked: data.loggingLevel == LoggingLevel.defaultLevel,
                onTap: () => unawaited(
                  callbacks.onLoggingLevelPressed(LoggingLevel.defaultLevel),
                ),
              ),
              TrayButton(
                id: 'loggingLevelDetailed',
                title: data.localization.loggingLevelDetailed,
                isChecked: data.loggingLevel == LoggingLevel.debug,
                onTap: () => unawaited(
                  callbacks.onLoggingLevelPressed(LoggingLevel.debug),
                ),
              ),
            ],
          ),
          TrayButton(
            id: 'sensitiveData',
            title: data.localization.sensitiveData,
            children: [
              TrayButton(
                id: 'sensitiveDataExcluded',
                title: data.localization.sensitiveDataExcluded,
                isChecked: data.loggingSecurityType == LoggingSecurityType.stripped,
                onTap: () => unawaited(
                  callbacks.onLoggingSecurityTypePressed(LoggingSecurityType.stripped),
                ),
              ),
              TrayButton(
                id: 'sensitiveDataIncluded',
                title: data.localization.sensitiveDataIncluded,
                isChecked: data.loggingSecurityType == LoggingSecurityType.full,
                onTap: () => unawaited(
                  callbacks.onLoggingSecurityTypePressed(LoggingSecurityType.full),
                ),
              ),
            ],
          ),
          TrayButton(
            id: 'deleteAppLogs',
            title: data.localization.deleteAppLogs,
            onTap: () => unawaited(callbacks.onDeleteLogsPressed()),
          ),
          TrayButton(
            id: 'downloadAppLogs',
            title: data.localization.downloadAppLogs,
            onTap: () => unawaited(callbacks.onExportLogsPressed()),
          ),
        ],
      ),
      const TraySeparator(),
      TrayButton(
        id: 'trayQuitApp',
        title: data.localization.trayQuitApp(AppConstants.appName),
        onTap: () => unawaited(callbacks.onQuitPressed()),
      ),
    ]);

    return items;
  }

  List<TrayItem> _buildServerTrayItems(
    List<Server> servers, {
    required String? activeServerId,
    required AppLocalizations localization,
    required TrayMenuCallbacks callbacks,
  }) {
    final topLevelServers = servers.take(_topServersLimitForView).toList();
    final items = topLevelServers
        .map(
          (server) => TrayButton(
            id: 'server:${server.id}',
            title: _truncateServerTitle(server.serverData.name),
            isChecked: server.id == activeServerId,
            onTap: () => unawaited(callbacks.onConnectToServerPressed(server.id)),
          ),
        )
        .toList();

    if (servers.length <= _topServersLimitForView) {
      return items;
    }

    items.add(
      TrayButton(
        id: 'otherServers',
        title: localization.otherServers,
        onTap: () => unawaited(callbacks.onOtherServersPressed()),
      ),
    );

    return items;
  }

  String _truncateServerTitle(String value) {
    if (value.length <= _maxServerTitleLength) {
      return value;
    }

    return '${value.substring(0, _maxServerTitleLength - 1)}…';
  }

  String _getConnectionStateTitleString(
    TrayMenuConnectionState state,
    AppLocalizations localization,
  ) => switch (state) {
    TrayMenuConnectionState.connected => localization.trayStatusConnected,
    TrayMenuConnectionState.connecting => localization.trayStatusConnecting,
    TrayMenuConnectionState.disconnected => localization.trayStatusDisconnected,
  };
}
