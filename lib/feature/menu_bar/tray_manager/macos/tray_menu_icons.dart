import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/common/assets/assets_images.dart';
import 'package:trusttunnel/feature/menu_bar/tray_manager/macos/tray_menu_data.dart';

final class TrayIcons {
  final TrayIcon connected;
  final TrayIcon connecting;
  final TrayIcon disconnected;

  const TrayIcons({
    required this.connected,
    required this.connecting,
    required this.disconnected,
  });

  TrayIcon iconFor(ConnectionStateInTrayMenuMacOS state) => switch (state) {
    ConnectionStateInTrayMenuMacOS.connected => connected,
    ConnectionStateInTrayMenuMacOS.connecting => connecting,
    ConnectionStateInTrayMenuMacOS.disconnected => disconnected,
  };

  static Future<TrayIcons> create() async => TrayIcons(
    connected: await _loadIcon(AssetImages.trayOn),
    connecting: await _loadIcon(AssetImages.trayLoading),
    disconnected: await _loadIcon(AssetImages.trayOff),
  );

  static Future<TrayIcon> _loadIcon(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);

    return TrayIcon(
      byteData.buffer.asUint8List(),
      isMonochrome: true,
    );
  }
}
