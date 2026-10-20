import 'package:flutter/services.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:trusttunnel/common/constants/app_constants.dart';
import 'package:trusttunnel/feature/tray_menu/model/tray_menu_data.dart';
import 'package:trusttunnel/feature/tray_menu/platform/tray_menu_icons.dart';
import 'package:trusttunnel/feature/tray_menu/platform/tray_menu_items_builder.dart';

/// Synchronizes the native tray using platform-specific menu items.
final class TrayMenuBuilder {
  final TrayManagerApi _trayManagerApi;
  final TrayMenuItemsBuilder _itemsBuilder;

  TrayMenuBuilder({
    required this._itemsBuilder,
    TrayManagerApi? trayManager,
    void Function(PlatformException error)? onNativeError,
  }) : _trayManagerApi = trayManager ?? TrayManagerApi(onNativeError: onNativeError);

  bool _isMenuPrepared = false;
  TrayMenuIcons? _trayIcons;

  bool get isMenuPrepared => _isMenuPrepared;

  /// Synchronizes the tray menu with the given [TrayMenuData] and [TrayMenuCallbacks], uses [TrayManagerApi].
  ///
  /// Initializes the tray menu if it is not prepared yet.
  Future<void> synchronizeMenu({
    required TrayMenuData data,
    required TrayMenuCallbacks callbacks,
  }) async {
    final trayIcons = await _ensureTrayMenuIcons();
    final trayItems = _itemsBuilder.build(
      data: data,
      callbacks: callbacks,
    );

    if (!_isMenuPrepared) {
      await _trayManagerApi.initTray(trayItems);
      _isMenuPrepared = true;
    } else {
      await _trayManagerApi.updateMenu(trayItems);
    }
    await _trayManagerApi.setTrayIcon(
      trayIcons.iconFor(data.connectionState),
      tooltip: '${AppConstants.appName} — ${data.labels.connectionTitles[data.connectionState]}',
    );
  }

  Future<void> dispose() async {
    await _trayManagerApi.dispose();
    _isMenuPrepared = false;
  }

  Future<TrayMenuIcons> _ensureTrayMenuIcons() async {
    final existingIcons = _trayIcons;
    if (existingIcons != null) {
      return existingIcons;
    }

    final icons = await TrayMenuIcons.create();
    _trayIcons = icons;

    return icons;
  }
}
