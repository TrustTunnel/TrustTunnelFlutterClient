import 'dart:async';

import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_labels.dart';
import 'package:trusttunnel/feature/tray_menu/platform/tray_menu_items_builder.dart';

/// Defines the Windows tray menu contents and layout.
final class WindowsTrayMenuItemsBuilder implements TrayMenuItemsBuilder {
  final int _topServersLimitForView;
  final int _maxServerTitleLength;

  const WindowsTrayMenuItemsBuilder({
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
          title: data.labels.statusTitles[data.connectionState]!,
        ),
      );
      if (data.activeServerName != null) {
        items.add(TrayStatus(title: _truncateServerTitle(data.activeServerName!)));
      }
      items.add(const TraySeparator());
      items.add(
        TrayButton(
          id: 'connect',
          title: data.labels.connect,
          isEnabled: connectEnabled,
          onTap: connectEnabled ? () => unawaited(callbacks.onConnectPressed()) : null,
        ),
      );
      items.add(
        TrayButton(
          id: 'disconnect',
          title: data.labels.disconnect,
          isEnabled: disconnectEnabled,
          onTap: disconnectEnabled ? () => unawaited(callbacks.onDisconnectPressed()) : null,
        ),
      );
      items.add(const TraySeparator());
      items.add(
        TrayButton(
          id: 'connectTo',
          title: data.labels.connectTo,
          children: _buildServerTrayItems(
            data.servers,
            activeServerId: data.activeServerId,
            labels: data.labels,
            callbacks: callbacks,
          ),
        ),
      );
      items.add(const TraySeparator());
    } else {
      items.add(
        TrayButton(
          id: 'addServer',
          title: data.labels.addServer,
          onTap: () => unawaited(callbacks.onAddServerPressed()),
        ),
      );
      items.add(const TraySeparator());
    }

    items.addAll([
      TrayButton(
        id: 'trayOpenApp',
        title: data.labels.trayOpenApp,
        onTap: () => unawaited(callbacks.onOpenTrustTunnelPressed()),
      ),
      TrayButton(
        id: 'routing',
        title: data.labels.routing,
        onTap: () => unawaited(callbacks.onRoutingPressed()),
      ),
      TrayButton(
        id: 'connectionLog',
        title: data.labels.connectionLog,
        onTap: () => unawaited(callbacks.onConnectionLogPressed()),
      ),
      TrayButton(
        id: 'logging',
        title: data.labels.logging,
        children: [
          TrayButton(
            id: 'loggingLevel',
            title: data.labels.loggingLevel,
            children: [
              TrayButton(
                id: 'loggingLevelBasic',
                title: data.labels.loggingLevelBasic,
                isChecked: data.loggingLevel == LoggingLevel.defaultLevel,
                onTap: () => unawaited(
                  callbacks.onLoggingLevelPressed(LoggingLevel.defaultLevel),
                ),
              ),
              TrayButton(
                id: 'loggingLevelDetailed',
                title: data.labels.loggingLevelDetailed,
                isChecked: data.loggingLevel == LoggingLevel.debug,
                onTap: () => unawaited(
                  callbacks.onLoggingLevelPressed(LoggingLevel.debug),
                ),
              ),
            ],
          ),
          TrayButton(
            id: 'sensitiveData',
            title: data.labels.sensitiveData,
            children: [
              TrayButton(
                id: 'sensitiveDataExcluded',
                title: data.labels.sensitiveDataExcluded,
                isChecked: data.loggingSecurityType == LoggingSecurityType.stripped,
                onTap: () => unawaited(
                  callbacks.onLoggingSecurityTypePressed(LoggingSecurityType.stripped),
                ),
              ),
              TrayButton(
                id: 'sensitiveDataIncluded',
                title: data.labels.sensitiveDataIncluded,
                isChecked: data.loggingSecurityType == LoggingSecurityType.full,
                onTap: () => unawaited(
                  callbacks.onLoggingSecurityTypePressed(LoggingSecurityType.full),
                ),
              ),
            ],
          ),
          TrayButton(
            id: 'deleteAppLogs',
            title: data.labels.deleteAppLogs,
            onTap: () => unawaited(callbacks.onDeleteLogsPressed()),
          ),
          TrayButton(
            id: 'downloadAppLogs',
            title: data.labels.downloadAppLogs,
            onTap: () => unawaited(callbacks.onExportLogsPressed()),
          ),
        ],
      ),
      const TraySeparator(),
      TrayButton(
        id: 'trayQuitApp',
        title: data.labels.trayQuitApp,
        onTap: () => unawaited(callbacks.onQuitPressed()),
      ),
    ]);

    return items;
  }

  List<TrayItem> _buildServerTrayItems(
    List<Server> servers, {
    required String? activeServerId,
    required TrayMenuLabels labels,
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
        title: labels.otherServers,
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
}
