import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart' as db;
import 'package:trusttunnel/data/database/migrations/migrations.dart';

class MigrationsV5 implements Migrations {
  const MigrationsV5();

  @override
  Future<void> migrate(GeneratedDatabase database, Migrator m) async {
    final appDatabase = database as db.AppDatabase;
    await m.addColumn(appDatabase.servers, appDatabase.servers.tlsFingerprint);
  }
}
