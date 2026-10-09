import 'dart:async';
import 'dart:ui' show AppExitType;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/common/error/model/presentation_exception.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/common/logging/enum/logging_level.dart';
import 'package:trusttunnel/common/logging/enum/logging_security_type.dart';
import 'package:trusttunnel/common/router/app_route.dart';
import 'package:trusttunnel/common/router/app_routes.dart';
import 'package:trusttunnel/data/model/server.dart';
import 'package:trusttunnel/data/model/vpn_state.dart';
import 'package:trusttunnel/feature/app/controller/app_window_controller.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_state.dart';
import 'package:trusttunnel/feature/tray_menu/platform/macos/macos_tray_menu_items_builder.dart';
import 'package:trusttunnel/feature/tray_menu/platform/tray_menu_builder.dart';
import 'package:trusttunnel/feature/tray_menu/platform/windows/windows_tray_menu_items_builder.dart';

/// Prepares connection parameters before calling [onReady].
/// Returning false from [onReady] skips starting VPN after selecting another server.
typedef TrayMenuConnectCallback = Future<void> Function(Server server, {required bool Function() onReady});

/// Handles tray actions and synchronizes native state independently of Flutter frames.
final class TrayMenuController {
  final ValueListenable<TrayMenuState> _sources;
  final TrayMenuConnectCallback _connectVpn;
  final AsyncCallback _disconnectVpn;
  final ValueChanged<String?> _pickServer;
  final ValueChanged<LoggingLevel> _updateLoggingLevel;
  final ValueChanged<LoggingSecurityType> _updateSecurityType;
  final void Function({VoidCallback? onError, VoidCallback? onCancelled}) _exportLogsCallback;
  final void Function({VoidCallback? onError}) _deleteLogsCallback;
  final TrayMenuBuilder _trayMenuBuilder;
  final AppWindowController _windowController;
  final Future<void> Function(AppRoute route) _onRouteRequested;
  final void Function({bool canceled}) _onMessage;

  TrayMenuController({
    required this._sources,
    required TrayMenuConnectCallback connect,
    required AsyncCallback disconnect,
    required this._pickServer,
    required this._updateLoggingLevel,
    required this._updateSecurityType,
    required void Function({VoidCallback? onError, VoidCallback? onCancelled}) exportLogs,
    required void Function({VoidCallback? onError}) deleteLogs,
    required this._localization,
    required this._windowController,
    required this._onRouteRequested,
    required this._onMessage,
  }) : _connectVpn = connect,
       _disconnectVpn = disconnect,
       _exportLogsCallback = exportLogs,
       _deleteLogsCallback = deleteLogs,
       _trayMenuBuilder = TrayMenuBuilder(
         itemsBuilder: switch (defaultTargetPlatform) {
           TargetPlatform.macOS => const MacosTrayMenuItemsBuilder(),
           TargetPlatform.windows => const WindowsTrayMenuItemsBuilder(),
           _ => throw UnsupportedError('Tray menu is not supported on $defaultTargetPlatform'),
         },
         onNativeError: (error) => _reportBackgroundError(error, StackTrace.current),
       ) {
    _callbacks = TrayMenuCallbacks(
      onAddServerPressed: () => _runTrayMenuAction(() => _route(AppRoutes.serverDetails)),
      onOpenTrustTunnelPressed: () => _runTrayMenuAction(_windowController.showMainWindow),
      onRoutingPressed: () => _runTrayMenuAction(() => _route(AppRoutes.routing)),
      onConnectionLogPressed: () => _runTrayMenuAction(() => _route(AppRoutes.queryLog)),
      onConnectPressed: () => _runTrayMenuAction(_connect),
      onDisconnectPressed: () => _runTrayMenuAction(_disconnectVpn),
      onConnectToServerPressed: (id) => _runTrayMenuAction(() => _connectToServerId(id)),
      onOtherServersPressed: () => _runTrayMenuAction(() => _route(AppRoutes.servers)),
      onLoggingLevelPressed: (level) => _runTrayMenuAction(() async => _updateLoggingLevel(level)),
      onLoggingSecurityTypePressed: (type) => _runTrayMenuAction(() async => _updateSecurityType(type)),
      onDeleteLogsPressed: () => _runTrayMenuAction(_deleteLogs),
      onExportLogsPressed: () => _runTrayMenuAction(_exportLogs),
      onQuitPressed: () => _runTrayMenuAction(_quit),
    );
    _sources.addListener(_onSourcesChanged);
    _enqueueSync();
  }

