import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';

final class TrayMenuIcons {
  final TrayIcon connected;
  final TrayIcon connecting;
  final TrayIcon disconnected;

  const TrayMenuIcons({
    required this.connected,
    required this.connecting,
    required this.disconnected,
  });

  static Future<TrayMenuIcons> create() async => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => TrayMenuIcons(
      connected: await _loadIcon(AssetImages.trayMacosOn, isMonochrome: true),
      connecting: await _loadIcon(AssetImages.trayMacosLoading, isMonochrome: true),
      disconnected: await _loadIcon(AssetImages.trayMacosOff, isMonochrome: true),
    ),
    TargetPlatform.windows => TrayMenuIcons(
      connected: await _loadIcon(AssetImages.trayWindowsOn),
      connecting: await _loadIcon(AssetImages.trayWindowsLoading),
      disconnected: await _loadIcon(AssetImages.trayWindowsOff),
    ),
    _ => throw UnsupportedError('Tray menu is not supported on $defaultTargetPlatform'),
  };

  static Future<TrayIcon> _loadIcon(String assetPath, {bool isMonochrome = false}) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

    return TrayIcon(bytes, isMonochrome: isMonochrome);
  }

  TrayIcon iconFor(TrayMenuConnectionState state) => switch (state) {
    TrayMenuConnectionState.connected => connected,
    TrayMenuConnectionState.connecting => connecting,
    TrayMenuConnectionState.disconnected => disconnected,
  };
}
