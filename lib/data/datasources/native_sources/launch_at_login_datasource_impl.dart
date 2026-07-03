import 'package:flutter/services.dart';
import 'package:trusttunnel/data/datasources/launch_at_login_datasource.dart';

class LaunchAtLoginDataSourceImpl implements LaunchAtLoginDataSource {
  static const _defaultChannel = MethodChannel('trusttunnel/launch_at_login');

  final MethodChannel _channel;

  LaunchAtLoginDataSourceImpl({
    MethodChannel channel = _defaultChannel,
  }) : _channel = channel;

  @override
  Future<bool> isEnabled() async => await _channel.invokeMethod<bool>('isEnabled') ?? false;

  @override
  Future<void> setEnabled(bool enabled) => _channel.invokeMethod<void>(
    'setEnabled',
    <String, Object?>{
      'enabled': enabled,
    },
  );
}
