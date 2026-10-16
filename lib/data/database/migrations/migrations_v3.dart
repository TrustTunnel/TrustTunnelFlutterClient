import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart';
import 'package:trusttunnel/data/database/migrations/migrations.dart';

class MigrationsV3 implements Migrations {
  static const _sniDivider = '|';

  const MigrationsV3();

  @override
  Future<void> migrate(GeneratedDatabase db, Migrator m) async {
    // Adds only custom_sni; other columns from the current Servers class are not required.
    await m.addColumn(Servers(db), Servers(db).customSni);

    // This step runs before v5 adds tls_fingerprint. Read historical columns
    // without mapping rows to the current Server model.
    final serversWithSni = await db
        .customSelect(
          'SELECT id, domain FROM servers WHERE domain LIKE ?',
          variables: [Variable.withString('%$_sniDivider%')],
        )
        .get();

    // Update only migrated fields: replacing a current Server would also write
    // columns that do not exist yet.
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
