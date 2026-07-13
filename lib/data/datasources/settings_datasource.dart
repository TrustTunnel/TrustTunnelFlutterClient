/// {@template settings_data_source}
/// Persistence interface for application-level settings related to VPN.
///
/// This data source stores and retrieves settings that are not tied to a
/// particular server or routing profile. Currently it manages excluded routes
/// used in VPN/TUN configuration.
/// {@endtemplate}
abstract class SettingsDataSource {
  /// {@template settings_data_source_set_excluded_routes}
  /// Persists the list of routes excluded from VPN/TUN routing.
  ///
  /// Implementations may replace the stored list entirely.
  /// {@endtemplate}
  Future<void> setExcludedRoutes(List<String> routes);

  /// {@template settings_data_source_get_excluded_routes}
  /// Loads the currently stored excluded routes list.
  /// {@endtemplate}
  Future<List<String>> getExcludedRoutes();
}
