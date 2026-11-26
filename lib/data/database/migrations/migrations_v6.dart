import 'package:drift/drift.dart';
import 'package:trusttunnel/common/utils/routing_profile_utils.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/database/migrations/migrations.dart';

/// Removes the old seeded name so the built-in profile can use the current locale.
class MigrationsV6 implements Migrations {
  const MigrationsV6();

  @override
  Future<void> migrate(GeneratedDatabase database, Migrator m) async {
    final appDatabase = database as db.AppDatabase;
    final builtInProfileId = int.parse(RoutingProfileUtils.defaultRoutingProfileId);
    await (appDatabase.update(appDatabase.routingProfiles)..where(
          (table) => table.id.equals(builtInProfileId) & table.name.equals('Default profile'),
        ))
        .write(const db.RoutingProfilesCompanion(name: Value('')));
  }
}
