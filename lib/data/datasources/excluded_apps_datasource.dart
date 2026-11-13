import 'package:trusttunnel/data/model/installed_app.dart';

/// {@template excluded_apps_data_source}
/// Storage for the per-app VPN exclusions and a source of installed apps.
/// {@endtemplate}
abstract class ExcludedAppsDataSource {
  /// Returns the persisted list of excluded package names.
  Future<List<String>> getExcludedApps();

  /// Replaces the persisted list of excluded package names.
  Future<void> setExcludedApps(List<String> packages);

  /// Returns applications installed on the device.
  ///
  /// Returns an empty list on platforms without per-app tunneling support.
  Future<List<InstalledApp>> getInstalledApps();
}
