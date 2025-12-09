abstract class SettingsDataSource {
  Future<void> setExcludedRoutes(List<String> routes);

  Future<List<String>> getExcludedRoutes();
}
