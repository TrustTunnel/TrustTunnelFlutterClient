import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:trusttunnel/data/datasources/open_main_window_on_login_datasource.dart';

class OpenMainWindowOnLoginDataSourceImpl implements OpenMainWindowOnLoginDataSource {
  static const _macOSmainWindowChannel = MethodChannel('trusttunnel/macos_main_window');

  @override
  Future<bool> isEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _throwUnsupportedError();
    }

    return await _macOSmainWindowChannel.invokeMethod<bool>('getOpenMainWindowOnLogin') ?? false;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      _throwUnsupportedError();
    }

    await _macOSmainWindowChannel.invokeMethod<void>(
      'setOpenMainWindowOnLogin',
      <String, Object?>{
        'enabled': enabled,
      },
    );
  }

  Never _throwUnsupportedError() =>
      throw UnsupportedError('OpenMainWindowOnLoginDataSource currently is only supported on macOS');
}
