import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/excluded_apps_datasource.dart';
import 'package:trusttunnel/data/model/installed_app.dart';

/// {@template excluded_apps_data_source_impl}
/// Drift-backed implementation of [ExcludedAppsDataSource].
///
/// Excluded packages are stored as a plain list of rows. Updates replace the
/// entire list (delete all + insert all).
/// {@endtemplate}
class ExcludedAppsDataSourceImpl implements ExcludedAppsDataSource {
  /// Drift database used for persistence.
  final db.AppDatabase database;

  /// Enumerates installed applications on the current platform.
  final Future<List<InstalledApp>> Function() installedAppsProvider;

  /// {@macro excluded_apps_data_source_impl}
  ExcludedAppsDataSourceImpl({
    required this.database,
    required this.installedAppsProvider,
  });

  @override
  Future<List<String>> getExcludedApps() async {
    final rows = await database.excludedApps.select().get();

    return rows.map((row) => row.packageName).toList();
  }

  @override
  Future<void> setExcludedApps(List<String> packages) async {
    await database.excludedApps.deleteAll();
    if (packages.isEmpty) {
      return;
    }

    await database.excludedApps.insertAll(
      packages.map((packageName) => db.ExcludedAppsCompanion.insert(packageName: packageName)),
      mode: InsertMode.insertOrIgnore,
    );
  }

  @override
  Future<List<InstalledApp>> getInstalledApps() => installedAppsProvider();
}
