import 'package:shared_preferences/shared_preferences.dart';
import 'package:trusttunnel/data/datasources/vpn_profile_server_datasource.dart';

final class VpnProfileServerDataSourceImpl implements VpnProfileServerDataSource {
  static const _serverIdKey = 'vpn_confirmed_profile_server_id';

  final SharedPreferences _preferences;

  VpnProfileServerDataSourceImpl({required this._preferences});

  @override
  Future<String?> getServerId() async => _preferences.getString(_serverIdKey);

  @override
  Future<bool> setServerId(String? serverId) =>
      serverId == null ? _preferences.remove(_serverIdKey) : _preferences.setString(_serverIdKey, serverId);
}
