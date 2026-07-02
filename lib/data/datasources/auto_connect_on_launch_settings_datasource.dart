abstract class AutoConnectOnLaunchSettingsDataSource {
  Future<bool> isEnabled();

  Future<void> enable();

  Future<void> disable();

  Future<String?> getLastServerId();

  Future<void> setLastServerId(String? serverId);
}
