import 'package:drift/drift.dart';
import 'package:vpn/data/database/app_database.dart' as db;
import 'package:vpn/data/datasources/settings_datasource.dart';

class SettingsDataSourceImpl implements SettingsDataSource {
  final db.AppDatabase database;

  SettingsDataSourceImpl({required this.database});

  @override
  Future<List<String>> getExcludedRoutes() async {
    final unparsedResult = await database.excludedRoutes.select().get();

    return unparsedResult.map((e) => e.value).toList();
  }

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
