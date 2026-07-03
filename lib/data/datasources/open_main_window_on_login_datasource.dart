abstract class OpenMainWindowOnLoginDataSource {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}
