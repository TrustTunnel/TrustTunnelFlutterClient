import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart';
import 'package:trusttunnel/data/database/migrations/migrations.dart';

class MigrationsV3 implements Migrations {
  static const _sniDivider = '|';

  const MigrationsV3();

  @override
  Future<void> migrate(GeneratedDatabase db, Migrator m) async {
    await m.addColumn(Servers(db), Servers(db).customSni);

    final servers = Servers(db);
    // Read only columns available at this migration step. Later schema
    // additions (such as sort_order in v5) do not exist yet.
    final serversWithSni =
        await (db.selectOnly(servers)
              ..addColumns([servers.id, servers.domain])
              ..where(servers.domain.contains(_sniDivider)))
            .get();

    for (final server in serversWithSni) {
      final parts = server.read(servers.domain)!.split(_sniDivider);
      if (parts.length != 2) {
        continue;
      }

      await (db.update(servers)..where((row) => row.id.equals(server.read(servers.id)!))).write(
        ServersCompanion(
          customSni: Value(parts[0]),
          domain: Value(parts[1]),
        ),
      );
    }
  }
}
