import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/data/datasources/auto_connect_on_launch_settings_datasource.dart';

class AutoConnectOnLaunchSettingsDataSourceImpl implements AutoConnectOnLaunchSettingsDataSource {
  static const _enabledKey = 'auto_connect_on_launch_enabled';
  static const _lastServerIdKey = 'auto_connect_on_launch_last_server_id';

  final SharedPreferences _preferences;

  AutoConnectOnLaunchSettingsDataSourceImpl({
    required SharedPreferences preferences,
  }) : _preferences = preferences;

  @override
  Future<String?> getLastServerId() async => _preferences.getString(_lastServerIdKey);

  @override
  Future<bool> isEnabled() async => _preferences.getBool(_enabledKey) ?? false;

  @override
  Future<void> enable() => _preferences.setBool(_enabledKey, true);

  @override
  Future<void> disable() => _preferences.setBool(_enabledKey, false);

  @override
  Future<void> setLastServerId(String? serverId) async {
    if (serverId == null) {
      await _preferences.remove(_lastServerIdKey);

      return;
    }

    await _preferences.setString(_lastServerIdKey, serverId);
  }
}
