abstract class LaunchAtLoginDataSource {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}
