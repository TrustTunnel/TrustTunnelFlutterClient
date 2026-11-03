import 'dart:io';

import 'package:crypto/crypto.dart';

abstract final class FileUtils {
  static Future<void> deleteIfExists(File file) async {
    final bool exists = await file.exists();

    if (exists) {
      await file.delete();
    }
  }

  static Future<bool> verifyFile(({String path, int size, String sha256}) targetInfo) async {
    final File file = File(targetInfo.path);
    final bool exists = await file.exists();

    if (!exists) {
      return false;
    }

    final int size = await file.length();

    if (size != targetInfo.size) {
      return false;
    }

    final Digest digest = await sha256.bind(file.openRead()).single;

    return digest.toString() == targetInfo.sha256;
  }
}
