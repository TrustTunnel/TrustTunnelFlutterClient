import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/datasources/settings_datasource.dart';

/// {@template settings_data_source_impl}
/// Drift-backed implementation of [SettingsDataSource].
///
/// Excluded routes are stored as a plain list of string rows. Updates replace
/// the entire list (delete all + insert all).
/// {@endtemplate}
class SettingsDataSourceImpl implements SettingsDataSource {
  /// Drift database used for persistence.
  final db.AppDatabase database;

  /// {@macro settings_data_source_impl}
  SettingsDataSourceImpl({required this.database});

  /// {@macro settings_data_source_get_excluded_routes}
  @override
  Future<List<String>> getExcludedRoutes() async {
    final unparsedResult = await database.excludedRoutes.select().get();

    return unparsedResult.map((e) => e.value).toList();
  }

  /// {@macro settings_data_source_set_excluded_routes}
  ///
  /// The stored list is replaced atomically from the perspective of this method:
  /// all existing rows are removed, then the new set is inserted.
  @override
  Future<void> setExcludedRoutes(List<String> routes) async {
    await database.excludedRoutes.deleteAll();
    await database.excludedRoutes.insertAll(
      routes.map(
        (e) => db.ExcludedRoutesCompanion.insert(
          value: e,
        ),
      ),
    );
  }
}
