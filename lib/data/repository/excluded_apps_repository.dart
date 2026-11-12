import 'package:trusttunnel/data/datasources/excluded_apps_datasource.dart';
import 'package:trusttunnel/data/model/installed_app.dart';

/// {@template excluded_apps_repository}
/// Repository for the per-app VPN exclusions.
/// {@endtemplate}
abstract class ExcludedAppsRepository {
  /// Returns the persisted list of excluded package names.
  Future<List<String>> getExcludedApps();

  /// Replaces the persisted list of excluded package names.
  Future<void> setExcludedApps(List<String> packages);

  /// Returns applications installed on the device.
  Future<List<InstalledApp>> getInstalledApps();
}

/// {@template excluded_apps_repository_impl}
/// Default implementation of [ExcludedAppsRepository].
/// {@endtemplate}
class ExcludedAppsRepositoryImpl implements ExcludedAppsRepository {
  final ExcludedAppsDataSource _dataSource;

  /// {@macro excluded_apps_repository_impl}
  ExcludedAppsRepositoryImpl(this._dataSource);

  @override
  Future<List<String>> getExcludedApps() => _dataSource.getExcludedApps();

  @override
  Future<void> setExcludedApps(List<String> packages) => _dataSource.setExcludedApps(packages);

  @override
  Future<List<InstalledApp>> getInstalledApps() => _dataSource.getInstalledApps();
}
