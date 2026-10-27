import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/data/datasources/open_main_window_on_login_datasource.dart';

class OpenMainWindowOnLoginDataSourceImpl implements OpenMainWindowOnLoginDataSource {
  static const _macOSmainWindowChannel = MethodChannel('trusttunnel/macos_main_window');
  static const _windowsMainWindowChannel = MethodChannel('trusttunnel/windows_main_window');

  MethodChannel get _channel => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => _macOSmainWindowChannel,
    TargetPlatform.windows => _windowsMainWindowChannel,
    _ => throw UnsupportedError('OpenMainWindowOnLoginDataSource is only supported on macOS and Windows'),
  };

  @override
  Future<bool> isEnabled() async => await _channel.invokeMethod<bool>('getOpenMainWindowOnLogin') ?? false;

  @override
  Future<void> setEnabled(bool enabled) async {
    await _channel.invokeMethod<void>(
      'setOpenMainWindowOnLogin',
      <String, Object?>{
        'enabled': enabled,
      },
    );
  }
}
