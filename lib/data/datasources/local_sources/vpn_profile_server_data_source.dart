import 'package:shared_preferences/shared_preferences.dart';

abstract interface class VpnProfileServerDataSource {
  String? get serverId;

  Future<bool> setServerId(String? serverId);
}

final class VpnProfileServerDataSourceImpl implements VpnProfileServerDataSource {
  static const _serverIdKey = 'vpn_confirmed_profile_server_id';

  final SharedPreferences _preferences;

  VpnProfileServerDataSourceImpl({required this._preferences});

  @override
  String? get serverId => _preferences.getString(_serverIdKey);

  @override
  Future<bool> setServerId(String? serverId) =>
      serverId == null ? _preferences.remove(_serverIdKey) : _preferences.setString(_serverIdKey, serverId);
}
