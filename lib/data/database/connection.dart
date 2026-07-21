import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:trusttunnel/data/database/database_key_manager.dart';
import 'package:trusttunnel/data/database/interceptors/db_log_interceptor.dart';

Future<File> get databaseFile async {
  final dbFolder = await _getDbContainmentFolder();
  final file = File(p.join(dbFolder.path, 'vpn_oss_db.sqlite'));

  return file;
}

/// Checks that the bundled sqlite3 library is SQLite3MultipleCiphers,
/// which provides the `cipher` pragma (absent in upstream SQLite).
bool _debugCheckHasCipher(Database database) => database.select('PRAGMA cipher;').isNotEmpty;

/// Returns the database encryption key (app id), generating a new one if
/// it is missing.
///
/// When a new app id is generated, the existing database is deleted (it
/// can no longer be decrypted without a key), so a new encrypted database
/// is created with the new key.
Future<String> _obtainDatabaseKey(DatabaseKeyManager keyManager, File databaseFile) async {
  final existingAppId = keyManager.getAppId();
  if (existingAppId != null) {
    return existingAppId;
  }

  await _clearDatabase(databaseFile);

  final appId = keyManager.generateAppId();
  await keyManager.setAppId(appId);

  return appId;
}

Future<void> _clearDatabase(File databaseFile) async {
  final relatedFiles = [
    databaseFile,
    File('${databaseFile.path}-wal'),
    File('${databaseFile.path}-shm'),
    File('${databaseFile.path}-journal'),
  ];

  for (final file in relatedFiles) {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Obtains an encrypted database connection for running drift in a Dart VM.
///
/// The encryption key is the app id provided by [keyManager] and is applied
/// via `PRAGMA key` before the database is used.
DatabaseConnection connect(DatabaseKeyManager keyManager) => DatabaseConnection.delayed(
  Future(() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();

      final cacheBase = (await getTemporaryDirectory()).path;

      // We can't access /tmp on Android, which sqlite3 would try by default.
      // Explicitly tell it about the correct temporary directory.
      sqlite3.tempDirectory = cacheBase;
    }

    final file = await databaseFile;
    final key = await _obtainDatabaseKey(keyManager, file);

    final connection = NativeDatabase.createBackgroundConnection(
      file,
      setup: (rawDb) {
        assert(_debugCheckHasCipher(rawDb), 'SQLite3MultipleCiphers is not available');
        rawDb.execute("PRAGMA key = '$key';");
      },
    );

    return connection.interceptWith(DBLogInterceptor());
  }),
);

Future<Directory> _getDbContainmentFolder() async {
  final Directory path;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS || TargetPlatform.macOS:
      path = await getLibraryDirectory();
    case TargetPlatform.windows:
      path = await getApplicationSupportDirectory();
    default:
      path = await getApplicationDocumentsDirectory();
  }
  if (!await path.exists()) {
    await path.create();
  }

  return path;
}
