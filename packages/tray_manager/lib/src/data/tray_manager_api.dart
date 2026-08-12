import 'package:tray_manager/src/model/tray_icon.dart';
import 'package:tray_manager/src/model/tray_item.dart';
import 'package:tray_manager/src/model/tray_item_to_map_converter.dart';
import 'package:tray_manager/src/platform/tray_api.dart';
import 'package:tray_manager/src/platform/tray_callback_api.dart';
import 'package:tray_manager/src/platform/tray_callback_handler.dart';

const _kChannelPrefix = 'tray_manager';

/// {@template tray_manager_api}
/// High-level API for managing desktop system tray.
///
/// Provides methods to initialize, update, and dispose the tray icon and menu.
/// Supports macOS. Only one instance can be active at a time.
///
/// Usage:
/// ```dart
/// final api = TrayManagerApi();
/// await api.initTray([TrayButton(title: 'Quit', onTap: () => exit(0))]);
/// await api.setTrayIcon(TrayIcon(pngBytes));
/// ```
/// {@endtemplate}
final class TrayManagerApi {
  /// Currently active instance. Only one instance can receive callbacks.
  static TrayManagerApi? _activeInstance;

  /// Low-level platform API.
  final TrayApi _api;

  /// Converts [TrayItem] tree to native format and stores callbacks.
  final TrayItemConverter _converter;

  /// Optional error handler for callback exceptions.
  final void Function(Object, StackTrace)? _onError;

  TrayManagerApi({
    TrayApi? api,
    void Function(Object, StackTrace)? onError,
  }) : _onError = onError,
       _api = api ?? TrayApi(_kChannelPrefix),
       _converter = TrayItemConverter() {
    _becomeActive();
  }

  /// Initializes the tray with the given menu [items].
  ///
  /// Creates the tray icon and context menu. Call [setTrayIcon] to set the icon.
  /// Invoke only on macOS.
  Future<void> initTray(List<TrayItem> items) async {
    _becomeActive();
    await _api.initTray(_convertItems(items));
  }

  /// Updates the tray context menu with new [items].
  ///
  /// Replaces the entire menu. Invoke only on macOS.
  Future<void> updateMenu(List<TrayItem> items) async {
    _becomeActive();
    await _api.updateMenu(_convertItems(items));
  }

  /// Sets the tray icon from PNG bytes.
  ///
  /// On macOS, [TrayIcon.isMonochrome] enables template mode for dark/light adaptation.
  Future<void> setTrayIcon(TrayIcon icon) async {
    await _api.setTrayIconPng(icon.bytes, icon.isMonochrome);
  }

  /// Disposes the tray and stops receiving callbacks.
  ///
  /// Only disposes native resources if this is the active instance.
  Future<void> dispose() async {
    final isActive = identical(_activeInstance, this);

    if (isActive) {
      await _api.disposeTray();
      TrayCallbackApiSetup.setUp(_kChannelPrefix, null);
      _activeInstance = null;
    }

    _converter.reset();
  }

  /// Dispatches a menu item click by [id] to the registered callback.
  void _dispatchCallback(String id) {
    final callback = _converter.callbacks[id];
    try {
      callback?.call();
    } catch (e, st) {
      _onError?.call(e, st);
    }
  }

  /// Converts [TrayItem] list to native format, resetting previous callbacks.
  List<Map<String, Object?>> _convertItems(List<TrayItem> items) {
    _converter.reset();

    return items
        .map(
          _converter.convert,
        )
        .toList();
  }

  /// Makes this instance the active one, receiving all callbacks.
  ///
  /// Deactivates any previously active instance.
  void _becomeActive() {
    if (!identical(_activeInstance, this)) {
      _activeInstance?._stopReceivingClicks();
      _activeInstance = this;
    }

    TrayCallbackApiSetup.setUp(
      _kChannelPrefix,
      TrayCallbackHandler(_dispatchCallback),
    );
  }

  /// Stops this instance from receiving click callbacks.
  void _stopReceivingClicks() {
    TrayCallbackApiSetup.setUp(_kChannelPrefix, null);
  }
}
