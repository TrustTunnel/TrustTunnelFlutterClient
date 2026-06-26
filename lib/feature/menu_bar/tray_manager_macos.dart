import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/common/localization/generated/l10n.dart';
import 'package:trusttunnel/data/model/server.dart';

final class TrayManagerMacOS {
  static const _topLevelServerLimit = 10;

  final TrayManagerApi _trayManager;

  _TrayIcons? _trayIcons;
  bool _isTrayInitialized = false;
  bool _isTrayAvailable = true;

  TrayManagerMacOS({
    TrayManagerApi? trayManager,
  }) : _trayManager = trayManager ?? TrayManagerApi();

  Future<void> sync({
    required TrayMenuData data,
    required AsyncCallback onQuitPressed,
  }) async {
    if (!_isTrayAvailable) {
      return;
    }

    try {
      final trayIcons = await _ensureTrayIcons();
      final trayItems = _buildTrayItems(
        data,
        onQuitPressed: onQuitPressed,
      );

      if (!_isTrayInitialized) {
        await _trayManager.initTray(trayItems);
        _isTrayInitialized = true;
      } else {
        await _trayManager.updateMenu(trayItems);
      }

      await _trayManager.setTrayIcon(
        trayIcons.iconFor(data.connectionState),
      );
    } catch (error, stackTrace) {
      _isTrayAvailable = false;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'tray_manager_macos',
          context: ErrorDescription('while syncing macOS tray menu'),
        ),
      );
    }
  }

  Future<void> dispose() => _trayManager.dispose();

  Future<_TrayIcons> _ensureTrayIcons() async {
    final existingIcons = _trayIcons;
    if (existingIcons != null) {
      return existingIcons;
    }

    final icons = await _TrayIcons.create();
    _trayIcons = icons;
    return icons;
  }

  List<TrayItem> _buildTrayItems(
    TrayMenuData data, {
    required AsyncCallback onQuitPressed,
  }) {
    final items = <TrayItem>[];

    if (data.hasServers) {
      items.add(
        TrayStatus(title: 'Status: ${data.connectionState.title}'),
      );
      items.add(
        TrayButton(
          title: data.selectedServerName!,
          onTap: _noop,
        ),
      );
      items.add(const TrayButton(title: 'Connect', onTap: _noop));
      items.add(const TrayButton(title: 'Disconnect', onTap: _noop));
      items.add(
        TrayButton(
          title: 'Connect to',
          children: _buildServerItems(
            data.servers,
            data.selectedServerName!,
          ),
        ),
      );
    } else {
      items.add(
        TrayButton(
          title: data.localization.addServer,
          onTap: _noop,
        ),
      );
    }

    items.addAll([
      TrayButton(
        title: data.localization.routing,
        onTap: _noop,
      ),
      const TrayButton(
        title: 'Connection log',
        onTap: _noop,
      ),
      const TrayButton(
        title: 'Logging',
        children: [
          TrayButton(
            title: 'Logging level',
            children: [
              TrayButton(title: 'Default', onTap: _noop),
              TrayButton(title: 'Debug', onTap: _noop),
            ],
          ),
          TrayButton(
            title: 'Sensitive data',
            children: [
              TrayButton(title: 'Stripped', onTap: _noop),
              TrayButton(title: 'Included', onTap: _noop),
            ],
          ),
          TrayButton(
            title: 'Delete app logs',
            onTap: _noop,
          ),
          TrayButton(
            title: 'Export logs and system info',
            onTap: _noop,
          ),
        ],
      ),
      TrayButton(
        title: '${data.localization.quit} TrustTunnel',
        onTap: () => unawaited(onQuitPressed()),
      ),
    ]);

    return items;
  }

  List<TrayItem> _buildServerItems(
    List<Server> servers,
    String selectedServerName,
  ) {
    final topLevelServers = servers.take(_topLevelServerLimit).toList();
    final remainingServers = servers.skip(_topLevelServerLimit).toList();
    final items = topLevelServers
        .map(
          (server) => TrayButton(
            title: server.serverData.name,
            isChecked: server.serverData.name == selectedServerName,
            onTap: _noop,
          ),
        )
        .cast<TrayItem>()
        .toList();

    if (remainingServers.isEmpty) {
      return items;
    }

    items.add(
      TrayButton(
        title: 'Other servers',
        children: remainingServers
            .map(
              (server) => TrayButton(
                title: server.serverData.name,
                isChecked: server.serverData.name == selectedServerName,
                onTap: _noop,
              ),
            )
            .toList(),
      ),
    );

    return items;
  }

  static void _noop() {}
}

