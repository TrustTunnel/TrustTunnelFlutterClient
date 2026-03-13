import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart';
import 'package:trusttunnel/data/database/migrations/migrations.dart';

class MigrationsV3 implements Migrations {
  static const _sniDivider = '|';

  const MigrationsV3();

  @override
  Future<void> migrate(GeneratedDatabase db, Migrator m) async {
    await m.addColumn(Servers(db), Servers(db).customSni);

    final serversWithSni =
        await (db.select(Servers(db))..where(
              (s) => s.domain.contains(_sniDivider),
            ))
            .get();

    final List<Server> updatingRows = [];

    for (final server in serversWithSni) {
      final parts = server.domain.split(_sniDivider);
      if (parts.length != 2) {
        continue;
      }

      updatingRows.add(
        server.copyWith(
          customSni: Value(parts[0]),
          domain: parts[1],
        ),
      );
    }

    await db.batch(
      (batch) => batch.replaceAll(Servers(db), updatingRows),
    );
  }
}
