import 'package:drift/drift.dart';
import 'package:trusttunnel/data/database/app_database.dart';
import 'package:trusttunnel/data/database/migrations/migrations.dart';

class MigrationsV2 implements Migrations {
  const MigrationsV2();

  @override
  Future<void> migrate(GeneratedDatabase db, Migrator m) async {
    await m.createTable(
      CertificateTable(
        db,
      ),
    );

    await m.addColumn(Servers(db), Servers(db).tlsPrefix);
    await m.addColumn(Servers(db), Servers(db).ipv6Enabled);
  }
}