enum TrayConnectionState {
  connected(
    title: 'Connected',
    badgeColor: Color(0xFF34C759),
  ),
  connecting(
    title: 'Connecting...',
    badgeColor: Color(0xFFFF9F0A),
  ),
  disconnected(
    title: 'Disconnected',
    badgeColor: Color(0xFFFF453A),
  )
  ;

  final String title;
  final Color badgeColor;

  const TrayConnectionState({
    required this.title,
    required this.badgeColor,
  });
}

final class TrayMenuData {
  final AppLocalizations localization;
  final TrayConnectionState connectionState;
  final String? selectedServerName;
  final List<Server> servers;

  const TrayMenuData({
    required this.localization,
    required this.connectionState,
    required this.selectedServerName,
    required this.servers,
  });

  bool get hasServers => selectedServerName != null;
}

final class _TrayIcons {
  final TrayIcon connected;
  final TrayIcon connecting;
  final TrayIcon disconnected;

  const _TrayIcons({
    required this.connected,
    required this.connecting,
    required this.disconnected,
  });

  TrayIcon iconFor(TrayConnectionState state) => switch (state) {
    TrayConnectionState.connected => connected,
    TrayConnectionState.connecting => connecting,
    TrayConnectionState.disconnected => disconnected,
  };

  static Future<_TrayIcons> create() async => _TrayIcons(
    connected: TrayIcon(
      await _buildPng(TrayConnectionState.connected),
    ),
    connecting: TrayIcon(
      await _buildPng(TrayConnectionState.connecting),
    ),
    disconnected: TrayIcon(
      await _buildPng(TrayConnectionState.disconnected),
    ),
  );

  static Future<Uint8List> _buildPng(TrayConnectionState state) async {
    const size = 18.0;
    const outputSize = 36;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final shieldPaint = Paint()..color = const Color(0xFF1F2937);

    final shield = ui.Path()
      ..moveTo(size * 0.5, size * 0.08)
      ..lineTo(size * 0.78, size * 0.2)
      ..lineTo(size * 0.78, size * 0.5)
      ..cubicTo(size * 0.78, size * 0.72, size * 0.64, size * 0.9, size * 0.5, size * 0.96)
      ..cubicTo(size * 0.36, size * 0.9, size * 0.22, size * 0.72, size * 0.22, size * 0.5)
      ..lineTo(size * 0.22, size * 0.2)
      ..close();

    canvas.drawPath(shield, shieldPaint);

    final badgeCenter = const Offset(0.72, 0.72).scale(size, size);
    final badgeRadius = size * 0.18;
    final badgePaint = Paint()..color = state.badgeColor;
    canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);

    final badgeSymbolPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (state) {
      case TrayConnectionState.connected:
        final path = ui.Path()
          ..moveTo(size * 0.65, size * 0.72)
          ..lineTo(size * 0.7, size * 0.77)
          ..lineTo(size * 0.8, size * 0.67);
        canvas.drawPath(path, badgeSymbolPaint);
      case TrayConnectionState.connecting:
        final fillPaint = Paint()..color = Colors.white;
        for (final dx in [-0.08, 0.0, 0.08]) {
          canvas.drawCircle(
            Offset(size * (0.72 + dx), size * 0.72),
            size * 0.025,
            fillPaint,
          );
        }
      case TrayConnectionState.disconnected:
        canvas.drawLine(
          const Offset(0.65, 0.65).scale(size, size),
          const Offset(0.79, 0.79).scale(size, size),
          badgeSymbolPaint,
        );
        canvas.drawLine(
          const Offset(0.79, 0.65).scale(size, size),
          const Offset(0.65, 0.79).scale(size, size),
          badgeSymbolPaint,
        );
    }

    final image = await recorder.endRecording().toImage(outputSize, outputSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw StateError('Failed to create tray icon PNG bytes.');
    }

    return byteData.buffer.asUint8List();
  }
}
