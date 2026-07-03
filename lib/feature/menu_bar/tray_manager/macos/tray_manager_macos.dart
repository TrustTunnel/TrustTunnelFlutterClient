import 'dart:async';

import 'package:tray_manager/tray_manager.dart';

import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager/macos/tray_menu_data.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager/macos/tray_menu_icons.dart';

final class TrayManagerMacOS {
  final TrayManagerApi _trayManagerApi;
  final int _topServersLimitForView;
  final int _maxServerTitleLength;

  TrayIcons? _trayIcons;
  bool _isTrayInitialized = false;

  TrayManagerMacOS({
    TrayManagerApi? trayManager,
    int topServersLimitForView = 10,
    int maxServerTitleLength = 40,
  }) : _trayManagerApi = trayManager ?? TrayManagerApi(),
       _topServersLimitForView = topServersLimitForView,
       _maxServerTitleLength = maxServerTitleLength;

  Future<void> synchronizeMenu({
    required TrayMenuData data,
    required TrayMenuCallbacks callbacks,
  }) async {
    final trayIcons = await _ensureTrayIcons();
    final trayItems = _buildTrayItems(
      data,
      callbacks: callbacks,
    );

    if (!_isTrayInitialized) {
      await _trayManagerApi.initTray(trayItems);
      _isTrayInitialized = true;
    } else {
      await _trayManagerApi.updateMenu(trayItems);
    }

    await _trayManagerApi.setTrayIcon(
      trayIcons.iconFor(data.connectionState),
    );
  }

  Future<void> dispose() => _trayManagerApi.dispose();

  Future<TrayIcons> _ensureTrayIcons() async {
    final existingIcons = _trayIcons;
    if (existingIcons != null) {
      return existingIcons;
    }

    final icons = await TrayIcons.create();
    _trayIcons = icons;

    return icons;
  }

  List<TrayItem> _buildTrayItems(
    TrayMenuData data, {
    required TrayMenuCallbacks callbacks,
  }) {
    final items = <TrayItem>[];
    final connectEnabled = data.connectionState == ConnectionStateInTrayMenuMacOS.disconnected;
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
          title: data.localization.connect,
          isEnabled: connectEnabled,
          onTap: connectEnabled ? () => unawaited(callbacks.onConnectPressed()) : null,
        ),
      );
      items.add(
        TrayButton(
          title: data.localization.disconnect,
          isEnabled: disconnectEnabled,
          onTap: disconnectEnabled ? () => unawaited(callbacks.onDisconnectPressed()) : null,
        ),
      );
      items.add(const TraySeparator());
      items.add(
        TrayButton(
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
          title: data.localization.addServer,
          onTap: () => unawaited(callbacks.onAddServerPressed()),
        ),
      );
    }

    items.addAll([
      TrayButton(
        title: data.localization.routing,
        onTap: () => unawaited(callbacks.onRoutingPressed()),
      ),
      TrayButton(
        title: data.localization.connectionLog,
        onTap: () => unawaited(callbacks.onConnectionLogPressed()),
      ),
      TrayButton(
        title: data.localization.logging,
        children: [
          TrayButton(
            title: data.localization.loggingLevel,
            children: [
              TrayButton(
                title: data.localization.loggingLevelBasic,
                isChecked: data.loggingLevel == LoggingLevel.defaultLevel,
                onTap: () => unawaited(
                  callbacks.onLoggingLevelPressed(LoggingLevel.defaultLevel),
                ),
              ),
              TrayButton(
                title: data.localization.loggingLevelDetailed,
                isChecked: data.loggingLevel == LoggingLevel.debug,
                onTap: () => unawaited(
                  callbacks.onLoggingLevelPressed(LoggingLevel.debug),
                ),
              ),
            ],
          ),
          TrayButton(
            title: data.localization.sensitiveData,
            children: [
              TrayButton(
                title: data.localization.sensitiveDataExcluded,
                isChecked: data.loggingSecurityType == LoggingSecurityType.stripped,
                onTap: () => unawaited(
                  callbacks.onLoggingSecurityTypePressed(LoggingSecurityType.stripped),
                ),
              ),
              TrayButton(
                title: data.localization.sensitiveDataIncluded,
                isChecked: data.loggingSecurityType == LoggingSecurityType.full,
                onTap: () => unawaited(
                  callbacks.onLoggingSecurityTypePressed(LoggingSecurityType.full),
                ),
              ),
            ],
          ),
          TrayButton(
            title: data.localization.deleteAppLogs,
            onTap: () => unawaited(callbacks.onDeleteLogsPressed()),
          ),
          TrayButton(
            title: data.localization.downloadAppLogs,
            onTap: () => unawaited(callbacks.onExportLogsPressed()),
          ),
        ],
      ),
      const TraySeparator(),
      TrayButton(
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
    ConnectionStateInTrayMenuMacOS state,
    AppLocalizations localization,
  ) => switch (state) {
    ConnectionStateInTrayMenuMacOS.connected => localization.trayStatusConnected,
    ConnectionStateInTrayMenuMacOS.connecting => localization.trayStatusConnecting,
    ConnectionStateInTrayMenuMacOS.disconnected => localization.trayStatusDisconnected,
  };
}
