import 'package:drift/drift.dart';

abstract class Migrations {
  Future<void> migrate(GeneratedDatabase db, Migrator m);
}