  static void _reportBackgroundError(Object error, StackTrace stackTrace) => FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'tray menu',
    ),
  );

  late final TrayMenuCallbacks _callbacks;
  AppLocalizations _localization;
  Future<void> _syncQueue = Future<void>.value();
  bool _isDisposed = false;
  bool _syncErrorReported = false;
  Timer? _retryTimer;
  Object? _lastServerError;
  Object? _lastLoggingError;
  String? _lastConnectedServerId;

  void updateLocalization(AppLocalizations localization) {
    _localization = localization;
    _enqueueSync();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _retryTimer?.cancel();
    _sources.removeListener(_onSourcesChanged);

    // Wait for native initialization/update before deleting its resources.
    await _syncQueue;
    await _trayMenuBuilder.dispose();
  }

  Future<void> _runTrayMenuAction(AsyncCallback action) async {
    if (_isDisposed) {
      return;
    }
    try {
      await action();
    } catch (error, stackTrace) {
      await _onError(error, stackTrace);
    }
  }

  Future<void> _route(AppRoute route) async {
    await _windowController.showMainWindow();
    if (!_isDisposed) {
      await _onRouteRequested(route);
    }
  }

  Future<void> _deleteLogs() async => _deleteLogsCallback(onError: () => unawaited(_showMessage()));

  Future<void> _exportLogs() async {
    await _windowController.showMainWindow();
    if (_isDisposed) {
      return;
    }
    _exportLogsCallback(
      onCancelled: () => unawaited(_showMessage(canceled: true)),
      onError: () => unawaited(_showMessage()),
    );
  }

  Future<void> _quit() async => await ServicesBinding.instance.exitApplication(AppExitType.cancelable);

  Future<void> _onError(Object error, StackTrace stack) async {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'tray menu',
      ),
    );

    await _showMessage();
  }

  Future<void> _showMessage({bool canceled = false}) async {
    if (_isDisposed) {
      return;
    }

    await _windowController.showMainWindow();
    if (!_isDisposed) {
      _onMessage(canceled: canceled);
    }
  }

  void _onSourcesChanged() {
    if (_isDisposed) {
      return;
    }

    final state = _sources.value;
    final serverError = state.serverError;
    final loggingError = state.loggingError;

    final List<PresentationException> errorsForReporting = [
      if (serverError != null && serverError != _lastServerError) serverError,
      if (loggingError != null && loggingError != _lastLoggingError) loggingError,
    ];
    for (final error in errorsForReporting) {
      unawaited(
        _onError(error, StackTrace.current),
      );
    }

    _lastServerError = serverError;
    _lastLoggingError = loggingError;
    _enqueueSync();
  }

  /// Sequential asynchronous update queue for the tray menu.
  ///
  /// It handles the synchronization of menu and icons, but not all actions involving the tray menu.
  /// Connecting to a VPN, exporting logs, and other actions are handled via [_runTrayMenuAction].
  void _enqueueSync() {
    if (_isDisposed) {
      return;
    }
    _retryTimer?.cancel();

    _syncQueue = _syncQueue
        .then((_) async {
          if (_isDisposed) {
            return;
          }

          try {
            await _trayMenuBuilder.synchronizeMenu(data: _prepareTrayMenuData(), callbacks: _callbacks);
            _syncErrorReported = false;
          } catch (error, stackTrace) {
            if (_isDisposed) {
              return;
            }

            _retryTimer?.cancel();
            _retryTimer = Timer(const Duration(seconds: 5), _enqueueSync);

            if (!_syncErrorReported) {
              _syncErrorReported = true;
              _reportBackgroundError(error, stackTrace);
            }
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          // Report and resolve this Future so later menu synchronizations can still run.
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stackTrace));
        });
  }

  Future<void> _connect() async {
    final targetServer = _resolveCurrentTargetServer();
    if (targetServer != null) {
      await _connectToServer(targetServer);
    }
  }

  Future<void> _connectToServerId(String serverId) async {
    final targetServer = _sources.value.servers.firstWhereOrNull((server) => server.id == serverId);
    if (targetServer != null) {
      await _connectToServer(targetServer);
    }
  }

  /// Builds a tray menu snapshot from live tray data and localization.
  TrayMenuData _prepareTrayMenuData() {
    final state = _sources.value;
    final vpnState = state.vpnState;
    final servers = state.servers;
    final selectedServer = state.selectedServer;
    final connectionState = _mapConnectionStateForTray(vpnState);
    final activeServer = _resolveActiveServer(
      connectionState: connectionState,
      servers: servers,
      selectedServer: selectedServer,
    );

    return TrayMenuData(
      localization: _localization,
      connectionState: connectionState,
      activeServerId: activeServer?.id,
      activeServerName: activeServer?.serverData.name,
      servers: servers,
      loggingLevel: state.loggingLevel,
      loggingSecurityType: state.loggingSecurityType,
    );
  }

  /// Remembers the server once connection parameters are ready.
  Future<void> _connectToServer(Server server) => _connectVpn(
    server,
    onReady: () {
      _lastConnectedServerId = server.id;
      _enqueueSync();

      if (_sources.value.selectedServer?.id != server.id) {
        _pickServer(server.id);

        return false;
      }

      return true;
    },
  );

  Server? _resolveCurrentTargetServer() {
    final state = _sources.value;

    return _resolveActiveServer(
      connectionState: _mapConnectionStateForTray(state.vpnState),
      servers: state.servers,
      selectedServer: state.selectedServer,
    );
  }

  /// Resolves the server shown by the tray, preserving the active server across states.
  Server? _resolveActiveServer({
    required TrayMenuConnectionState connectionState,
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
      case TrayMenuConnectionState.connected:
      case TrayMenuConnectionState.connecting:
        final activeServer = selectedServer ?? cachedServer ?? servers.first;
        _lastConnectedServerId = activeServer.id;

        return activeServer;
      case TrayMenuConnectionState.disconnected:
        return cachedServer ?? fallbackServer;
    }
  }

  /// Maps detailed VPN recovery states to the tray's simplified connection state.
  TrayMenuConnectionState _mapConnectionStateForTray(VpnState state) => switch (state) {
    VpnState.connected => TrayMenuConnectionState.connected,
    VpnState.disconnected => TrayMenuConnectionState.disconnected,
    VpnState.connecting ||
    VpnState.waitingForRecovery ||
    VpnState.recovering ||
    VpnState.waitingForNetwork => TrayMenuConnectionState.connecting,
  };
}
