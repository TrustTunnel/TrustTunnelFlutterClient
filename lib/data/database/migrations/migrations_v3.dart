import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart';
import 'package:trusttunnel/data/database/migrations/migrations.dart';

class MigrationsV3 implements Migrations {
  static const _sniDivider = '|';

  const MigrationsV3();

  @override
  Future<void> migrate(GeneratedDatabase db, Migrator m) async {
    await m.addColumn(Servers(db), Servers(db).customSni);

    final serversWithSni = await db
        .customSelect(
          'SELECT id, domain FROM servers WHERE domain LIKE ?',
          variables: [Variable.withString('%$_sniDivider%')],
        )
        .get();

    await db.batch((batch) {
      for (final server in serversWithSni) {
        final parts = server.read<String>('domain').split(_sniDivider);
        if (parts.length != 2) {
          continue;
        }

        batch.customStatement(
          'UPDATE servers SET domain = ?, custom_sni = ? WHERE id = ?',
          [parts[1], parts[0], server.read<int>('id')],
        );
      }
    });
  }
}
